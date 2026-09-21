# Android implementation decisions

For Android, `core/sqlitecompat` registers the shared core's SQLite driver name
using `go-sqlite3` compiled against the NDK libc. This avoids Linux AMD64 legacy
syscalls prohibited by Android's seccomp policy. Connection pragmas, transaction
locking, schema, and backup compatibility remain shared with desktop and CLI.

The initial stack discussion in Sailune-Go offered native SwiftUI/Compose and Flutter alternatives. The user selected Flutter + Dart, Android first, with iOS in a separate project. There is no iOS or Compose application in this repository.

## Shared-core boundary

`core/mobile.Client` exposes a synchronous JSON request/response method and network cancellation, using only gomobile-compatible types. The Android executor moves calls off the main thread. Native errors become `PlatformException`; Dart retains editable values and presents a retry path.

Request operations: `list`, `get`, `add`, `update`, `refresh`, `delete`, `open`, `resume`, `export`, and `import`. Each call has a unique active request ID. The Android handler registers requests with `Prepare` before putting them on a worker queue. Cancellation therefore also covers requests that have not started running. The context deadline is 15 seconds, including worker queue time, and overrides the scraper’s longer default. Cancellation does not undo committed writes: if a save already succeeded, its successful result is shown. A cancelled fetch returning late metadata is rejected before adding a bookmark.

List filters and edit patches use the Go public field names. Bookmark payloads and effective metadata use the existing JSON schema. `effective` is added for presentation so metadata overrides imported from desktop are honored without duplicating merge rules in Dart. Source metadata and overrides remain intact even though the first mobile editor exposes only personal fields.

SQLite is authoritative. Dart does not cache bookmark state across launches. The document picker grants access to exactly the selected file, with no broad storage permission. External browser opening accepts only core-supported HTTPS hosts.

## Design

- Light: canvas `#f5f5f5`, surface `#ffffff`, ink `#202020`, border `#dedede`.
- Dark: canvas `#181818`, surface `#232323`, ink `#ededed`, border `#3b3b3b`.
- 22px cards, 16px form controls, 24px page gutters, 48dp minimum icon targets.
- One reading-room destination. The full-width Add story button first expands to cover the bottom of the screen, then the editor sheet rises to 86% of the screen height. Editing, settings, and story details use standard Flutter routes; filters use a sheet. Reduced motion skips the sheet transition and freezes the scraping spinner.
- Native back navigation, pull-to-refresh, keyboard-aware forms, large text, and browser reading.
- No live SQLite cloud synchronization, no inferred progress on opening a story.

## Dependency audit

The pinned shared library builds into ARM64 and x86_64 Android bindings. `modernc.org/sqlite` supplies the SQLite implementation. The facade imports the public Sailune-Go package, which also brings desktop authentication dependencies into the compile graph. The guest scraper uses an empty session directory and an in-memory cookie jar. Mobile exposes no browser-cookie or keyring entry points. These compiled desktop dependencies are not evidence of mobile authentication support.

32-bit Android is deliberately excluded from both gomobile and Gradle ABI targets. App-private paths are supplied explicitly, preventing accidental use of desktop-default library paths. The shared core includes an Android-specific atomic database publication helper: Android denies hard links in app-private storage, so initialization uses `renameat2(RENAME_NOREPLACE)`. Desktop platforms retain their existing hard-link publication behavior.
