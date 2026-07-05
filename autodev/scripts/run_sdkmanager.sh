#!/usr/bin/env bash
# sdkmanager 実行ラッパー。素の sdkmanager は PreToolUse hook が禁止する。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
[ -x "$SDKMANAGER_BIN" ] || { log_error "sdkmanager が見つかりません。bash setup.sh を実行してください。"; exit 1; }
LOG="$(log_dir)/sdkmanager_$(date +%H%M%S).log"
"$SDKMANAGER_BIN" "$@" 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
