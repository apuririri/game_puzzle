#!/usr/bin/env bash
# ADB スクリーンショット取得（実機検証の証跡 / 修正方針 §3-3）。
# 使い方: screenshot.sh [対象名] [ファイル名] [serial]
# 保存先: autodev/evidence/screenshots/<対象名>/<ファイル名 or 連番>.png（パスを echo）
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

TARGET="${1:-manual}"
NAME="${2:-}"
S="$(device_required "${3:-}")" || exit 1
DIR="$EVIDENCE_DIR/screenshots/$TARGET"
mkdir -p "$DIR"
if [ -z "$NAME" ]; then
  N="$(find "$DIR" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')"
  NAME="$(printf '%03d_%s' $((N+1)) "$(date +%H%M%S)")"
fi
OUT="$DIR/${NAME%.png}.png"
"$ADB_BIN" -s "$S" exec-out screencap -p > "$OUT" || { log_error "screencap 失敗"; rm -f "$OUT"; exit 1; }
[ -s "$OUT" ] || { log_error "スクリーンショットが空です"; rm -f "$OUT"; exit 1; }
log_info "スクリーンショット: ${OUT#$REPO_ROOT/}"
echo "$OUT"
