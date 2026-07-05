#!/usr/bin/env bash
# state ファイル間 drift 検証（案4 / 改善案レポート#4）。
# 使い方:
#   check_state_consistency.sh         # 検証のみ。drift があれば exit 1。
#   check_state_consistency.sh --fix   # 自動修復できる drift だけ即時同期。
# SessionStart hook と attestation 完了時に呼ぶ前提。
#
# 検査項目:
#   1. system.json::features[].status==done ↔ attestations/<F>.json 存在
#   2. attestation 存在 ↔ system.json::features[].status==done
#   3. system.json::persona_test_plan.schedule[].status==completed ↔ state/persona_tests/<N>.json 存在
#   4. system.json::features[i].iterations と loops/<F>.json::iterations の数値一致（存在時のみ）
#   5. 進捗.md と state mtime 同期（check_progress_md_sync.sh に委譲）
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq が必要です。" >&2; exit 2; }

SYS="$STATE_DIR/loops/system.json"
if [ ! -f "$SYS" ]; then
  echo "[SKIP] system.json なし（初期状態 / 未着手）。"
  exit 0
fi

FIX_MODE=0
[ "${1:-}" = "--fix" ] && FIX_MODE=1

FAIL=0

# --- 1) done な feature には attestation がある ---
echo "== [1] features.status=done ↔ attestations/<F>.json 整合 =="
while IFS= read -r fid; do
  [ -z "$fid" ] && continue
  if [ ! -f "$STATE_DIR/attestations/${fid}.json" ]; then
    echo "[FAIL] $fid: system.json で done だが attestation 不在"
    FAIL=1
  fi
done < <(jq -r '.features[]? | select(.status=="done") | .id' "$SYS")

# --- 2) attestation 存在 ↔ features[].status=done ---
echo "== [2] attestations/<F>.json ↔ features.status=done 整合 =="
for af in "$STATE_DIR"/attestations/*.json; do
  [ -f "$af" ] || continue
  TARGET="$(jq -r '.target // ""' "$af")"
  case "$TARGET" in F*) ;; *) continue ;; esac
  STATUS="$(jq -r --arg id "$TARGET" '.features[]? | select(.id==$id) | .status // ""' "$SYS")"
  if [ -z "$STATUS" ]; then
    echo "[WARN] $TARGET: attestation 存在だが system.json::features に該当 ID なし"
  elif [ "$STATUS" != "done" ]; then
    echo "[FAIL] $TARGET: attestation 存在だが system.json での status=$STATUS"
    FAIL=1
  fi
done

# --- 3) persona_test_plan.schedule ↔ state/persona_tests/ 整合 ---
echo "== [3] persona_test_plan.schedule ↔ state/persona_tests/ 整合 =="
while IFS= read -r row; do
  [ -z "$row" ] && continue
  RID="$(echo "$row" | jq -r '.run_id // empty')"
  [ -z "$RID" ] && continue
  RSTATUS="$(echo "$row" | jq -r '.status // ""')"
  # ファイル名は新採番ルールに合わせて 2 形式（ゼロ詰めあり/なし）を許容する。
  # SKILL.md / 要件定義書 B.7 では `<番号>.json`（非ゼロ詰め）を正規だが、
  # 既存運用で 2 桁ゼロ詰めの実施記録も存在するため、両方を探索する。
  FNUM_PAD="$(printf '%02d' "$RID")"
  PFILE=""
  for cand in "$STATE_DIR/persona_tests/${RID}.json" "$STATE_DIR/persona_tests/${FNUM_PAD}.json"; do
    if [ -f "$cand" ]; then PFILE="$cand"; break; fi
  done
  # ファイル不在判定時の表示用既定値
  [ -z "$PFILE" ] && PFILE="$STATE_DIR/persona_tests/${RID}.json"
  if [ -f "$PFILE" ] && [ "$RSTATUS" != "completed" ]; then
    echo "[FAIL] persona run_id=$RID: 実施記録あり ($PFILE) だが schedule.status=$RSTATUS"
    FAIL=1
    if [ "$FIX_MODE" = "1" ]; then
      EXEC_AT="$(jq -r '.executed_at // ""' "$PFILE")"
      RESULT="$(jq -r '.result // ""' "$PFILE")"
      TMP="$(mktemp "$SYS.XXXXXX")"
      jq --argjson rid "$RID" --arg ea "$EXEC_AT" --arg rs "$RESULT" \
        '.persona_test_plan.schedule |= map(if .run_id == $rid then . + {"status":"completed","executed_at":$ea,"result":$rs} else . end)' \
        "$SYS" > "$TMP" && mv "$TMP" "$SYS"
      echo "  [FIX] schedule[run_id=$RID].status=completed に同期しました。"
    fi
  elif [ ! -f "$PFILE" ] && [ "$RSTATUS" = "completed" ]; then
    echo "[FAIL] persona run_id=$RID: schedule.status=completed だが $PFILE 不在"
    FAIL=1
  fi
done < <(jq -c '.persona_test_plan.schedule[]?' "$SYS")

# --- 4) features[i].iterations と loops/<F>.json::iterations の一致 ---
# system.json 側を真とし、--fix では loops/<F>.json を合わせる（feature ループは system.json::features[i] を更新する設計）。
echo "== [4] iterations 数値整合（system.json ↔ loops/<F>.json） =="
while IFS= read -r line; do
  [ -z "$line" ] && continue
  FID="$(echo "$line" | jq -r '.id')"
  SYS_IT="$(echo "$line" | jq -r '.iterations // 0')"
  LOOP_FILE="$STATE_DIR/loops/${FID}.json"
  [ -f "$LOOP_FILE" ] || continue
  LOOP_IT="$(jq -r '.iterations // 0' "$LOOP_FILE")"
  if [ "$SYS_IT" != "$LOOP_IT" ]; then
    echo "[FAIL] $FID: system.json::iterations=$SYS_IT ≠ loops/${FID}.json::iterations=$LOOP_IT"
    FAIL=1
    if [ "$FIX_MODE" = "1" ]; then
      TMP="$(mktemp "$LOOP_FILE.XXXXXX")"
      jq --argjson it "$SYS_IT" '.iterations = $it' "$LOOP_FILE" > "$TMP" && mv "$TMP" "$LOOP_FILE"
      echo "  [FIX] loops/${FID}.json::iterations=$SYS_IT に同期しました。"
    fi
  fi
done < <(jq -c '.features[]?' "$SYS")

# --- 5) 進捗.md 同期 ---
echo "== [5] 進捗.md ↔ state mtime 同期 =="
"$SCRIPTS_DIR/check_progress_md_sync.sh" || FAIL=1

if [ "$FAIL" = "1" ]; then
  echo
  echo "[FAIL] state 不整合あり。"
  echo "  → --fix で部分自動修復、または手動で対応してください。"
  exit 1
fi
echo "[OK] state 整合性 OK"
exit 0
