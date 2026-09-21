# Mobile SQLite adapter

The shared Sailune core uses only `database/sql` driver registration from
`modernc.org/sqlite`. This mobile module replaces that registration with
`github.com/mattn/go-sqlite3`, compiling SQLite against the Android NDK's libc.
The pure-Go Linux AMD64 implementation calls legacy `lstat`, which Android's
seccomp policy terminates with `SIGSYS`. The NDK implementation supports both
ARM64 and x86_64 without weakening Android's sandbox.

The adapter preserves the `sqlite` driver name, repeated `_pragma` options,
URI modes, and `_txlock` behavior used by the shared core. Database files and
schema remain standard SQLite and are compatible with desktop and CLI.
This is intentionally not an implementation of modernc's wider package API.
The native driver is MIT licensed; SQLite itself is public domain.
