#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
go -C core test -race ./...
go -C core vet ./...
