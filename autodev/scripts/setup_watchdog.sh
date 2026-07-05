#!/usr/bin/env bash
# 無人運用 watchdog の有効化（opt-in）。crontab 登録＋tmux セッション起動。
# 対象: Linux / macOS / WSL（tmux + cron 必須）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
WD="$AUTODEV_DIR/config/watchdog.yaml"
yget(){ grep -E "^$1:" "$WD" 2>/dev/null | head -1 | sed -E "s/^$1:[[:space:]]*//; s/[[:space:]]*#.*$//"; }

# 前提
command -v tmux    >/dev/null 2>&1 || { log_error "tmux が必要です（Windows は WSL を使用）。"; exit 1; }
command -v crontab >/dev/null 2>&1 || { log_error "crontab が必要です。"; exit 1; }
command -v claude  >/dev/null 2>&1 || log_warn "claude が PATH に見つかりません（起動時に解決されればOK）。"

INTERVAL="$(yget interval_min)"; INTERVAL="${INTERVAL:-5}"
SESSION="$(yget tmux_session)"; SESSION="${SESSION:-autodev}"

# enabled: true へ
sed -i -E 's/^enabled:.*/enabled: true              # setup_watchdog.sh が有効化済み/' "$WD"

# crontab 登録（既存の autodev-watchdog 行は置換）
ENTRY="*/$INTERVAL * * * * cd '$REPO_ROOT' && PATH='$PATH' bash autodev/scripts/watchdog.sh >> autodev/logs/watchdog.log 2>&1 # autodev-watchdog"
( crontab -l 2>/dev/null | grep -v 'autodev-watchdog'; echo "$ENTRY" ) | crontab -
log_info "crontab に watchdog を登録しました（$INTERVAL 分毎）。"

# tmux セッション起動
"$SCRIPTS_DIR/start_session.sh" "$SESSION"
cat <<EOF

[OK] 無人運用 watchdog を有効化しました。
  - 監視: $INTERVAL 分毎に autodev/scripts/watchdog.sh が heartbeat を確認
  - 停止検知時: tmux セッション '$SESSION' へ「$(yget resume_prompt)」を自動送信
  - セッションに接続: tmux attach -t $SESSION
  - 無効化: autodev/scripts/teardown_watchdog.sh
  - ログ: autodev/logs/watchdog.log
EOF
