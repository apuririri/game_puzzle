#!/usr/bin/env bash
# デバイス上スモーク（run_smoke_remote.sh の後継 / 修正方針 §3-6 D7）。
# 使い方: run_smoke_device.sh [serial] [対象名=smoke]
#  - アプリ起動（APP_STARTED マーカー）→ maestro/smoke.yaml → logcat クラッシュスキャン
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

S="$(device_required "${1:-}")" || exit 1
TARGET="${2:-smoke}"

"$ADB_BIN" -s "$S" logcat -c 2>/dev/null || true
echo "[smoke] アプリ起動確認 ($APP_ID @ $S)"
"$SCRIPTS_DIR/run.sh" "$S" || { echo "[smoke][FAIL] アプリ起動"; exit 1; }

if [ -f "$MAESTRO_DIR/smoke.yaml" ]; then
  echo "[smoke] Maestro smoke flow"
  "$SCRIPTS_DIR/test_maestro.sh" "$MAESTRO_DIR/smoke.yaml" "$TARGET" || { echo "[smoke][FAIL] maestro smoke"; exit 1; }
else
  echo "[smoke][WARN] maestro/smoke.yaml 不在（起動確認のみ）"
fi

OUT="$EVIDENCE_DIR/logcat/$TARGET/logcat_$(date +%Y%m%d_%H%M%S).txt"
dump_logcat "$S" "$OUT" >/dev/null
if ! scan_logcat_crash "$OUT"; then
  echo "[smoke][FAIL] logcat にクラッシュ痕跡（${OUT#$REPO_ROOT/}）"
  exit 1
fi
"$SCRIPTS_DIR/screenshot.sh" "$TARGET" "smoke_$(date +%H%M%S)" "$S" >/dev/null || true
echo "[smoke] PASS"
