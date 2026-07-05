#!/usr/bin/env bash
# 現在地ポインタ autodev/state/current.json を更新する（再開の起点）。
# 使い方: set_current.sh <mode> <target> <loop_phase> <task_id> <last_step> [blocked(true/false)] [reason]
#   例: set_current.sh feature ログイン F4 3 "ログイン画面コンポーネント実装" false ""
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MODE="${1:-}"; TARGET="${2:-}"; PHASE="${3:-}"; TASK="${4:-}"; STEP="${5:-}"; BLOCKED="${6:-false}"; REASON="${7:-}"
mkdir -p "$STATE_DIR"
CUR="$STATE_DIR/current.json"

# 規約13: 完了宣言（mode を空にする）は機械ゲート PASS が前提。
# mode="" かつ blocked=false の場合のみ「完了宣言」とみなし、check_system_completion.sh を必須化する。
# blocked=true（人手介入待ち停止）や、システム以外のループ完了（mode を一時的に変更）は対象外。
# 同スクリプトは S10/S11/S14 の 3 attestation の存在も検査する（規約 12〜15）。
if [ -z "$MODE" ] && [ "$BLOCKED" != "true" ]; then
  if [ -x "$SCRIPTS_DIR/check_system_completion.sh" ]; then
    echo "[set_current] 完了宣言検出（mode=\"\" かつ blocked=false）。check_system_completion.sh を実行..."
    if ! "$SCRIPTS_DIR/check_system_completion.sh"; then
      echo
      echo "[set_current] [FAIL] システム完了ゲート NG（CLAUDE_MAIN.md 規約13）。"
      echo "  → 未満項目を解消してから再実行するか、blocked=true で人手介入待ちにしてください。"
      echo "     例: set_current.sh \"\" \"\" \"\" \"\" \"\" true \"未完了の機能あり: ...\""
      echo "     強制バイパス（非推奨。HARNESS_NOTES.md に記録すること）: AUTODEV_FORCE_COMPLETE=1"
      if [ "${AUTODEV_FORCE_COMPLETE:-0}" != "1" ]; then
        exit 1
      fi
      echo "[set_current] [WARN] AUTODEV_FORCE_COMPLETE=1 が設定されているため強制続行します。"
    fi
  fi
fi
TMP="$(mktemp "${CUR%/*}/.current.XXXXXX")"
cat > "$TMP" <<JSON
{
  "mode": "$MODE",
  "target": "$TARGET",
  "loop_phase": "$PHASE",
  "current_task_id": "$TASK",
  "last_step": "$STEP",
  "blocked": $([ "$BLOCKED" = "true" ] && echo true || echo false),
  "blocked_reason": $( [ -n "$REASON" ] && printf '"%s"' "$REASON" || echo null ),
  "updated_at": "$(date -Iseconds 2>/dev/null || date)"
}
JSON
mv "$TMP" "$CUR"
# state 更新に伴い進捗.md を再生成（PostToolUse hook 相当を明示実行）
"$SCRIPTS_DIR/update_progress_md.sh" >/dev/null 2>&1 || true
echo "[set_current] $MODE/$TARGET phase=$PHASE task=$TASK blocked=$BLOCKED"
