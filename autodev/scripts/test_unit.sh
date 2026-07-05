#!/usr/bin/env bash
# 単体テスト（JUnit / app/src/test）。使い方: test_unit.sh [--tests <pattern>]
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
"$SCRIPTS_DIR/run_gradle.sh" :app:testDebugUnitTest "$@"
RC=$?
[ "$RC" = "0" ] && echo "[OK] unit tests PASS" || echo "[FAIL] unit tests 失敗（レポート: app/build/reports/tests/）"
exit "$RC"
