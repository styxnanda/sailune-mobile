# Verification

## Automated checks

- Go facade: persistence across client creation, canonical URL duplicate rejection, partial patches, chapter resolution without changing progress, export/import and merge, invalid-write rollback, pagination, effective metadata, cancellation, and unique active request IDs.
- Flutter: empty-library add route, debounced search, chapter progress, browser-read action, failed-save recovery, changed-field-only editing, load-error retry, light/dark golden screenshots, large-text layouts, and platform-channel error propagation.
- Android integration: actual MethodChannel → gomobile → SQLite add/update/get/export/import, duplicate rejection, next-chapter resolution, preferences, and cleanup of the test record.

Local execution results are recorded at completion below.

## Manual release checks

Before a store release: verify TalkBack navigation, real-device frame timing, Android document providers (local and cloud), system Back/predictive Back, process death during a file picker, network loss, live public AO3/FFN responses, and signed release installation. Authenticated fetching is outside this version's scope.

## Local results

Verified with Flutter 3.47.4 / Dart 3.13.3, Go 1.26.3, JDK 17, and NDK 28.2.13676358:

- `flutter analyze`: no issues.
- `flutter test`: all 9 tests passed; light/dark screenshots visually reviewed.
- `go -C core test -race ./...` and `go -C core vet ./...`: passed.
- Full Sailune-Go `go test -race ./...` and `go vet ./...`: passed after the Android publication fix.
- gomobile binding build: ARM64 and x86_64 passed.
- Debug APK build: passed.
- Android 15/API 35 ARM64 emulator integration test: passed with real SQLite and the native bridge.

The first emulator run found Android's denial of hard-link database publication. The shared core now uses Android-only `renameat2(RENAME_NOREPLACE)` for initialization, preserving no-overwrite behavior. The integration test passed after rebuilding that dependency. Host tests also cover concurrent first writes and refusal to replace an existing file. The desktop publication implementation remains unchanged.

No physical Android phone, production signing, live authenticated website access, or Play Store submission was tested. Debug APK size and debug frame timing are not release-performance measurements.

The final app APK was installed and launched separately from the test harness on the emulator. Its empty-library screen was visually inspected and started without an app error.

## Folded corners and scraping flow update

The revised interface passed 15 Flutter tests and static analysis. Tests cover the full-width Add story action, staged sheet transition, keyboard insets, offline saving, retention of form values after cancellation, all five fading messages, the 15-second timeout, network-error dismissal, and the save-versus-cancel race. Updated light/dark cards, the expanded button, the raised form, and the centered scraping dialog were rendered and visually reviewed.

The mobile Go facade passed race tests and vet, including cancellation before worker startup, request cleanup, the 15-second context deadline, and rejection of metadata arriving after cancellation. Android's real bridge/SQLite integration test passed after rebuilding the native AAR with `Prepare` registration. The final normal application APK was rebuilt separately from the integration-test harness.
