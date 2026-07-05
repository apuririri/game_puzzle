#!/usr/bin/env bash
# 稼働監視＋自動再開（cron から N 分毎に実行）。
# heartbeat が stale ＆ current.json が「進行中・非blocked」のときだけ、
# 同一 tmux セッションへ再開プロンプトを送る（追加費用なし）。完了/blocked/質問待ちは何もしない。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
WD="$AUTODEV_DIR/config/watchdog.yaml"
HB="$STATE_DIR/heartbeat.json"
CUR="$STATE_DIR/current.json"
WLOG="$AUTODEV_DIR/logs/watchdog.log"; mkdir -p "$(dirname "$WLOG")"
RCNT="$STATE_DIR/.watchdog_restarts"
log(){ echo "[$(date -Iseconds 2>/dev/null || date)] $*" >> "$WLOG"; }
yget(){ grep -E "^$1:" "$WD" 2>/dev/null | head -1 | sed -E "s/^$1:[[:space:]]*//; s/[[:space:]]*#.*$//"; }

[ -f "$WD" ] || exit 0
[ "$(yget enabled)" = "true" ] || exit 0
command -v tmux >/dev/null 2>&1 || { log "tmux 無し。中止。"; exit 0; }
command -v jq   >/dev/null 2>&1 || { log "jq 無し。中止。"; exit 0; }

STALE_MIN="$(yget stale_min)"; STALE_MIN="${STALE_MIN:-15}"
SESSION="$(yget tmux_session)"; SESSION="${SESSION:-autodev}"
RESUME="$(yget resume_prompt)"; RESUME="${RESUME:-作業を再開して}"
MAXR="$(yget max_restarts_per_hour)"; MAXR="${MAXR:-6}"

# 進行中の作業が無ければ何もしない
[ -f "$CUR" ] || { log "current.json 無し（作業なし）。skip。"; exit 0; }
MODE="$(jq -r '.mode // ""' "$CUR")"; [ -n "$MODE" ] || exit 0
[ "$(jq -r '.blocked // false' "$CUR")" = "true" ] && { log "blocked（人手要因）。skip。"; exit 0; }

# heartbeat の経過秒（無ければ十分古いとみなす）
AGE=999999
if [ -f "$HB" ]; then
  AGE="$(python3 -c "import json,datetime;d=json.load(open('$HB'));t=datetime.datetime.fromisoformat(d['updated_at']);n=datetime.datetime.now(t.tzinfo);print(int((n-t).total_seconds()))" 2>/dev/null || echo 999999)"
fi
THRESH=$(( STALE_MIN * 60 ))
if [ "$AGE" -lt "$THRESH" ]; then exit 0; fi   # まだ稼働中

# レート制限（直近1時間の再開回数）
NOW=$(date +%s); touch "$RCNT"
RECENT=$(python3 -c "import sys,time;now=int(time.time());lines=[int(x) for x in open('$RCNT').read().split() if x.strip().isdigit()];lines=[t for t in lines if now-t<3600];open('$RCNT','w').write('\n'.join(map(str,lines)));print(len(lines))" 2>/dev/null || echo 0)
if [ "${RECENT:-0}" -ge "$MAXR" ]; then log "レート制限（直近1h $RECENT 回 >= $MAXR）。skip。"; exit 0; fi

log "停止検知（heartbeat ${AGE}s >= ${THRESH}s, mode=$MODE）→ 再開を試行。"
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  log "tmux セッション '$SESSION' 不在 → 再起動。"
  "$SCRIPTS_DIR/start_session.sh" "$SESSION" >> "$WLOG" 2>&1 || { log "再起動失敗。"; exit 1; }
  sleep 8
fi
tmux send-keys -t "$SESSION" "$RESUME" Enter && log "再開プロンプト送信: '$RESUME'"
echo "$NOW" >> "$RCNT"
