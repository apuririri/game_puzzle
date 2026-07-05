#!/usr/bin/env bash
# UI テスト（Compose UI Test / app/src/androidTest）。デバイス必須。
# 使い方: test_ui.sh [テストクラスFQCN]（省略時は全 androidTest）
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

S="$(device_required "")" || exit 1
stabilize_device "$S"
TIMEOUT="$(lconf connected_test_timeout_sec 1200)"
ARGS=(:app:connectedDebugAndroidTest)
[ -n "${1:-}" ] && ARGS+=("-Pandroid.testInstrumentationRunnerArguments.class=$1")
GRADLE_TIMEOUT="$TIMEOUT" "$SCRIPTS_DIR/run_gradle.sh" "${ARGS[@]}"
RC=$?
[ "$RC" = "0" ] && echo "[OK] UI tests PASS" || echo "[FAIL] UI tests 失敗（レポート: app/build/reports/androidTests/）"
exit "$RC"
