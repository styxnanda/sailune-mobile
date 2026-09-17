// Package mobile is the narrow gomobile boundary shared by the native clients.
// All bookmark rules, URL resolution and SQLite transactions belong to Sailune-Go.
package mobile

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"path/filepath"
	"strings"
	"sync"
	"time"

	sailune "github.com/styxnanda/sailune-go"
)

// Client uses an explicit app-private path. It never consults desktop defaults.
type Client struct {
	library  sailune.Library
	mu       sync.Mutex
	requests map[string]*activeRequest
	fetcher  sailune.MetadataFetcher
}

func NewClient(path string) (*Client, error) {
	if !filepath.IsAbs(path) {
		return nil, errors.New("library path must be absolute")
	}
	return &Client{library: sailune.Library{Store: sailune.Store{Path: path}}, requests: map[string]*activeRequest{}, fetcher: &sailune.Scraper{}}, nil
}

type request struct {
	Op       string           `json:"op"`
	ID       int64            `json:"id"`
	Filter   sailune.Filter   `json:"filter"`
	Bookmark sailune.Bookmark `json:"bookmark"`
	Patch    sailune.Patch    `json:"patch"`
	Fetch    bool             `json:"fetch"`
	Chapter  int              `json:"chapter"`
	Snapshot string           `json:"snapshot"`
}

type story struct {
	sailune.Bookmark
	Effective sailune.Metadata `json:"effective"`
}

func present(b sailune.Bookmark) story { return story{b, b.EffectiveMetadata()} }

// Call is blocking: native adapters must use a worker executor. requestID must be
// unique among active requests. Cancel interrupts network I/O, not committed writes.
func (c *Client) Call(requestID, payload string) (string, error) {
	if requestID == "" {
		return "", errors.New("request ID is required")
	}
	c.mu.Lock()
	active := c.requests[requestID]
	if active == nil {
		active = newRequest()
		c.requests[requestID] = active
	}
	if active.started {
		c.mu.Unlock()
		return "", errors.New("request ID already active")
	}
	active.started = true
	c.mu.Unlock()
	ctx := active.ctx
	defer func() { active.cancel(); c.mu.Lock(); delete(c.requests, requestID); c.mu.Unlock() }()
	if err := ctx.Err(); err != nil {
		return "", err
	}
	if len(payload) > 32<<20 {
		return "", errors.New("mobile request exceeds 32 MiB")
	}
	var r request
	d := json.NewDecoder(strings.NewReader(payload))
	d.DisallowUnknownFields()
	if err := d.Decode(&r); err != nil {
		return "", fmt.Errorf("invalid request: %w", err)
	}
	if err := d.Decode(new(any)); err != io.EOF {
		return "", errors.New("unexpected trailing JSON")
	}
	var value any
	var err error
	switch r.Op {
	case "list":
		if r.Filter.Limit <= 0 || r.Filter.Limit > 100 {
			r.Filter.Limit = 40
		}
		var rows []sailune.Bookmark
		rows, err = c.library.List(r.Filter)
		items := make([]story, 0, len(rows))
		for _, b := range rows {
			items = append(items, present(b))
		}
		value = items
	case "get":
		var b sailune.Bookmark
		b, err = c.library.Get(r.ID)
		value = present(b)
	case "add":
		var b sailune.Bookmark
		if r.Fetch {
			b, err = c.library.AddScraped(ctx, r.Bookmark, deadlineFetcher{c.fetcher})
		} else {
			b, err = c.library.Add(r.Bookmark)
		}
		value = present(b)
	case "update":
		var b sailune.Bookmark
		b, err = c.library.Update(r.ID, r.Patch)
		value = present(b)
	case "refresh":
		var b sailune.Bookmark
		b, err = c.library.Refresh(ctx, r.ID, c.fetcher)
		value = present(b)
	case "delete":
		err = c.library.Delete(r.ID)
		value = true
	case "open":
		value, err = c.library.OpenURL(r.ID, r.Chapter)
	case "resume":
		value, err = c.library.ResumeURL(r.ID)
	case "export":
		var b bytes.Buffer
		err = c.library.Export(&b)
		value = b.String()
	case "import":
		value, err = c.library.Import(strings.NewReader(r.Snapshot), true)
	default:
		return "", errors.New("unknown mobile operation")
	}
	if err != nil {
		if strings.Contains(err.Error(), "AO3 chapter index is unavailable") {
			return "", errors.New("this story's chapter list is unavailable. Refresh website details, or open the website to choose a chapter")
		}
		if errors.Is(err, sailune.ErrLoginRequired) {
			return "", errors.New("this story requires sign-in; mobile sign-in is not available yet. Save it offline or open the website")
		}
		if errors.Is(err, sailune.ErrChallenge) {
			return "", errors.New("the website blocked this request. Save offline or try again later")
		}
		return "", err
	}
	data, err := json.Marshal(value)
	return string(data), err
}

func (c *Client) Cancel(requestID string) {
	c.mu.Lock()
	active := c.requests[requestID]
	c.mu.Unlock()
	if active != nil {
		active.cancel()
	}
}

const scrapeTimeout = 15 * time.Second

type activeRequest struct {
	ctx     context.Context
	cancel  context.CancelFunc
	started bool
}

func newRequest() *activeRequest {
	ctx, cancel := context.WithTimeout(context.Background(), scrapeTimeout)
	return &activeRequest{ctx: ctx, cancel: cancel}
}

// Prepare registers cancellation and the deadline before native worker queuing.
// Every successful Prepare must be followed by Call, even after cancellation,
// so that Call can release the request state.
func (c *Client) Prepare(requestID string) error {
	if requestID == "" {
		return errors.New("request ID is required")
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if _, exists := c.requests[requestID]; exists {
		return errors.New("request ID already active")
	}
	c.requests[requestID] = newRequest()
	return nil
}

// A fetcher returning after cancellation must not allow AddScraped to save it.
// If a local commit has already won the race, Call returns the saved result.
type deadlineFetcher struct{ delegate sailune.MetadataFetcher }

func (f deadlineFetcher) Fetch(ctx context.Context, url string) (sailune.Metadata, error) {
	metadata, err := f.delegate.Fetch(ctx, url)
	if ctx.Err() != nil {
		return sailune.Metadata{}, ctx.Err()
	}
	return metadata, err
}
