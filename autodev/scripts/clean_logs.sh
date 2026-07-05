#!/usr/bin/env bash
# logcat バッファのクリア（検証前のノイズ除去）。使い方: clean_logs.sh [serial]
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"
S="$(device_required "${1:-}")" || exit 1
"$ADB_BIN" -s "$S" logcat -c 2>/dev/null || true
log_info "logcat バッファをクリアしました ($S)"
