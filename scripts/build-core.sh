#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../core"
: "${ANDROID_HOME:?Set ANDROID_HOME to your Android SDK directory}"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$ANDROID_HOME/ndk/28.2.13676358}"
export PATH="$(go env GOPATH)/bin:$PATH"
mkdir -p ../android/app/libs
# ARM64 phones + x86_64 emulators. SQLite's current mobile support is 64-bit.
gomobile bind -target=android/arm64,android/amd64 -androidapi 24 -o ../android/app/libs/sailune.aar ./mobile
