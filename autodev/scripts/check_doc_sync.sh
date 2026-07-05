#!/usr/bin/env bash
# SKILL.md::required_doc_version と autodev/docs/要件定義書.md::版数 の照合（案6）。
# SessionStart hook と CI で実行。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

DOC="$AUTODEV_DIR/docs/要件定義書.md"
if [ ! -f "$DOC" ]; then
  echo "[SKIP] 要件定義書.md 不在。"
  exit 0
fi

# "- 版数: 5.0（最終確定版・完全自己完結）" の "5.0" を抽出（先頭の dash 有無は許容）。
DOC_VER="$(grep -E '^[-*]?[[:space:]]*版数:' "$DOC" | head -1 | sed -E 's/^[-*]?[[:space:]]*版数:[[:space:]]*([0-9]+(\.[0-9]+)*).*/\1/')"
if [ -z "$DOC_VER" ]; then
  echo "[WARN] 要件定義書.md から版数を抽出できません。スキーマ確認してください。"
  exit 0
fi
echo "要件定義書 version: $DOC_VER"

FAIL=0
MISS=0
for sk in "$AUTODEV_DIR"/skills/*/SKILL.md; do
  [ -f "$sk" ] || continue
  NAME="$(basename "$(dirname "$sk")")"
  REQ_VER="$(grep -E '^required_doc_version:' "$sk" | head -1 | sed -E 's/^required_doc_version:[[:space:]]*"?([0-9]+(\.[0-9]+)*)"?.*/\1/')"
  if [ -z "$REQ_VER" ]; then
    echo "[WARN] $NAME: required_doc_version 未設定"
    MISS=1
    continue
  fi
  if [ "$REQ_VER" != "$DOC_VER" ]; then
    echo "[FAIL] $NAME: required_doc_version=$REQ_VER ≠ doc=$DOC_VER"
    FAIL=1
  fi
done

[ "$FAIL" = "1" ] && exit 1
[ "$MISS" = "1" ] && exit 1
echo "[OK] 全 SKILL の required_doc_version が要件定義書 ($DOC_VER) と整合。"
exit 0
