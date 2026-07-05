#!/usr/bin/env bash
# S14 RG1 デバッグ残骸検出（FR-5.19.2）。
# プロダクション側（app/src/main/）に println / Log.v / Log.setLoggable(true) / localhost / dev URL 等の
# デバッグ用残骸が残っていないか機械検出する。
#
# 使い方:
#   check_no_debug_artifacts.sh         # 検出件数を表示。0 件で PASS
#   check_no_debug_artifacts.sh --warn  # exit 0
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MODE="strict"
[ "${1:-}" = "--warn" ] && MODE="warn"

CONF="$AUTODEV_DIR/config/release.yaml"

# 検出パターン（プロダクション側の本物の問題のみ。識別子・パッケージ名は除外する。）
PATTERNS=(
  '\bprintln\s*\('                          # println の本番側残骸（規約11 違反）
  '\bSystem\.out\.print(ln)?\s*\('
  '\bprintStackTrace\s*\(\)'
  '\bLog\.v\s*\('                            # 本番ビルドで verbose ログ
  'Log\.setLoggable\s*\(.+,\s*Log\.(VERBOSE|DEBUG)\s*\)'
  '"https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)' # 開発端末向け URL を文字列リテラルで持つ場合のみ
  '"https?://[^"]*\.(dev|local|staging)[^"]*"'     # dev/local/staging ドメインを URL 文字列で持つ場合
  '"https?://[^"]*:(3000|8080|8000|5000)/'        # 開発ポートを含む URL 文字列
  'STRICT_MODE.*true'                              # 一部 StrictMode の有効化（要注意）
  'BuildConfig\.APPLICATION_ID\s*\+\s*"\.debug"'   # debug suffix の意図せぬ参照
)

# allowlist（release.yaml から）
ALLOWLIST="$(conf_list "$CONF" debug_artifact_allowlist)"

HITS_FILE="$(mktemp)"
trap 'rm -f "$HITS_FILE" "$HITS_FILE.tmp"' EXIT

SRC="$APP_DIR/src/main"
if [ ! -d "$SRC" ]; then
  echo "[FAIL] app/src/main が存在しません"
  exit 1
fi

for pat in "${PATTERNS[@]}"; do
  grep -rEn --include='*.kt' --include='*.java' --include='*.xml' \
       --exclude-dir=build --exclude-dir=.gradle \
       "$pat" "$SRC" 2>/dev/null \
    | sed "s|^$REPO_ROOT/||" >> "$HITS_FILE" || true
done

# allowlist で除外
if [ -n "$ALLOWLIST" ]; then
  while IFS= read -r al; do
    [ -z "$al" ] && continue
    grep -vE "$al" "$HITS_FILE" > "$HITS_FILE.tmp" && mv "$HITS_FILE.tmp" "$HITS_FILE"
  done <<< "$ALLOWLIST"
fi

sort -u "$HITS_FILE" -o "$HITS_FILE"
COUNT="$(wc -l < "$HITS_FILE" | tr -d ' ')"

if [ "$COUNT" = "0" ]; then
  echo "[OK] check_no_debug_artifacts: 本番側にデバッグ残骸なし"
  exit 0
fi

echo "[FAIL] check_no_debug_artifacts: $COUNT 件のデバッグ残骸（FR-5.19 / 規約11 違反）"
cat "$HITS_FILE"
echo
echo "  → AppLogger 経由のログ・本番 URL（BuildConfig 経由）への置換、または allowlist 追加で対応"

[ "$MODE" = "warn" ] && exit 0 || exit 1
