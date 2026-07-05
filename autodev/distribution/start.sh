#!/usr/bin/env bash
# LAN 内 APK 配信サーバーの起動。
# 使い方:
#   autodev/distribution/start.sh         # フォアグラウンド
#   autodev/distribution/start.sh --bg    # nohup でバックグラウンド
#   autodev/distribution/start.sh --stop  # 停止
#
# port: 既定 9080（PORT 環境変数で変更可）
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDFILE="$HERE/.server.pid"
LOGFILE="$HERE/.server.log"
PORT="${PORT:-9080}"

stop() {
  if [ -f "$PIDFILE" ]; then
    PID="$(cat "$PIDFILE" 2>/dev/null || echo)"
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
      kill "$PID" && sleep 1
      kill -0 "$PID" 2>/dev/null && kill -9 "$PID"
      echo "stopped pid=$PID"
    fi
    rm -f "$PIDFILE"
  else
    echo "no pidfile"
  fi
}

status() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
    echo "running pid=$(cat "$PIDFILE") url=http://${IP}:${PORT}/"
  else
    echo "not running"
  fi
}

sync_apk() {
  # 最新の release APK を www/ に配置
  WWW="$HERE/www"
  APK="$(ls -t "$HERE/../artifacts/"*.apk 2>/dev/null | head -1)"
  if [ -z "${APK:-}" ]; then
    echo "[WARN] artifacts/ に APK が見つかりません" >&2
    return 0
  fi
  cp -u "$APK" "$WWW/$(basename "$APK")"
  ln -sf "$(basename "$APK")" "$WWW/latest.apk"
  echo "[OK] sync: $(basename "$APK") (latest.apk -> $(basename "$APK"))"
}

case "${1:-fg}" in
  --stop|stop) stop ;;
  --status|status) status ;;
  --sync|sync) sync_apk ;;
  --bg|bg)
    stop >/dev/null 2>&1 || true
    sync_apk
    nohup python3 "$HERE/server.py" >> "$LOGFILE" 2>&1 &
    echo $! > "$PIDFILE"
    sleep 0.5
    status
    echo "log: $LOGFILE"
    ;;
  --fg|fg|*)
    sync_apk
    exec python3 "$HERE/server.py"
    ;;
esac
