package mobile

import (
	"context"
	"errors"
	"path/filepath"
	"testing"
	"time"
)

type nativeProbe struct {
	begin  func(string, string, int64)
	cancel chan string
}

func (n *nativeProbe) Begin(id, u string, ms int64) { n.begin(id, u, ms) }
func (n *nativeProbe) Cancel(id string)             { n.cancel <- id }
func TestNativeBrowserRoundTrip(t *testing.T) {
	c, _ := NewClient(filepath.Join(t.TempDir(), "library.sqlite3"))
	n := &nativeProbe{cancel: make(chan string, 2)}
	n.begin = func(id, u string, ms int64) {
		if ms <= 0 || ms > 15000 {
			t.Errorf("deadline %d", ms)
		}
		c.BrowserResult(id, u, "header", "")
	}
	c.SetBrowser(n)
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	u, html, err := c.browser.Load(ctx, "https://www.fanfiction.net/s/123/1")
	if err != nil || html != "header" || u == "" {
		t.Fatal(u, html, err)
	}
	select {
	case <-n.cancel:
	default:
		t.Fatal("browser not released")
	}
	if len(c.browser.pending) != 0 {
		t.Fatal("pending bridge leaked")
	}
}
func TestNativeBrowserCancellationAndLateResult(t *testing.T) {
	c, _ := NewClient(filepath.Join(t.TempDir(), "library.sqlite3"))
	ctx, cancel := context.WithCancel(context.Background())
	ctx, deadline := context.WithTimeout(ctx, time.Second)
	defer deadline()
	n := &nativeProbe{cancel: make(chan string, 2)}
	var id string
	n.begin = func(i, u string, ms int64) { id = i; cancel() }
	c.SetBrowser(n)
	_, _, err := c.browser.Load(ctx, "https://www.fanfiction.net/s/123/1")
	if !errors.Is(err, context.Canceled) {
		t.Fatal(err)
	}
	c.BrowserResult(id, "https://www.fanfiction.net/s/123/1", "late", "")
	if len(c.browser.pending) != 0 {
		t.Fatal("late response resurrected request")
	}
	select {
	case <-n.cancel:
	default:
		t.Fatal("native cancel not delivered")
	}
}

func TestCloseReleasesNativeBrowserAndRejectsNewWork(t *testing.T) {
	c, _ := NewClient(filepath.Join(t.TempDir(), "library.sqlite3"))
	n := &nativeProbe{cancel: make(chan string, 1), begin: func(string, string, int64) {}}
	c.SetBrowser(n)
	c.Close()
	if c.browser.native != nil {
		t.Fatal("Activity reference retained after close")
	}
	if c.Prepare("new") == nil {
		t.Fatal("closed client accepted work")
	}
	if _, err := c.Call("new", `{"op":"list"}`); err == nil {
		t.Fatal("closed client accepted Call")
	}
}
