package mobile

import (
	"context"
	"errors"
	"strconv"
	"sync"
	"sync/atomic"
	"time"
)

// Browser is implemented by Android. Begin and Cancel must return immediately;
// results are delivered through Client.BrowserResult. No UI may be presented.
type Browser interface {
	Begin(id, url string, timeoutMillis int64)
	Cancel(id string)
}
type browserPage struct{ url, html, failure string }
type nativeBrowser struct {
	native   Browser
	mu       sync.Mutex
	pending  map[string]chan browserPage
	sequence atomic.Int64
}

func (c *Client) SetBrowser(b Browser) {
	c.mu.Lock()
	defer c.mu.Unlock()
	// Configuration happens once before any requests are accepted.
	if c.closed || c.browser != nil || b == nil || len(c.requests) != 0 {
		return
	}
	c.browser = &nativeBrowser{native: b, pending: map[string]chan browserPage{}}
	c.configureFetcher()
}

func (c *Client) BrowserResult(id, url, html, failure string) {
	c.mu.Lock()
	b := c.browser
	c.mu.Unlock()
	if b == nil {
		return
	}
	if len(html) > 1<<20 {
		html = ""
		failure = "browser response too large"
	}
	b.mu.Lock()
	ch := b.pending[id]
	b.mu.Unlock()
	if ch != nil {
		select {
		case ch <- browserPage{url, html, failure}:
		default:
		}
	}
}

func (b *nativeBrowser) Load(ctx context.Context, url string) (string, string, error) {
	deadline, ok := ctx.Deadline()
	if !ok {
		return "", "", errors.New("browser deadline required")
	}
	id := strconv.FormatInt(b.sequence.Add(1), 10)
	ch := make(chan browserPage, 1)
	b.mu.Lock()
	native := b.native
	if native == nil {
		b.mu.Unlock()
		return "", "", errors.New("browser closed")
	}
	b.pending[id] = ch
	b.mu.Unlock()
	defer func() { b.mu.Lock(); delete(b.pending, id); b.mu.Unlock(); native.Cancel(id) }()
	if ctx.Err() != nil {
		return "", "", ctx.Err()
	}
	native.Begin(id, url, max(1, time.Until(deadline).Milliseconds()))
	select {
	case <-ctx.Done():
		return "", "", ctx.Err()
	case p := <-ch:
		if p.failure != "" {
			return "", "", errors.New("background browser failed")
		}
		return p.url, p.html, nil
	}
}

// Close cancels workers before the Activity and its WebViews are destroyed.
func (c *Client) Close() {
	c.mu.Lock()
	c.closed = true
	for _, r := range c.requests {
		r.cancel()
	}
	b := c.browser
	session := c.session
	c.mu.Unlock()
	if session != nil {
		session.mu.Lock()
		session.native = nil
		session.mu.Unlock()
	}
	if b != nil {
		b.mu.Lock()
		b.native = nil
		b.mu.Unlock()
	}
}
