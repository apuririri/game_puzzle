#!/usr/bin/env bash
# AutoDev for Android 共通ライブラリ。各スクリプトの先頭で source する。
# 役割: リポジトリルート解決 / Android SDK・JDK パス解決 / 設定読み出し / ロギング / OS 判定。
# パス解決はユーザーのシェル設定（.bashrc 等）に依存しない（修正方針 §6-7「自己完結したパス解決」）。

# --- リポジトリルート（git 非依存。autodev/scripts/ から2階層上） ---
_this_dir() { cd "$(dirname "${BASH_SOURCE[0]}")" && pwd; }
COMMON_DIR="$(_this_dir)"
REPO_ROOT="$(cd "$COMMON_DIR/../.." && pwd)"
export REPO_ROOT

# --- 主要パス ---
export APP_DIR="$REPO_ROOT/app"
export MAESTRO_DIR="$REPO_ROOT/maestro"
export AUTODEV_DIR="$REPO_ROOT/autodev"
export SCRIPTS_DIR="$AUTODEV_DIR/scripts"
export STATE_DIR="$AUTODEV_DIR/state"
export EVIDENCE_DIR="$AUTODEV_DIR/evidence"
export ARTIFACTS_DIR="$AUTODEV_DIR/artifacts"
export SECRETS_DIR="$AUTODEV_DIR/secrets"
export PROGRESS_MD="$AUTODEV_DIR/開発進捗状況.md"
export LOOP_YAML="$AUTODEV_DIR/config/loop.yaml"
export ANDROID_ENV_YAML="$AUTODEV_DIR/config/android_env.yaml"

# --- OS 判定 ---
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) export AUTODEV_OS="windows" ;;
  Darwin)               export AUTODEV_OS="macos" ;;
  *)                    export AUTODEV_OS="linux" ;;
esac

# --- ログ ---
log_dir() {
  local d="$AUTODEV_DIR/logs/$(date +%Y-%m-%d)"
  mkdir -p "$d"
  echo "$d"
}
log_info()  { echo "[$(date +%H:%M:%S)] [INFO]  $*" >&2; }
log_warn()  { echo "[$(date +%H:%M:%S)] [WARN]  $*" >&2; }
log_error() { echo "[$(date +%H:%M:%S)] [ERROR] $*" >&2; }

# hooks 無効化エスケープハッチ（FR-5.15.5）
hooks_disabled() { [ "${AUTODEV_DISABLE_HOOKS:-0}" = "1" ]; }

# python ランチャ（ハーネス補助 _conf.py 用。アプリ側に Python 層は無い）
detect_python() {
  for c in python3 python py; do
    if command -v "$c" >/dev/null 2>&1; then echo "$c"; return 0; fi
  done
  return 1
}

# --- 設定読み出し（_conf.py 経由。PyYAML 不在でも簡易パーサで動く） ---
conf_get() {  # conf_get <yaml> <dotted.key> [default]
  local py; py="$(detect_python)" || { echo "${3:-}"; return 0; }
  "$py" "$SCRIPTS_DIR/_conf.py" "$1" "$2" "${3:-}" 2>/dev/null | tail -1
}
lconf() { conf_get "$LOOP_YAML" "$1" "${2:-}"; }          # loop.yaml
aconf() { conf_get "$ANDROID_ENV_YAML" "$1" "${2:-}"; }   # android_env.yaml

# YAML のリスト値を改行区切りで取得する（要 PyYAML or 簡易対応）。
# 使い方: conf_list <yaml> <dotted.key>
# PyYAML があれば dict/list を辿る。無ければ簡易: 該当 key 直下の "- item" 行を抜く。
conf_list() {  # conf_list <yaml> <dotted.key>
  local py; py="$(detect_python)" || return 0
  "$py" - "$1" "$2" 2>/dev/null <<'PYEOF'
import sys, re
path = sys.argv[1]
dotted = sys.argv[2]
try:
    text = open(path, encoding="utf-8").read()
except Exception:
    sys.exit(0)
try:
    import yaml
    data = yaml.safe_load(text) or {}
    cur = data
    for k in dotted.split("."):
        if isinstance(cur, dict) and k in cur:
            cur = cur[k]
        else:
            sys.exit(0)
    if isinstance(cur, list):
        for v in cur:
            if isinstance(v, (dict, list)):
                continue
            print(v)
    sys.exit(0)
except Exception:
    pass
# 簡易: dotted の末端 key を見つけ、直下の "- item" を取り出す。
keys = dotted.split(".")
lines = text.splitlines()
i = 0
indent_stack = [-1]
cur_keys = []
last_indent_for_key = {}
target_key = keys[-1]
parent_path = keys[:-1]
hit = False
while i < len(lines):
    raw = lines[i]
    stripped = raw.strip()
    if not stripped or stripped.startswith("#"):
        i += 1
        continue
    indent = len(raw) - len(raw.lstrip())
    if stripped.startswith("- "):
        if hit:
            v = stripped[2:].strip()
            if v.startswith('"') and v.endswith('"'):
                v = v[1:-1]
            elif v.startswith("'") and v.endswith("'"):
                v = v[1:-1]
            print(v)
        i += 1
        continue
    # スカラ or ネスト開始
    if ":" in stripped:
        key = stripped.split(":", 1)[0].strip()
        # スタック巻き戻し
        while indent_stack and indent <= indent_stack[-1]:
            indent_stack.pop()
            if cur_keys:
                cur_keys.pop()
        indent_stack.append(indent)
        cur_keys.append(key)
        if cur_keys == parent_path + [target_key]:
            hit = True
        else:
            if hit:
                # 既に集め始めていて別の key に来たので終了
                break
    i += 1
PYEOF
}

# --- Android SDK / JDK / Maestro のパス解決 ---
_sdk_root_conf="$(aconf sdk.root "")"
if [ -n "${ANDROID_SDK_ROOT:-}" ]; then :;
elif [ -n "$_sdk_root_conf" ]; then export ANDROID_SDK_ROOT="$_sdk_root_conf"
else export ANDROID_SDK_ROOT="$HOME/Android/Sdk"; fi
export ANDROID_HOME="$ANDROID_SDK_ROOT"

_jdk_dir_conf="$(aconf jdk.dir "")"
if [ -n "$_jdk_dir_conf" ] && [ -x "$_jdk_dir_conf/bin/java" ]; then
  export JAVA_HOME="$_jdk_dir_conf"
elif [ -x "$HOME/.autodev-android/jdk/bin/java" ]; then
  export JAVA_HOME="$HOME/.autodev-android/jdk"
fi
# （JAVA_HOME 未解決時はシステム java に委ねる。検証は check_android_setup.sh）

_maestro_home_conf="$(aconf maestro.home "")"
export MAESTRO_HOME="${_maestro_home_conf:-$HOME/.maestro}"

# PATH（ラッパー内のみで有効。ユーザーのシェル設定は変更しない）
export PATH="$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$MAESTRO_HOME/bin${JAVA_HOME:+:$JAVA_HOME/bin}:$PATH"

# 主要バイナリ（存在チェックは利用側で）
export ADB_BIN="$ANDROID_SDK_ROOT/platform-tools/adb"
[ -x "$ADB_BIN" ] || ADB_BIN="adb"
export EMULATOR_BIN="$ANDROID_SDK_ROOT/emulator/emulator"
export SDKMANAGER_BIN="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
export AVDMANAGER_BIN="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/avdmanager"

# 開発対象アプリの applicationId
export APP_ID="$(lconf application_id com.karakurai.prismalink)"

# --- timeout ラッパ（GNU timeout が無い環境では素通し） ---
run_with_timeout() {  # run_with_timeout <sec> <cmd...>
  local sec="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout --foreground "$sec" "$@"
  else
    "$@"
  fi
}
