package mobile

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	sailune "github.com/styxnanda/sailune-go"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func newTestClient(t *testing.T) *Client {
	t.Helper()
	c, e := NewClient(filepath.Join(t.TempDir(), "library.sqlite3"))
	if e != nil {
		t.Fatal(e)
	}
	return c
}
func call(t *testing.T, c *Client, r any) string {
	t.Helper()
	b, _ := json.Marshal(r)
	v, e := c.Call("test", string(b))
	if e != nil {
		t.Fatal(e)
	}
	return v
}
func add(t *testing.T, c *Client, n int) story {
	t.Helper()
	v := call(t, c, map[string]any{"op": "add", "bookmark": map[string]any{"url": fmt.Sprintf("https://www.fanfiction.net/s/%d/1/Title", n), "title": "Moonlit library", "author": "A Writer"}})
	var s story
	if e := json.Unmarshal([]byte(v), &s); e != nil {
		t.Fatal(e)
	}
	return s
}
func TestPersistenceAndPatch(t *testing.T) {
	c := newTestClient(t)
	s := add(t, c, 123)
	call(t, c, map[string]any{"op": "update", "id": s.ID, "patch": map[string]any{"Chapter": 3, "Notes": "keep me", "Rating": 4}})
	call(t, c, map[string]any{"op": "update", "id": s.ID, "patch": map[string]any{"Title": "New title"}})
	reopened, e := NewClient(c.library.Store.Path)
	if e != nil {
		t.Fatal(e)
	}
	var got story
	json.Unmarshal([]byte(call(t, reopened, map[string]any{"op": "get", "id": s.ID})), &got)
	if got.Chapter != 3 || got.Notes != "keep me" || got.Rating != 4 || got.Title != "New title" {
		t.Fatalf("lost data: %+v", got)
	}
	url := call(t, c, map[string]any{"op": "resume", "id": s.ID})
	if url != `"https://www.fanfiction.net/s/123/4"` {
		t.Fatal(url)
	}
	b, _ := c.library.Get(s.ID)
	if b.Chapter != 3 {
		t.Fatal("opening changed progress")
	}
	if _, e = c.Call("duplicate", `{"op":"add","bookmark":{"url":"https://fanfiction.net/s/123/9"}}`); !errors.Is(e, sailune.ErrDuplicate) {
		t.Fatal(e)
	}
}
func TestTransferAndValidation(t *testing.T) {
	c := newTestClient(t)
	add(t, c, 123)
	raw := call(t, c, map[string]any{"op": "export"})
	var snapshot string
	json.Unmarshal([]byte(raw), &snapshot)
	other := newTestClient(t)
	first := call(t, other, map[string]any{"op": "import", "snapshot": snapshot})
	second := call(t, other, map[string]any{"op": "import", "snapshot": snapshot})
	if first != `{"imported":1,"skipped":0}` || second != `{"imported":0,"skipped":1}` {
		t.Fatal(first, second)
	}
	for _, bad := range []string{`{"op":"oops"}`, `{"op":"list"} {}`, `{"op":"list","typo":true}`, `{"op":"update","id":1,"patch":{"Chapter":-1}}`, `{"op":"add","bookmark":{"url":"https://example.com"}}`, `{"op":"import","snapshot":"{}"}`} {
		if _, e := other.Call("invalid", bad); e == nil {
			t.Fatalf("accepted %s", bad)
		}
	}
	rows, _ := other.library.List(sailune.Filter{})
	if len(rows) != 1 || rows[0].Chapter != 0 {
		t.Fatal("invalid write changed library")
	}
	call(t, other, map[string]any{"op": "delete", "id": rows[0].ID})
	if _, e := other.library.Get(rows[0].ID); !errors.Is(e, sailune.ErrNotFound) {
		t.Fatal(e)
	}
}
func TestPaginationSearchAndEffectiveMetadata(t *testing.T) {
	c := newTestClient(t)
	for i := 1; i <= 43; i++ {
		add(t, c, i)
	}
	var rows []story
	json.Unmarshal([]byte(call(t, c, map[string]any{"op": "list", "filter": map[string]any{"Limit": 40}})), &rows)
	if len(rows) != 40 {
		t.Fatal(len(rows))
	}
	json.Unmarshal([]byte(call(t, c, map[string]any{"op": "list", "filter": map[string]any{"Offset": 40, "Query": "moonlit writer"}})), &rows)
	if len(rows) != 3 {
		t.Fatal(len(rows))
	}
	chapters := 12
	summary := "My summary"
	c.library.Update(1, sailune.Patch{Overrides: &sailune.MetadataPatch{Chapters: &chapters, Summary: &summary}})
	var s story
	json.Unmarshal([]byte(call(t, c, map[string]any{"op": "get", "id": 1})), &s)
	if s.Effective.Chapters != 12 || s.Effective.Summary != summary {
		t.Fatal(s)
	}
}

type blockedFetcher struct{ entered chan struct{} }

func (f blockedFetcher) Fetch(ctx context.Context, _ string) (sailune.Metadata, error) {
	close(f.entered)
	<-ctx.Done()
	return sailune.Metadata{}, ctx.Err()
}
func TestCancellationPreservesPersonalData(t *testing.T) {
	c := newTestClient(t)
	s := add(t, c, 1)
	f := blockedFetcher{make(chan struct{})}
	c.fetcher = f
	done := make(chan error, 1)
	go func() { _, e := c.Call("slow", fmt.Sprintf(`{"op":"refresh","id":%d}`, s.ID)); done <- e }()
	<-f.entered
	if _, e := c.Call("slow", `{"op":"list"}`); e == nil {
		t.Fatal("accepted duplicate active ID")
	}
	c.Cancel("slow")
	select {
	case e := <-done:
		if !errors.Is(e, context.Canceled) {
			t.Fatal(e)
		}
	case <-time.After(time.Second):
		t.Fatal("cancel did not interrupt")
	}
	b, _ := c.library.Get(s.ID)
	if b.Title != s.Title || b.Metadata != nil {
		t.Fatal("failed refresh changed story")
	}
}

func TestMissingChapterIndexHasMobileRecovery(t *testing.T) {
	c := newTestClient(t)
	b, err := c.library.Add(sailune.Bookmark{URL: "https://archiveofourown.org/works/123", Chapter: 2})
	if err != nil {
		t.Fatal(err)
	}
	_, err = c.Call("resume", fmt.Sprintf(`{"op":"resume","id":%d}`, b.ID))
	if err == nil || !strings.Contains(err.Error(), "open the website") || strings.Contains(err.Error(), "refresh ID") {
		t.Fatal(err)
	}
}

func TestCancelBeforeWorkerStartsAndMalformedCleanup(t *testing.T) {
	c := newTestClient(t)
	if err := c.Prepare("queued"); err != nil {
		t.Fatal(err)
	}
	c.Cancel("queued")
	_, err := c.Call("queued", `{"op":"add","bookmark":{"url":"https://fanfiction.net/s/123/1"}}`)
	if !errors.Is(err, context.Canceled) {
		t.Fatal(err)
	}
	rows, err := c.library.List(sailune.Filter{})
	if err != nil || len(rows) != 0 {
		t.Fatal("cancelled request saved a bookmark", err)
	}
	if err := c.Prepare("bad"); err != nil {
		t.Fatal(err)
	}
	if _, err := c.Call("bad", `not json`); err == nil {
		t.Fatal("accepted invalid payload")
	}
	if len(c.requests) != 0 {
		t.Fatal("request registrations leaked")
	}
}

type deadlineProbe struct{ t *testing.T }

func (f deadlineProbe) Fetch(ctx context.Context, _ string) (sailune.Metadata, error) {
	deadline, ok := ctx.Deadline()
	if !ok || time.Until(deadline) > 15*time.Second || time.Until(deadline) < 14*time.Second {
		f.t.Error("expected a 15-second deadline")
	}
	return sailune.Metadata{}, context.DeadlineExceeded
}
func TestScrapingUsesFifteenSecondDeadline(t *testing.T) {
	c := newTestClient(t)
	c.fetcher = deadlineProbe{t}
	_, err := c.Call("timeout", `{"op":"add","fetch":true,"bookmark":{"url":"https://fanfiction.net/s/123/1"}}`)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatal(err)
	}
	rows, _ := c.library.List(sailune.Filter{})
	if len(rows) != 0 {
		t.Fatal("timeout saved a bookmark")
	}
}

type ignoringCancellationFetcher struct {
	entered chan struct{}
	release chan struct{}
}

func (f ignoringCancellationFetcher) Fetch(ctx context.Context, _ string) (sailune.Metadata, error) {
	close(f.entered)
	<-f.release
	return sailune.Metadata{Title: "Too late"}, nil
}
func TestCancelledFetchCannotReturnLateMetadataAndSave(t *testing.T) {
	c := newTestClient(t)
	f := ignoringCancellationFetcher{make(chan struct{}), make(chan struct{})}
	c.fetcher = f
	done := make(chan error, 1)
	go func() {
		_, err := c.Call("late", `{"op":"add","fetch":true,"bookmark":{"url":"https://fanfiction.net/s/123/1"}}`)
		done <- err
	}()
	<-f.entered
	c.Cancel("late")
	close(f.release)
	if err := <-done; !errors.Is(err, context.Canceled) {
		t.Fatal(err)
	}
	rows, _ := c.library.List(sailune.Filter{})
	if len(rows) != 0 {
		t.Fatal("late result saved a cancelled bookmark")
	}
}
