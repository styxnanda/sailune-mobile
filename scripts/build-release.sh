#!/usr/bin/env bash
# Build the real app and copy it out of Flutter's test-overwritten output folders.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build apk --release --target lib/main.dart --target-platform android-arm64,android-x64
mkdir -p build/releases
cp build/app/outputs/flutter-apk/app-release.apk build/releases/sailune-v0.9.0-android.apk
(cd build/releases && shasum -a 256 sailune-v0.9.0-android.apk > SHA256SUMS)
