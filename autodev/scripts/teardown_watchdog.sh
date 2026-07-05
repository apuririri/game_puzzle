#!/usr/bin/env bash
# 無人運用 watchdog の無効化。crontab から除去し enabled:false に戻す。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
WD="$AUTODEV_DIR/config/watchdog.yaml"

if command -v crontab >/dev/null 2>&1; then
  ( crontab -l 2>/dev/null | grep -v 'autodev-watchdog' ) | crontab - || true
  log_info "crontab から watchdog を除去しました。"
fi
sed -i -E 's/^enabled:.*/enabled: false             # teardown 済み/' "$WD"
log_info "watchdog を無効化しました（tmux セッションは手動で終了可: tmux kill-session -t <name>）。"
