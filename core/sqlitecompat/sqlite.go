// Package sqlite provides the database/sql registration used by Sailune's core.
// Mobile uses SQLite compiled against the Android NDK's libc: the pure-Go Linux
// amd64 libc issues legacy syscalls that Android's seccomp policy prohibits.
// This is a mobile-only adapter, not a replacement for modernc's general API.
package sqlite

import (
	"database/sql"
	"database/sql/driver"
	"fmt"
	"net/url"

	"github.com/mattn/go-sqlite3"
)

func init() { sql.Register("sqlite", mobileDriver{}) }

type mobileDriver struct{}

func (mobileDriver) Open(name string) (driver.Conn, error) {
	u, err := url.Parse(name)
	if err != nil {
		return nil, err
	}
	q := u.Query()
	pragmas := q["_pragma"]
	q.Del("_pragma")
	u.RawQuery = q.Encode()
	conn, err := (&sqlite3.SQLiteDriver{}).Open(u.String())
	if err != nil {
		return nil, err
	}
	// Preserve every connection pragma requested by the shared core, including
	// foreign keys, full durability, secure deletion and read-only browser reads.
	for _, pragma := range pragmas {
		if _, err := conn.(driver.Execer).Exec("PRAGMA "+pragma, nil); err != nil {
			conn.Close()
			return nil, fmt.Errorf("SQLite pragma %q: %w", pragma, err)
		}
	}
	return conn, nil
}
