module github.com/styxnanda/sailune-mobile/core

go 1.26.0

require github.com/styxnanda/sailune-go v0.9.0

require (
	github.com/danieljoos/wincred v1.2.3 // indirect
	github.com/godbus/dbus/v5 v5.2.2 // indirect
	github.com/mattn/go-sqlite3 v1.14.52 // indirect
	github.com/zalando/go-keyring v0.2.8 // indirect
	golang.org/x/mobile v0.0.0-20260908204917-8b95e45f8d3e // indirect
	golang.org/x/mod v0.41.0 // indirect
	golang.org/x/net v0.59.0 // indirect
	golang.org/x/sync v0.23.0 // indirect
	golang.org/x/sys v0.48.0 // indirect
	golang.org/x/tools v0.50.0 // indirect
	modernc.org/sqlite v1.58.0 // indirect
)

replace github.com/styxnanda/sailune-go => ../../sailune-cli

replace modernc.org/sqlite => ./sqlitecompat

tool golang.org/x/mobile/cmd/gobind
