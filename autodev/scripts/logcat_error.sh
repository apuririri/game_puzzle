#!/usr/bin/env bash
# logcat からエラー・クラッシュ・統一タグの異常を抽出して表示（原因調査の入口）。
# 使い方: logcat_error.sh [対象名] [serial]   ※クラッシュ痕跡を検出したら exit 1
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"
TARGET="${1:-manual}"
S="$(device_required "${2:-}")" || exit 1
OUT="$EVIDENCE_DIR/logcat/$TARGET/logcat_error_$(date +%Y%m%d_%H%M%S).txt"
dump_logcat "$S" "$OUT" >/dev/null

echo "== エラー抽出（${OUT#$REPO_ROOT/}） =="
grep -E "FATAL EXCEPTION|AndroidRuntime|ANR in |Process .* has died" "$OUT" | head -40 || true
echo "-- 統一タグの E/W --"
grep -E "^[0-9-]+ [0-9:.]+ +[0-9]+ +[0-9]+ [EW] (AppLog|ApiLog|DbLog|UiLog)" "$OUT" | tail -40 || true
echo "-- その他 Error --"
grep -E " E " "$OUT" | grep -vE "(AppLog|ApiLog|DbLog|UiLog)" | tail -20 || true

if ! scan_logcat_crash "$OUT" >/dev/null; then
  log_error "クラッシュ痕跡を検出しました。上記 FATAL/ANR を調査してください。"
  exit 1
fi
log_info "クラッシュ痕跡なし。"
