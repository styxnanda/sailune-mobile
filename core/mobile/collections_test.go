package mobile

import (
	"encoding/json"
	"fmt"
	sailune "github.com/styxnanda/sailune-go"
	"testing"
)

func TestCollectionOverviewAcrossPages(t *testing.T) {
	c := newTestClient(t)
	manual, err := c.library.SaveCollection(sailune.Collection{Name: "Together", Kind: "manual"})
	if err != nil {
		t.Fatal(err)
	}
	var ids []int64
	for i := 0; i < 205; i++ {
		rating := 0
		if i == 0 {
			rating = 2
		}
		if i == 204 {
			rating = 4
		}
		b, e := c.library.Add(sailune.Bookmark{URL: fmt.Sprintf("https://archiveofourown.org/works/%d", 9000+i), Title: fmt.Sprintf("Story %d", i), Rating: rating, Notes: "private notes excluded from previews"})
		if e != nil {
			t.Fatal(e)
		}
		ids = append(ids, b.ID)
	}
	if e := c.library.SetMembership(manual.ID, ids, false); e != nil {
		t.Fatal(e)
	}
	var rows []struct {
		Count    int
		Average  float64
		Rated    int
		Contains bool
		Preview  []map[string]any
	}
	if e := json.Unmarshal([]byte(call(t, c, map[string]any{"op": "collection-overviews", "id": ids[0]})), &rows); e != nil {
		t.Fatal(e)
	}
	if len(rows) != 1 || rows[0].Count != 205 || rows[0].Average != 3 || rows[0].Rated != 2 || !rows[0].Contains || len(rows[0].Preview) != 5 {
		t.Fatalf("bad overview: %+v", rows)
	}
	if _, ok := rows[0].Preview[0]["notes"]; ok {
		t.Fatal("preview leaked unnecessary notes")
	}
	if e := c.library.DeleteCollection(manual.ID); e != nil {
		t.Fatal(e)
	}
	if n, e := c.library.Count(sailune.Filter{}); e != nil || n != 205 {
		t.Fatalf("collection deletion affected stories: %d %v", n, e)
	}
}
