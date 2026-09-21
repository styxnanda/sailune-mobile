package mobile

import (
	"database/sql"
	"net/url"
	"path/filepath"
	"testing"
)

func TestNativeSQLiteConnectionPragmas(t *testing.T) {
	u := url.URL{Scheme: "file", Path: filepath.Join(t.TempDir(), "native # sqlite.db")}
	q := url.Values{"_pragma": {"foreign_keys(1)", "busy_timeout(2000)", "synchronous(FULL)", "secure_delete(ON)"}, "_txlock": {"immediate"}}
	u.RawQuery = q.Encode()
	db, err := sql.Open("sqlite", u.String())
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	db.SetMaxOpenConns(1)
	for pragma, want := range map[string]int{"foreign_keys": 1, "busy_timeout": 2000, "synchronous": 2, "secure_delete": 1} {
		var got int
		if err := db.QueryRow("PRAGMA " + pragma).Scan(&got); err != nil || got != want {
			t.Fatalf("%s = %d, want %d: %v", pragma, got, want, err)
		}
	}
	if _, err := db.Exec("CREATE TABLE parent(id INTEGER PRIMARY KEY); CREATE TABLE child(parent_id REFERENCES parent(id))"); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec("INSERT INTO child VALUES(123)"); err == nil {
		t.Fatal("foreign key violation accepted")
	}
	q = url.Values{"mode": {"ro"}, "_pragma": {"query_only(1)"}}
	u.RawQuery = q.Encode()
	ro, err := sql.Open("sqlite", u.String())
	if err != nil {
		t.Fatal(err)
	}
	defer ro.Close()
	if err := ro.Ping(); err != nil {
		t.Fatal(err)
	}
	if _, err := ro.Exec("INSERT INTO parent VALUES(1)"); err == nil {
		t.Fatal("read-only connection accepted write")
	}
}
