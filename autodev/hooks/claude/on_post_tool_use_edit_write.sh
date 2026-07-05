#!/usr/bin/env bash
# PostToolUse(Edit|Write) hook（FR-5.15.2 / 付録G.3）。
# autodev/state/ 配下の JSON が書かれたら 開発進捗状況.md を自動再生成（FR-5.6.7）。
set -uo pipefail

if [ "${AUTODEV_DISABLE_HOOKS:-0}" = "1" ]; then exit 0; fi
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
ROOT="$(_hook_root)"
LOG_DIR="$ROOT/autodev/logs/$(date +%Y-%m-%d)"; mkdir -p "$LOG_DIR"
mkdir -p "$ROOT/autodev/state" 2>/dev/null; printf '{"updated_at":"%s","action":"post_tool_use_edit_write"}' "$(date -Iseconds 2>/dev/null || date)" > "$ROOT/autodev/state/heartbeat.json" 2>/dev/null || true

# 案8: jq 不在では書込みパスを識別できず進捗.md 同期がスキップされる。
# fail-loud（警告 + 続行）にして SessionStart 通告で気付かせる。
INPUT="$(cat)"
FILE_PATH=""
if hook_require_jq "on_post_tool_use_edit_write"; then
  FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)"
else
  exit 0
fi

case "$FILE_PATH" in
  *autodev/state/*.json)
    if "$ROOT/autodev/scripts/update_progress_md.sh"; then
      echo "[hook] 開発進捗状況.md を再生成しました。"
    else
      # 案2: silent fail を防ぐため失敗ログに記録
      echo "[hook] 進捗.md 再生成に失敗（autodev-progress-md skill で手動復旧してください）。" >&2
      hook_log_failure "on_post_tool_use_edit_write" "error" \
        "update_progress_md.sh failed after edit to $FILE_PATH"
    fi
    echo "[$(date -Iseconds 2>/dev/null || date)] regen for $FILE_PATH" >> "$LOG_DIR/hooks_on_post_tool_use_edit_write.log"
    ;;
esac

# 規約14: 言い訳語の機械検出（軽量実行 / warn モード）。
# Edit/Write 直後に進捗.md・state・attestation に「時間制約」「後続作業」等が混入したら
# 即座に AI に警告を返す（fail まではしない。完了宣言時に check_system_completion.sh が hard-fail させる）。
case "$FILE_PATH" in
  *autodev/開発進捗状況.md|*autodev/state/*.json)
    if [ -x "$ROOT/autodev/scripts/check_no_skip_excuses.sh" ]; then
      SKIP_TMP="$LOG_DIR/_skip_check.$$.tmp"
      "$ROOT/autodev/scripts/check_no_skip_excuses.sh" --warn >"$SKIP_TMP" 2>&1 || true
      if grep -q '^\[FAIL\]' "$SKIP_TMP" 2>/dev/null; then
        echo "[hook] ⚠️ 言い訳語ゲート WARN（CLAUDE_MAIN.md 規約14）:" >&2
        grep '^\[FAIL\]' "$SKIP_TMP" | sed 's/^/  /' >&2
        echo "  → フェーズ・ステップを「時間制約」「後続作業」「将来対応」等で打ち切ってはいけません。" >&2
        echo "  → 実施不能なら blocked=true で停止、追加対応は 修正_<理由>.md で修正ループへ。" >&2
        hook_log_failure "on_post_tool_use_edit_write" "warn" \
          "skip-excuse keyword detected in $FILE_PATH"
      fi
      rm -f "$SKIP_TMP" 2>/dev/null || true
    fi
    ;;
esac

# 規約13: 「✅ システム完了」を進捗.md に書き込んだ瞬間にシステム完了ゲートを必須化。
# AI が手順を省略して完了宣言テキストだけを書き込んだ場合に即時警告する
# （set_current.sh と多層で防御）。
case "$FILE_PATH" in
  *autodev/開発進捗状況.md)
    if grep -qE '(✅ ?システム完了|システムループ.*完了)' "$ROOT/autodev/開発進捗状況.md" 2>/dev/null; then
      if [ -x "$ROOT/autodev/scripts/check_system_completion.sh" ]; then
        SYS_TMP="$LOG_DIR/_sys_complete.$$.tmp"
        "$ROOT/autodev/scripts/check_system_completion.sh" >"$SYS_TMP" 2>&1 || {
          echo "[hook] ⚠️ システム完了ゲート NG（CLAUDE_MAIN.md 規約13）:" >&2
          tail -20 "$SYS_TMP" | sed 's/^/  /' >&2
          echo "  → 進捗.md に完了宣言を書きましたが、機械ゲートは PASS していません。" >&2
          echo "  → 未満項目を解消するか、完了宣言を取り消して blocked=true で停止してください。" >&2
          hook_log_failure "on_post_tool_use_edit_write" "error" \
            "system completion gate failed after writing completion text to progress.md"
        }
        rm -f "$SYS_TMP" 2>/dev/null || true
      fi
    fi
    ;;
esac

exit 0
