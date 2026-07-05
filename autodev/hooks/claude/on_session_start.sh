#!/usr/bin/env bash
# SessionStart hook（FR-5.15.2）。
# 起動時に開発進捗状況.md を context として注入し、冪等再開で前回状況を即把握させる。
set -uo pipefail

if [ "${AUTODEV_DISABLE_HOOKS:-0}" = "1" ]; then exit 0; fi
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
ROOT="$(_hook_root)"
PROGRESS="$ROOT/autodev/開発進捗状況.md"
LOG_DIR="$ROOT/autodev/logs/$(date +%Y-%m-%d)"; mkdir -p "$LOG_DIR"
echo "[$(date -Iseconds 2>/dev/null || date)] SessionStart" >> "$LOG_DIR/hooks_on_session_start.log"

# 案8: 起動初期に jq の存在を確認（不在は致命的だが SessionStart の hard fail は避け、明示警告）。
if ! command -v jq >/dev/null 2>&1; then
  echo "===== ⚠️ AutoDev Agent: 環境警告 ====="
  echo "jq が PATH 上に見つかりません。多くの hook（PreToolUse / PostToolUse 等）が fail します。"
  echo "対処: 'apt install jq' / 'brew install jq' / 'choco install jq' を実行してから再起動してください。"
  echo "緊急バイパス: AUTODEV_DISABLE_HOOKS=1（安全網が無効化されます / FR-5.15.5）"
  echo "====="
  hook_log_failure "on_session_start" "error" "jq not found in PATH at session start"
fi

# Android 環境の所在確認（修正方針 §6-3）。詳細検証は check_android_setup.sh / healthcheck.sh が行う。
if [ ! -f "$ROOT/local.properties" ]; then
  echo "===== ⚠️ AutoDev for Android: 環境警告 ====="
  echo "local.properties が未生成です（Android SDK 未セットアップの可能性）。"
  echo "対処: 'bash setup.sh' を実行してください（JDK/SDK/AVD/Maestro を自動導入します）。"
  echo "====="
  hook_log_failure "on_session_start" "warn" "local.properties not found (run setup.sh)"
fi

# 案2: 未解決の hook 失敗を通告（前セッションで silent に積み残された失敗を可視化）。
FAIL_FILE="$ROOT/autodev/state/hook_failures.ndjson"
if [ -f "$FAIL_FILE" ] && [ -s "$FAIL_FILE" ] && command -v jq >/dev/null 2>&1; then
  UNRESOLVED="$(jq -c 'select(.resolved == false)' "$FAIL_FILE" 2>/dev/null | tail -10)"
  if [ -n "$UNRESOLVED" ]; then
    echo ""
    echo "===== ⚠️ 未解決の hook 失敗（直近10件） ====="
    echo "$UNRESOLVED" | jq -r '"  [\(.ts)] (\(.severity)) \(.hook): \(.msg)"' 2>/dev/null || echo "  (詳細は $FAIL_FILE 参照)"
    echo "  → AI: 各失敗の原因を調査・復旧してから作業を継続してください。"
    echo "     解決後は autodev/scripts/resolve_hook_failures.sh で resolved=true に更新（または --clear で全削除）。"
    echo "====="
    echo ""
  fi
fi

echo "===== AutoDev Agent: 前回までの開発進捗（autodev/開発進捗状況.md） ====="
if [ -f "$PROGRESS" ]; then
  cat "$PROGRESS"
else
  echo "（進捗ファイル未生成。autodev/CLAUDE_MAIN.md を参照し、初回起動として進めてください。）"
fi
echo ""
echo "----- 再開地点（autodev/state/current.json） -----"
"$ROOT/autodev/scripts/check_resume_point.sh" 2>/dev/null || true

# 案5: config schema 検証（不整合があれば warn のみ。SessionStart は止めない）。
if [ -x "$ROOT/autodev/scripts/check_config.sh" ]; then
  echo "----- config schema 検証 -----"
  "$ROOT/autodev/scripts/check_config.sh" 2>&1 || hook_log_failure "on_session_start" "warn" "check_config.sh reported errors"
fi

# 案4: state 整合性検証（drift があれば warn のみ）。
if [ -x "$ROOT/autodev/scripts/check_state_consistency.sh" ]; then
  echo "----- state 整合性検証 -----"
  "$ROOT/autodev/scripts/check_state_consistency.sh" 2>&1 || hook_log_failure "on_session_start" "warn" "check_state_consistency.sh reported drift"
fi

# 案6: SKILL ↔ 要件定義書 version 同期検証。
if [ -x "$ROOT/autodev/scripts/check_doc_sync.sh" ]; then
  echo "----- SKILL/doc version 同期 -----"
  "$ROOT/autodev/scripts/check_doc_sync.sh" 2>&1 || hook_log_failure "on_session_start" "warn" "check_doc_sync.sh reported mismatch"
fi

# 案1: 進行中作業 (current.json::mode 非空) があれば resume skill 発動を案内。
# verify_resume_point.sh は resume skill の手順 4 で AI が呼ぶ（SessionStart で重複実行しない）。
if command -v jq >/dev/null 2>&1 && [ -f "$ROOT/autodev/state/current.json" ]; then
  CUR_MODE="$(jq -r '.mode // ""' "$ROOT/autodev/state/current.json" 2>/dev/null)"
  if [ -n "$CUR_MODE" ]; then
    echo ""
    echo "----- ⚠️ 進行中作業あり（mode=$CUR_MODE） -----"
    echo "  → autodev-resume skill を発動し、ground-truth 再検証 (verify_resume_point.sh) を実行してから継続してください。"
  fi
fi

echo "===== ここまで。続けて autodev/CLAUDE_MAIN.md の規約に従って作業してください。 ====="
exit 0
