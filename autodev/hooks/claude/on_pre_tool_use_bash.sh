#!/usr/bin/env bash
# PreToolUse(Bash) hook（FR-5.15.2 / 付録G.2）。
# 素の gradle/gradlew/adb/emulator/avdmanager/sdkmanager/maestro/apksigner 直接実行を禁止し、ラッパー使用を促す。
#
# 検出方針（正規表現ではなくトークン解析で堅牢化）:
#  1. クォート内文字列を除去（コミットメッセージ等の誤検出を防ぐ）。
#  2. ; && || | & ` ( ) と改行でコマンドを分割。
#  3. 各セグメント先頭の「VAR=val 代入」「sudo/time/nice/env/command/exec/xargs」「-オプション」を剥がす。
#  4. 残った先頭トークンの basename が対象コマンド（gradle/gradlew/adb/emulator/avdmanager/sdkmanager/maestro/apksigner）なら fail。
#     autodev/scripts/run_*.sh 等のラッパーは basename が一致しないため通過（./gradlew も basename=gradlew で検出）。
set -uo pipefail

if [ "${AUTODEV_DISABLE_HOOKS:-0}" = "1" ]; then exit 0; fi
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
ROOT="$(_hook_root)"
LOG_DIR="$ROOT/autodev/logs/$(date +%Y-%m-%d)"; mkdir -p "$LOG_DIR"
mkdir -p "$ROOT/autodev/state" 2>/dev/null; printf '{"updated_at":"%s","action":"pre_tool_use_bash"}' "$(date -Iseconds 2>/dev/null || date)" > "$ROOT/autodev/state/heartbeat.json" 2>/dev/null || true

# 案8: jq 不在では検査機能が無効化される（素のコマンドが素通り）。
# ただし PreToolUse(Bash) を exit 1 にすると jq のインストールコマンドも Bash 経由で実行できず詰むため、
# fail-loud（警告 + 続行）にして SessionStart 通告に検出を委ねる。
INPUT="$(cat)"
COMMAND=""
if hook_require_jq "on_pre_tool_use_bash"; then
  COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)"
else
  # jq 不在では検査スキップ。素のコマンド禁止規約は実質無効化されるため記録のみ。
  echo "[$(date -Iseconds 2>/dev/null || date)] WARN: jq absent, command not inspected" >> "$LOG_DIR/hooks_on_pre_tool_use_bash.log"
  exit 0
fi
echo "[$(date -Iseconds 2>/dev/null || date)] cmd: ${COMMAND:0:160}" >> "$LOG_DIR/hooks_on_pre_tool_use_bash.log"

is_forbidden_basename() {
  case "${1##*/}" in
    gradle|gradlew|adb|emulator|avdmanager|sdkmanager|maestro|apksigner) return 0 ;;
  esac
  return 1
}

# 1) クォート内を除去
CLEAN="$(printf '%s' "$COMMAND" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")"
# 2) セグメント分割
SEGS="$(printf '%s' "$CLEAN" | sed -E 's/&&|\|\||[;&|()`]/\n/g')"

violation=""
while IFS= read -r seg; do
  # 先頭空白トリム
  seg="${seg#"${seg%%[![:space:]]*}"}"
  [ -z "$seg" ] && continue
  # 3) 接頭辞（代入 / ラッパー / オプション）を剥がす
  while [ -n "$seg" ]; do
    first="${seg%%[[:space:]]*}"
    strip=0
    case "$first" in
      *=*) strip=1 ;;                                            # VAR=val
      -*) strip=1 ;;                                             # -E などのオプション
      sudo|time|nice|env|command|exec|builtin|xargs) strip=1 ;; # ラッパー
    esac
    [ "$strip" = "1" ] || break
    rest="${seg#"$first"}"
    seg="${rest#"${rest%%[![:space:]]*}"}"
  done
  [ -z "$seg" ] && continue
  # 4) 判定
  first="${seg%%[[:space:]]*}"
  if is_forbidden_basename "$first"; then violation="$first"; break; fi
done <<EOF
$SEGS
EOF

if [ -n "$violation" ]; then
  {
    echo "ERROR: 素のコマンド実行は禁止です（検出: $violation）。autodev/scripts/ のラッパー経由で実行してください。"
    echo "  対象コマンド: $COMMAND"
    echo "  例: ./gradlew <task>      → autodev/scripts/run_gradle.sh <task>"
    echo "      adb <args>            → autodev/scripts/run_adb.sh <args>"
    echo "      emulator -avd ...     → autodev/scripts/start_emulator.sh"
    echo "      maestro test ...      → autodev/scripts/run_maestro.sh test ..."
    echo "      sdkmanager/avdmanager → autodev/scripts/run_sdkmanager.sh / setup_android_env.sh"
    echo "  高レベル: build.sh / install.sh / run.sh / build_install_run.sh / screenshot.sh / logcat.sh /"
    echo "            test_unit.sh / test_ui.sh / test_maestro.sh / run_real_device_check.sh"
  } >&2
  exit 2
fi
exit 0
