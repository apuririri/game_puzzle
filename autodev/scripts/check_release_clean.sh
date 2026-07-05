#!/usr/bin/env bash
# リリース前クリーンチェック（NFR-6.5.4 / 付録I.1）。
# 顧客提供物（app/ maestro/ docs/設計/）が autodev/ や .claude/ に依存していないか確認。
# 実行時結合（コード）が見つかれば fail。文書・コメント・dev DB パスは warning 扱い。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

FAIL=0
SRC_DIRS=("$APP_DIR" "$MAESTRO_DIR" "$REPO_ROOT/docs/設計")

# コードから autodev|.claude への実行時結合を hard-check。
#  - *.md / CLAUDE.md はリリース時に削除・再整備される文書 → warning。
#  - 証跡/レポート/トレース出力先・dev SQLite(autodev/db)・channel マーカーは許容。
#  - コメント行（#, //, *）の参照は実行時結合でないため warning。
for d in "${SRC_DIRS[@]}"; do
  [ -d "$d" ] || continue
  HITS="$(grep -rIn --exclude-dir=build --exclude-dir=.gradle \
           --exclude='*.md' --exclude='CLAUDE.md' \
           -E '(\.\./)*autodev/|(\.\./)*\.claude/' "$d" 2>/dev/null || true)"
  if [ -n "$HITS" ]; then
    REAL="$(echo "$HITS" \
      | grep -vE 'autodev/evidence' \
      | grep -vE ':[0-9]+:[[:space:]]*(#|//|\*)' \
      | grep -vE '(#|//|\*).*(autodev|\.claude)' \
      || true)"
    if [ -n "$REAL" ]; then
      echo "[FAIL] 顧客提供物のコードがツール本体へ依存しています ($d):"
      echo "$REAL"
      FAIL=1
    fi
  fi
done

# 文書（*.md）の参照は警告のみ（リリース時に AI が再整備・削除する前提）
DOC_HITS="$(grep -rIln --exclude-dir=build --exclude-dir=.gradle \
            --include='*.md' -E 'autodev/|\.claude/' \
            "$APP_DIR" "$MAESTRO_DIR" "$REPO_ROOT/docs" "$REPO_ROOT/README.md" 2>/dev/null || true)"
if [ -n "$DOC_HITS" ]; then
  echo "[WARN] 以下の文書が autodev/ または .claude/ に言及（リリース時に顧客向けへ書き換え/削除）:"
  echo "$DOC_HITS" | sed 's|^|  - |'
fi

if [ "$FAIL" = "0" ]; then echo "[OK] リリースクリーンチェック PASS（コード・設計に依存なし）。"; exit 0; fi
exit 1
