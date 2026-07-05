#!/usr/bin/env bash
# 再開地点を1行で提示する。current.json があればそれを、無ければ loops から推定。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

CUR="$STATE_DIR/current.json"
if [ -f "$CUR" ] && command -v jq >/dev/null 2>&1; then
  MODE="$(jq -r '.mode // ""' "$CUR")"
  if [ -z "$MODE" ]; then echo "[resume] 進行中の作業はありません（mode 空 = 完了/未着手）。"; exit 0; fi
  BLOCKED="$(jq -r '.blocked // false' "$CUR")"
  echo "[resume] mode=$MODE target=$(jq -r '.target' "$CUR") phase=$(jq -r '.loop_phase' "$CUR") task=$(jq -r '.current_task_id' "$CUR")"
  echo "         last_step=$(jq -r '.last_step' "$CUR") / blocked=$BLOCKED / updated=$(jq -r '.updated_at' "$CUR")"
  [ "$BLOCKED" = "true" ] && echo "         ※ blocked: $(jq -r '.blocked_reason // ""' "$CUR")（人手要因。再開前に解消が必要）"
  exit 0
fi
# フォールバック: system.json / 進行中ループ
SYS="$STATE_DIR/loops/system.json"
if [ -f "$SYS" ] && command -v jq >/dev/null 2>&1; then
  echo "[resume] current.json 無し。system.json から推定:"
  jq -r '"  phase=\(.current_phase // "?") status=\(.status // "?")"' "$SYS"
  IP="$(jq -r '[.features[]? | select(.status=="in_progress")][0].name // ""' "$SYS")"
  [ -n "$IP" ] && echo "  進行中機能: $IP"
  exit 0
fi
echo "[resume] 状態ファイルが見つかりません（初期状態 / 未着手）。"
exit 0
