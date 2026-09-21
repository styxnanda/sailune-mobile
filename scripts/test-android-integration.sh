#!/usr/bin/env bash
set -uo pipefail
log_path="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/sailune-android-integration.log"
flutter test integration_test/library_test.dart -d emulator-5554 --reporter expanded 2>&1 | tee "$log_path"
result=${PIPESTATUS[0]}
if [ "$result" -ne 0 ] && [ "${GITHUB_ACTIONS:-}" = true ]; then
  python3 - "$log_path" <<'PY'
import pathlib, sys
text = '\n'.join(pathlib.Path(sys.argv[1]).read_text().splitlines()[-80:])[-12000:]
print('::error::' + text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A'))
PY
fi
exit "$result"
