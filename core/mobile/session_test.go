package mobile

import (
	"context"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"

	sailune "github.com/styxnanda/sailune-go"
)

type sessionProbe struct {
	requests, stored []string
	enabled          bool
}

func (p *sessionProbe) Cookies(u string) string {
	p.requests = append(p.requests, u)
	if p.enabled {
		return "session=SYNTHETIC_SECRET"
	}
	return ""
}
func (p *sessionProbe) StoreCookie(u, c string) { p.stored = append(p.stored, u+" "+c) }

type sessionRoundTrip func(*http.Request) (*http.Response, error)

func (f sessionRoundTrip) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
func sessionResponse(r *http.Request, code int, body string) *http.Response {
	return &http.Response{StatusCode: code, Header: http.Header{"Content-Type": []string{"text/html"}}, Body: io.NopCloser(strings.NewReader(body)), Request: r}
}

func TestSessionTransportScopeRotationAndRevocation(t *testing.T) {
	p := &sessionProbe{enabled: true}
	calls := 0
	transport := &sessionTransport{native: p, base: sessionRoundTrip(func(r *http.Request) (*http.Response, error) {
		calls++
		want := "session=SYNTHETIC_SECRET"
		if !p.enabled {
			want = ""
		}
		if r.Header.Get("Cookie") != want {
			t.Fatal("session not applied correctly")
		}
		resp := sessionResponse(r, 200, "")
		resp.Header.Add("Set-Cookie", "session=ROTATED; Path=/; Secure; HttpOnly")
		resp.Header.Add("Set-Cookie", "bad=LEAK; Domain=fanfiction.net; Path=/")
		return resp, nil
	})}
	r, _ := http.NewRequest("GET", "https://archiveofourown.org/works/123", nil)
	resp, err := transport.RoundTrip(r)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if len(p.stored) != 1 || !strings.Contains(p.stored[0], "HttpOnly") {
		t.Fatal("rotation/domain filtering failed")
	}
	p.enabled = false
	resp, err = transport.RoundTrip(r)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	for _, u := range []string{"http://archiveofourown.org/works/123", "https://archiveofourown.org.evil.test/", "https://example.com/", "https://archiveofourown.org:444/"} {
		r, _ := http.NewRequest("GET", u, nil)
		if _, err := transport.RoundTrip(r); err == nil {
			t.Fatal("accepted untrusted session target")
		}
	}
	if calls != 2 {
		t.Fatal("untrusted network request occurred")
	}
}
func TestScraperRejectsCrossSiteSessionRedirect(t *testing.T) {
	p := &sessionProbe{enabled: true}
	transport := &sessionTransport{native: p, base: sessionRoundTrip(func(r *http.Request) (*http.Response, error) {
		resp := sessionResponse(r, 302, "")
		resp.Header.Set("Location", "https://www.fanfiction.net/s/123/1")
		return resp, nil
	})}
	_, err := (&sailune.Scraper{Client: &http.Client{Transport: transport}}).Fetch(context.Background(), "https://archiveofourown.org/works/123")
	if err == nil || len(p.requests) != 1 {
		t.Fatal("session redirect not blocked")
	}
}
func TestAuthenticatedAddAndBackupExcludesCookies(t *testing.T) {
	html, err := os.ReadFile("../../../sailune-cli/internal/scrape/testdata/ao3.html")
	if err != nil {
		t.Fatal(err)
	}
	c, _ := NewClient(filepath.Join(t.TempDir(), "library.sqlite3"))
	p := &sessionProbe{enabled: true}
	c.SetWebsiteSession(p)
	c.session.base = sessionRoundTrip(func(r *http.Request) (*http.Response, error) {
		if r.Header.Get("Cookie") == "" {
			return sessionResponse(r, 401, ""), nil
		}
		return sessionResponse(r, 200, string(html)), nil
	})
	result, err := c.Call("add", `{"op":"add","fetch":true,"bookmark":{"url":"https://archiveofourown.org/works/123"}}`)
	if err != nil || !strings.Contains(result, `"id":1`) {
		t.Fatal("authenticated add failed", err)
	}
	backup, err := c.Call("export", `{"op":"export"}`)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(backup, "SYNTHETIC_SECRET") {
		t.Fatal("cookie leaked into backup")
	}
	p.enabled = false
	_, err = c.Call("refresh", `{"op":"refresh","id":1}`)
	if err == nil || !strings.Contains(err.Error(), "Website sessions") {
		t.Fatal("expired session did not provide recovery", err)
	}
	c.Close()
	if c.session.native != nil {
		t.Fatal("native session reference retained")
	}
}
