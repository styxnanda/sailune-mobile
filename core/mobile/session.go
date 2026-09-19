package mobile

import (
	"errors"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	sailune "github.com/styxnanda/sailune-go"
)

// WebsiteSession is Android's app-private WebView cookie store. Values cross
// only the native/Go boundary; they are never returned over the Flutter channel.
type WebsiteSession interface {
	Cookies(url string) string
	StoreCookie(url, cookie string)
}

type sessionTransport struct {
	mu     sync.RWMutex
	native WebsiteSession
	base   http.RoundTripper
}

func sessionSite(raw string) string {
	u, e := url.Parse(raw)
	if e != nil || u.Scheme != "https" || u.User != nil || u.Port() != "" {
		return ""
	}
	switch u.Hostname() {
	case "archiveofourown.org", "www.archiveofourown.org":
		return "ao3"
	case "fanfiction.net", "www.fanfiction.net", "m.fanfiction.net":
		return "ffn"
	}
	return ""
}
func (t *sessionTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	if e := req.Context().Err(); e != nil {
		return nil, e
	}
	t.mu.RLock()
	native := t.native
	t.mu.RUnlock()
	site := sessionSite(req.URL.String())
	if site == "" {
		return nil, errors.New("refused session request outside supported HTTPS sites")
	}
	r := req.Clone(req.Context())
	if native != nil {
		if cookies := native.Cookies(r.URL.String()); cookies != "" {
			if len(cookies) > 65536 || strings.ContainsAny(cookies, "\r\n") {
				return nil, errors.New("invalid website session")
			}
			r.Header.Set("Cookie", cookies)
		}
	}
	resp, err := t.base.RoundTrip(r)
	if err != nil || native == nil || req.Context().Err() != nil {
		return resp, err
	}
	for i, c := range resp.Cookies() {
		if i >= 64 || req.Context().Err() != nil {
			break
		}
		if deadline, ok := req.Context().Deadline(); ok && time.Until(deadline) < time.Second {
			break
		}
		// Response cookies must not grant another site's domain access.
		if c.Domain != "" && sessionSite("https://"+strings.TrimPrefix(strings.ToLower(c.Domain), ".")+"/") != site {
			continue
		}
		if value := c.String(); len(value) <= 65536 && c.Valid() == nil {
			native.StoreCookie(r.URL.String(), value)
		}
	}
	return resp, nil
}

func (c *Client) SetWebsiteSession(native WebsiteSession) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed || native == nil || len(c.requests) != 0 || c.session != nil {
		return
	}
	c.session = &sessionTransport{native: native, base: http.DefaultTransport}
	c.configureFetcher()
}

// Caller holds Client.mu; invoked only during native configuration.
func (c *Client) configureFetcher() {
	s := &sailune.Scraper{}
	if c.browser != nil {
		s.Browser = &sailune.BrowserRecovery{Loader: c.browser}
	}
	if c.session != nil {
		s.Client = &http.Client{Transport: c.session}
	}
	c.fetcher = s
}
