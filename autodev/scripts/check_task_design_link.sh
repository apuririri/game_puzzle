#!/usr/bin/env bash
# タスク-設計書紐付けゲート（FR-5.2.3 / 9.9）。
# 使い方: check_task_design_link.sh <対象名>
#  - tasks/<対象名>.json の各タスクが design_doc_ref を持つことを確認
#  - 参照先設計書の全セクション（## 見出し）が少なくとも1タスクから参照されることを確認
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

TARGET="${1:-}"
[ -z "$TARGET" ] && { echo "[FAIL] 対象名を指定してください"; exit 1; }
TASKS="$STATE_DIR/tasks/$TARGET.json"
[ -f "$TASKS" ] || { echo "[FAIL] $TASKS が存在しません"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "[FAIL] jq が必要です"; exit 1; }

FAIL=0

# 1) 全タスクが design_doc_ref を持つか
MISSING="$(jq -r '[.tasks[] | select((.design_doc_ref.file // "")=="" or (.design_doc_ref.section // "")=="")] | length' "$TASKS")"
if [ "$MISSING" -gt 0 ]; then
  echo "[FAIL] design_doc_ref 未設定のタスクが $MISSING 件あります。"
  FAIL=1
else
  echo "[OK] 全タスクに design_doc_ref が設定されています。"
fi

# 2) 参照されている設計書ごとに、セクション網羅を確認
DOCS="$(jq -r '[.tasks[].design_doc_ref.file] | unique[]' "$TASKS")"
for doc in $DOCS; do
  ABS="$REPO_ROOT/$doc"
  if [ ! -f "$ABS" ]; then echo "[WARN] 設計書が見つかりません: $doc（後続で作成予定なら可）"; continue; fi
  # 設計書の ## 見出し一覧
  while IFS= read -r heading; do
    [ -z "$heading" ] && continue
    # この見出しを参照するタスクがあるか（section 文字列に heading が含まれる）
    if ! jq -e --arg d "$doc" --arg h "$heading" \
        '[.tasks[] | select(.design_doc_ref.file==$d and (.design_doc_ref.section|test($h; "x")))] | length > 0' \
        "$TASKS" >/dev/null 2>&1; then
      echo "[WARN] 未カバーのセクション: $doc -> $heading"
    fi
  done < <(grep -E '^##[^#]' "$ABS" | sed 's/^##[[:space:]]*//' || true)
done

[ "$FAIL" = "0" ] && { echo "[OK] タスク-設計書紐付けチェック PASS"; exit 0; } || exit 1
