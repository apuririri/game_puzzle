#!/usr/bin/env bash
# logcat ダンプ（アプリ起動中はプロセス絞り込み / 修正方針 §7-6）。
# 使い方: logcat.sh [対象名] [serial]
# 保存先: autodev/evidence/logcat/<対象名>/logcat_<ts>.txt（パスを echo）
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"
TARGET="${1:-manual}"
S="$(device_required "${2:-}")" || exit 1
OUT="$EVIDENCE_DIR/logcat/$TARGET/logcat_$(date +%Y%m%d_%H%M%S).txt"
dump_logcat "$S" "$OUT"
log_info "logcat: ${OUT#$REPO_ROOT/} ($(wc -l < "$OUT" | tr -d ' ') 行)"
