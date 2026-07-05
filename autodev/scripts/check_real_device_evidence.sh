#!/usr/bin/env bash
# 実機検証証跡ゲート（check_real_browser_evidence.sh の後継 / 修正方針 §3-3）。
# 使い方: check_real_device_evidence.sh <対象名>
#  - スクショ1枚以上 / logcat ダンプ存在 / 最新 logcat にクラッシュ痕跡なし / attestation に証跡記録
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

TARGET="${1:-}"
[ -z "$TARGET" ] && { echo "[FAIL] 使い方: check_real_device_evidence.sh <対象名>"; exit 1; }
RC=0
SHOT_DIR="$EVIDENCE_DIR/screenshots/$TARGET"
LOGCAT_DIR="$EVIDENCE_DIR/logcat/$TARGET"

SHOTS="$(find "$SHOT_DIR" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')"
if [ "${SHOTS:-0}" -ge 1 ]; then echo "[OK] スクショ $SHOTS 枚（${SHOT_DIR#$REPO_ROOT/}）"; else echo "[FAIL] スクショ証跡なし: ${SHOT_DIR#$REPO_ROOT/}"; RC=1; fi

LATEST_LOG="$(ls -t "$LOGCAT_DIR"/logcat_*.txt 2>/dev/null | head -1 || true)"
if [ -n "$LATEST_LOG" ]; then
  echo "[OK] logcat ダンプ（${LATEST_LOG#$REPO_ROOT/}）"
  if scan_logcat_crash "$LATEST_LOG" >/dev/null; then
    echo "[OK] クラッシュ痕跡なし"
  else
    echo "[FAIL] logcat にクラッシュ痕跡あり: ${LATEST_LOG#$REPO_ROOT/}"
    RC=1
  fi
else
  echo "[FAIL] logcat 証跡なし: ${LOGCAT_DIR#$REPO_ROOT/}"
  RC=1
fi

ATT="$STATE_DIR/attestations/$TARGET.json"
if [ -f "$ATT" ] && command -v jq >/dev/null 2>&1; then
  if jq -e '.real_device_evidence.screenshots_dir // empty' "$ATT" >/dev/null 2>&1; then
    echo "[OK] attestation に real_device_evidence 記録済み"
  else
    echo "[FAIL] attestation に real_device_evidence が未記録（run_real_device_check.sh を実行）"
    RC=1
  fi
else
  echo "[WARN] attestation 未生成（クローズ時に必要）: ${ATT#$REPO_ROOT/}"
fi

[ "$RC" = 0 ] && echo "[OK] 実機検証証跡ゲート PASS ($TARGET)" || echo "[FAIL] 実機検証証跡ゲート NG ($TARGET)"
exit "$RC"
