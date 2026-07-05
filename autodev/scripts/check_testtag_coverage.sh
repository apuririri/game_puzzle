#!/usr/bin/env bash
# testTag 付与の簡易検査（修正方針 §3-8。警告レベル運用から開始）。
# ui/screen/ の各画面ファイルに対し、操作可能要素（Button/TextField/clickable）があるのに
# testTag が1つも無いものを WARN。--strict 指定時のみ fail(1)。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

STRICT=0; [ "${1:-}" = "--strict" ] && STRICT=1
MISS=0
SRC="$APP_DIR/src/main"
[ -d "$SRC" ] || { echo "[SKIP] app/src/main 不在。"; exit 0; }

while IFS= read -r f; do
  if grep -qE "Button\(|TextField\(|OutlinedTextField\(|clickable|IconButton\(" "$f"; then
    if ! grep -q "testTag" "$f"; then
      echo "[WARN] testTag が無い画面: ${f#$REPO_ROOT/}（命名規約: <画面>_<要素>_<種別>）"
      MISS=1
    fi
  fi
done < <(find "$SRC" -path '*/ui/*' -name '*.kt' 2>/dev/null || true)

if [ "$MISS" = "0" ]; then echo "[OK] 主要UI要素の testTag 検査 PASS"; exit 0; fi
echo "[INFO] 主要UI要素（ボタン・入力欄・リスト・画面ルート）には必ず testTag を付与してください（絶対規約10）。"
[ "$STRICT" = "1" ] && exit 1 || exit 0
