#!/usr/bin/env bash
# Gradle 実行ラッパー（FR-5.13 相当）。素の gradle/gradlew は PreToolUse hook が禁止する。
# 使い方: run_gradle.sh <task> [args...]
#  - JAVA_HOME / ANDROID_SDK_ROOT を解決し、local.properties を自動整備
#  - loop.yaml::gradle_build_timeout_sec のタイムアウト付き（GRADLE_TIMEOUT で上書き可）
#  - ログを autodev/logs/<日付>/ に記録
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

[ -x "$REPO_ROOT/gradlew" ] || { log_error "gradlew が見つかりません（リポジトリ直下）。"; exit 1; }
if [ -z "${JAVA_HOME:-}" ] && ! command -v java >/dev/null 2>&1; then
  log_error "JDK が見つかりません。bash setup.sh を実行してください。"; exit 1
fi

# local.properties 整備（git 管理外。SDK パスを自動注入）
if [ ! -f "$REPO_ROOT/local.properties" ] && [ -d "$ANDROID_SDK_ROOT" ]; then
  echo "sdk.dir=$ANDROID_SDK_ROOT" > "$REPO_ROOT/local.properties"
  log_info "local.properties を生成（sdk.dir=$ANDROID_SDK_ROOT）"
fi

TIMEOUT="${GRADLE_TIMEOUT:-$(lconf gradle_build_timeout_sec 900)}"
LOG="$(log_dir)/gradle_$(date +%H%M%S).log"
log_info "gradle $* (timeout=${TIMEOUT}s, log=${LOG#$REPO_ROOT/})"
( cd "$REPO_ROOT" && run_with_timeout "$TIMEOUT" ./gradlew "$@" ) 2>&1 | tee "$LOG"
RC="${PIPESTATUS[0]}"
if [ "$RC" = "124" ]; then log_error "gradle がタイムアウトしました（${TIMEOUT}s）。"; fi
if [ "$RC" != "0" ]; then
  log_error "gradle 失敗 (rc=$RC)。エラー要約:"
  grep -E "^e: |error:|FAILURE:|What went wrong|Caused by:" "$LOG" | head -20 >&2 || true
fi
exit "$RC"
