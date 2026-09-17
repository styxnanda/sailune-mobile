# Sailune for Android

A quiet reading room for your fanfiction bookmarks, built with **Flutter + Dart** and the **embedded Sailune-Go core**. Android is the focus of this repository; iOS will be a separate project.

The interface follows Sailune Desktop: monochrome surfaces, rounded story cards, generous touch targets, chapter controls, and light/dark appearance. The original Sailune icon is shared across clients. Cards use small, color-only folded corners (Completed green, Reading blue, To read lavender, On hold amber, Dropped rose). Site watermarks use low-opacity black in light mode and pearl in dark mode, clipped at the lower-right corner.

<p>
<img src="test/goldens/library_light.png" width="280" alt="Sailune reading room in light appearance" />
<img src="test/goldens/library_dark.png" width="280" alt="Sailune reading room in dark appearance" />
</p>

Screenshots contain synthetic test stories, not a preloaded collection.

## Features

- Add AO3 and FanFiction.net stories with public metadata, or save offline. The full-width add button expands into a rising form sheet.
- Scraping shows a centered animated dialog with five fading waiting messages, Cancel, and a 15-second network deadline. Cancelled or failed fetches retain the form.
- Search, shelves, website filtering, unread-chapter filtering, and sorting.
- Bounded SQL pages of 40 stories and lazy scrolling.
- Edit titles, authors, progress, personal tags, notes, and ratings.
- Refresh source details without replacing personal fields.
- Read the next chapter using the shared core's URL resolver. Opening never marks a chapter read.
- Confirm before deleting a bookmark.
- Export and merge the CLI/desktop versioned JSON backup format using Android's document picker.
- Device, light, and dark appearance; scalable text and 48dp controls.

The app starts with an empty library. Tests inject their own fixtures; the shipped app has no mock persistence or server dependency.

## Build

Requirements: Flutter **3.47.4** / Dart **3.13**, Go **1.26.3**, JDK **17**, Android SDK platform **36**, build tools **36.0.0**, NDK **28.2.13676358**. Android 7.0/API 24 or newer, ARM64 phones and x86_64 emulators. The current SQLite dependency is supported here on those 64-bit ABIs.

Keep the shared core alongside this checkout:

```text
Projects/
  sailune-cli/        # github.com/styxnanda/sailune-go
  sailune-mobile/    # this repository
```

The `core/go.mod` replacement points at `../../sailune-cli`. CI pins core commit `de1eb190f2cc6855855fa3aef6ee881120077a36`. Use that revision for reproducible builds. Local core changes are picked up deliberately when you rebuild the bindings.

```sh
# Set JAVA_HOME and ANDROID_HOME to your installed JDK and SDK.
sdkmanager 'platforms;android-36' 'build-tools;36.0.0' 'ndk;28.2.13676358'
go install golang.org/x/mobile/cmd/gomobile@v0.0.0-20260908204917-8b95e45f8d3e
go install golang.org/x/mobile/cmd/gobind@v0.0.0-20260908204917-8b95e45f8d3e
scripts/build-core.sh
flutter pub get
flutter run
# Installable development build:
flutter build apk --debug --target-platform android-arm64,android-x64
```

The APK is `build/app/outputs/flutter-apk/app-debug.apk`. The generated AAR is intentionally ignored by Git. Rebuild it after changes to the facade or Go core. Flutter generates its Gradle launcher and local configuration on first build.

CI runs analysis, widget/golden tests, Go race tests and vet, builds the APK, and runs the real bridge integration test on an Android emulator. The APK is a development artifact; production signing and Play Store release are not configured.

## Test

```sh
flutter analyze
flutter test
go -C core test -race ./...
go -C core vet ./...
# Only on a disposable emulator; creates and deletes a synthetic bookmark:
flutter test integration_test/library_test.dart -d emulator-5554
```

Golden screenshots are generated with bundled Roboto and Material Icons on macOS. Review visual changes before running `flutter test --update-goldens`.

See [verification notes](docs/verification.md) for results and remaining checks.

## Architecture and storage

```text
Flutter screens → Dart Library interface → Android MethodChannel
  → worker executor → gomobile AAR → Sailune-Go → private SQLite
```

Dart owns presentation and form state. The Kotlin adapter owns app-private paths, browser intents, preferences, and the document picker. Go owns validation, canonical URLs, duplicate checks, metadata, persistence, queries, chapter resolution, and transfers. No CLI subprocess is launched and no domain rules are copied into Dart.

SQLite and network work run off Android's UI thread. Search is debounced, outdated list responses are discarded, lists are paginated, and saves disable duplicate submission. Failed saves retain the form. Editing sends only changed personal fields.

The library lives under Android's private app files directory. It is plaintext within the app sandbox; uninstalling removes it. Android automatic backup is disabled. Export a snapshot before uninstalling. JSON backups contain your personal notes and reading history, and can be read by anyone who has the file. Mobile file transfers are capped at 16 MiB. Import merges atomically and skips duplicate URLs; it does not synchronize edits to existing bookmarks.

Mobile login, cookie import, authenticated scraping, full-story downloads, background update checks, and cloud sync are not implemented. Public fetches may encounter website restrictions or rate limits; offline entry remains available. The core's desktop keyring/browser code is a transitive dependency, but mobile never invokes those APIs or configures a session directory. A native secure-storage/session adapter is needed before enabling authentication.

## References

- [Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels)
- [Go mobile bindings](https://go.dev/wiki/Mobile)
- [Flutter widget testing](https://docs.flutter.dev/cookbook/testing/widget/introduction)

Licensed under [GPL-3.0](LICENSE). Bundled Roboto uses the license in `assets/fonts/Roboto_LICENSE.txt`; Flutter and Go dependencies retain their respective licenses.
