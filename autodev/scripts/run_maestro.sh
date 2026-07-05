#!/usr/bin/env bash
# Maestro 実行ラッパー。素の maestro は PreToolUse hook が禁止する。
# 使い方: run_maestro.sh test <flow.yaml> [args...] / run_maestro.sh --version 等
# loop.yaml::maestro_timeout_sec のタイムアウト付き（MAESTRO_TIMEOUT で上書き可）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MAESTRO_CLI="$MAESTRO_HOME/bin/maestro"
[ -x "$MAESTRO_CLI" ] || MAESTRO_CLI="$(command -v maestro || true)"
[ -n "$MAESTRO_CLI" ] || { log_error "maestro が見つかりません。autodev/scripts/setup_maestro.sh を実行してください。"; exit 1; }

TIMEOUT="${MAESTRO_TIMEOUT:-$(lconf maestro_timeout_sec 600)}"
LOG="$(log_dir)/maestro_$(date +%H%M%S).log"
log_info "maestro $* (timeout=${TIMEOUT}s, log=${LOG#$REPO_ROOT/}, cwd=REPO_ROOT)"
# flow 内の相対パス（takeScreenshot 等）が常にリポジトリルート起点になるよう cwd を固定する。
( cd "$REPO_ROOT" && run_with_timeout "$TIMEOUT" "$MAESTRO_CLI" "$@" ) 2>&1 | tee "$LOG"
RC="${PIPESTATUS[0]}"
[ "$RC" = "124" ] && log_error "maestro がタイムアウトしました（${TIMEOUT}s）。"
exit "$RC"
