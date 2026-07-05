#!/usr/bin/env bash
# PostToolUse(Bash: git commit) hook（FR-5.15.2）。
# コミット直後に軽量ゲート（進捗.md 同期）を自動実行する。
set -uo pipefail

if [ "${AUTODEV_DISABLE_HOOKS:-0}" = "1" ]; then exit 0; fi
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
ROOT="$(_hook_root)"
LOG_DIR="$ROOT/autodev/logs/$(date +%Y-%m-%d)"; mkdir -p "$LOG_DIR"

# 案8: jq 不在では git commit 判定不能（軽微）。fail-loud + 続行。
INPUT="$(cat)"
COMMAND=""
if hook_require_jq "on_post_tool_use_git_commit"; then
  COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)"
else
  exit 0
fi

# git commit を含むコマンドのときだけ動作
case "$COMMAND" in
  *git*commit*)
    echo "[$(date -Iseconds 2>/dev/null || date)] post-commit gate" >> "$LOG_DIR/hooks_on_post_tool_use_git_commit.log"
    if ! "$ROOT/autodev/scripts/check_progress_md_sync.sh"; then
      echo "[hook] 警告: 進捗.md が未同期です。" >&2
      hook_log_failure "on_post_tool_use_git_commit" "warn" \
        "progress.md out of sync after git commit"
    fi
    ;;
esac
exit 0
