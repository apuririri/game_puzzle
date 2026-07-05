#!/usr/bin/env bash
# claude を名前付き tmux セッションで常駐起動する（無人運用の土台）。
# 使い方: start_session.sh [session名]
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
WD="$AUTODEV_DIR/config/watchdog.yaml"
yget(){ grep -E "^$1:" "$WD" 2>/dev/null | head -1 | sed -E "s/^$1:[[:space:]]*//; s/[[:space:]]*#.*$//"; }
SESSION="${1:-$(yget tmux_session)}"; SESSION="${SESSION:-autodev}"

command -v tmux >/dev/null 2>&1 || { log_error "tmux が必要です（無人運用は Linux/macOS/WSL）。"; exit 1; }
if tmux has-session -t "$SESSION" 2>/dev/null; then log_info "tmux セッション '$SESSION' は既に存在します。"; exit 0; fi
cd "$REPO_ROOT"
tmux new-session -d -s "$SESSION" "claude --dangerously-skip-permissions"
log_info "tmux セッション '$SESSION' で claude を起動しました（接続: tmux attach -t $SESSION）。"
