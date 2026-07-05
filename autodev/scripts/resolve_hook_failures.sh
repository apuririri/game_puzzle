#!/usr/bin/env bash
# Hook 失敗ログ (state/hook_failures.ndjson) の解決マーク（案2）。
# 使い方:
#   resolve_hook_failures.sh           # 全件 resolved=true に更新
#   resolve_hook_failures.sh --clear   # 全件削除（truncate）
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

FILE="$STATE_DIR/hook_failures.ndjson"
if [ ! -f "$FILE" ] || [ ! -s "$FILE" ]; then
  echo "[OK] hook 失敗ログ無し（または空）。"
  exit 0
fi

case "${1:-}" in
  --clear)
    : > "$FILE"
    echo "[OK] hook 失敗ログを全削除しました。"
    ;;
  *)
    command -v jq >/dev/null 2>&1 || { echo "ERROR: jq が必要です。" >&2; exit 1; }
    BEFORE="$(grep -c '"resolved":false' "$FILE" 2>/dev/null || echo 0)"
    # ndjson を1行ずつ resolved=true に書換
    TMP="$(mktemp "$FILE.XXXXXX")"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      echo "$line" | jq -c '. + {"resolved": true}' >> "$TMP" 2>/dev/null || echo "$line" >> "$TMP"
    done < "$FILE"
    mv "$TMP" "$FILE"
    echo "[OK] $BEFORE 件を resolved=true に更新しました。"
    ;;
esac
exit 0
