#!/usr/bin/env bash
# UserPromptSubmit hook（FR-5.15.2 / FR-5.1.7）。
# 起動プロンプトのモード判定（開発3形態＋デプロイ＋洗い替え）を文脈として返す。
set -uo pipefail

if [ "${AUTODEV_DISABLE_HOOKS:-0}" = "1" ]; then exit 0; fi
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
ROOT="$(_hook_root)"
LOG_DIR="$ROOT/autodev/logs/$(date +%Y-%m-%d)"; mkdir -p "$LOG_DIR"

# 案8: jq 不在は致命的ではないが、モード判定がスキップされる。warn + 続行。
PROMPT=""
if command -v jq >/dev/null 2>&1; then
  INPUT="$(cat)"
  PROMPT="$(echo "$INPUT" | jq -r '.prompt // .user_prompt // ""' 2>/dev/null)"
else
  cat >/dev/null   # stdin を捨てる
  hook_log_failure "on_user_prompt_submit" "warn" "jq not found; mode detection skipped"
  echo "[AutoDev] 警告: jq が無いためモード判定をスキップしました（hook_failures.ndjson 記録済）。" >&2
fi
echo "[$(date -Iseconds 2>/dev/null || date)] prompt: ${PROMPT:0:80}" >> "$LOG_DIR/hooks_on_user_prompt_submit.log"

emit() { echo "[AutoDev] $*"; }

case "$PROMPT" in
  *作業*再開*|*続きから*|*再開して*)
    emit "モード判定: 再開（skill: autodev-resume）。current.json と 進捗.md から直前位置を復元し、ground-truth 再検証の上で継続します。"
    ;;
  *デプロイ*)
    emit "モード判定: デプロイ（skill: autodev-deploy）。"
    emit "  「<source> から <target> へデプロイ」の形で source/target を autodev/config/deploy.yaml から解決します。"
    emit "  既定は dry-run。実行は deploy.sh ... --apply、本番(requires_approval)は承認後に --approve。"
    ;;
  *洗い替え*|*クリーンアップ*|*不要*データ*)
    emit "モード判定: 洗い替え（skill: autodev-cleanup）。"
    emit "  既定は dry-run（対象提示のみ）。アーカイブ後に prune、--full-reset で運用履歴をクリーンスレート化。"
    ;;
  *要件定義書*自動*開発*|*要件定義書*システム*)
    emit "モード判定: システム全体開発（skill: autodev-system-loop）。入力: autodev/inputs/要件定義/要件定義書.md"
    [ -f "$ROOT/autodev/inputs/要件定義/要件定義書.md" ] || emit "警告: 要件定義書.md が見つかりません。"
    ;;
  *機能要件*機能*開発*|*機能要件_*)
    emit "モード判定: 機能単位開発（skill: autodev-feature-loop / F1〜F7）。"
    emit "  F6.5 ペルソナ駆動テスト必須（FR-5.9.8 / scope=feature:<機能名>）。"
    emit "  F7 クローズゲートに check_persona_test_evidence.sh <機能名> feature を含めます。"
    ;;
  *修正*対応*|*修正_*)
    emit "モード判定: 修正対応（skill: autodev-fix-loop / R1〜R7）。"
    emit "  R6.5 ペルソナ駆動テスト必須（FR-5.9.9 / scope=fix:<修正名>）。"
    emit "  R7 クローズゲートに check_persona_test_evidence.sh <修正名> fix を含めます。"
    emit "  ※ source_scope が feature/fix の修正対応書（ペルソナテスト由来）は R6.5 をスキップ（無限ループ防止）。"
    ;;
  *) : ;;
esac
exit 0
