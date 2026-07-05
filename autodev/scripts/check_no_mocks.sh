#!/usr/bin/env bash
# プロダクション側のモック/スタブ/TODO 残存検出（FR-5.17.2 / S10 IV1, S14 RG1）。
# app/src/main/ から Mock/Fake/Stub/Dummy パターンと TODO/FIXME/XXX/HACK コメントを機械検出する。
# テストコード（src/test, src/androidTest）と自動生成（build/, res/）は除外。
#
# 使い方:
#   check_no_mocks.sh           # 検出件数を表示。0 件で PASS、1 件以上で FAIL（exit 1）。
#   check_no_mocks.sh --warn    # exit 0 で続行（軽量実行用）。
#   check_no_mocks.sh --json    # 結果を JSON で stdout に出力（attestation 用）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MODE="strict"
EMIT_JSON="0"
while [ $# -gt 0 ]; do
  case "$1" in
    --warn) MODE="warn"; shift ;;
    --strict) MODE="strict"; shift ;;
    --json) EMIT_JSON="1"; shift ;;
    *) echo "[FAIL] 不明な引数: $1"; exit 2 ;;
  esac
done

CONF="$AUTODEV_DIR/config/integration.yaml"

INCLUDE_DIRS="$(conf_list "$CONF" mock_scan.include_dirs)"
[ -z "$INCLUDE_DIRS" ] && INCLUDE_DIRS="app/src/main"
EXCLUDE_DIRS="$(conf_list "$CONF" mock_scan.exclude_dirs)"
[ -z "$EXCLUDE_DIRS" ] && EXCLUDE_DIRS="app/src/test
app/src/androidTest
app/build
app/src/main/res"
PATTERNS="$(conf_list "$CONF" mock_scan.patterns)"
if [ -z "$PATTERNS" ]; then
  PATTERNS='\b(Mock|Fake|Stub|Dummy)[A-Z][A-Za-z0-9_]*\b
\bFAKE_|\bSTUB_|\bDUMMY_
//\s*(TODO|FIXME|XXX|HACK)\b
/\*\s*(TODO|FIXME|XXX|HACK)\b'
fi
ALLOWLIST="$(conf_list "$CONF" mock_scan.allowlist)"

# grep 除外引数を組み立て。
GREP_EXCLUDE=()
while IFS= read -r d; do
  [ -z "$d" ] && continue
  GREP_EXCLUDE+=(--exclude-dir="$(basename "$d")")
done <<< "$EXCLUDE_DIRS"
GREP_EXCLUDE+=(--exclude-dir=build --exclude-dir=.gradle)

HITS_FILE="$(mktemp)"
trap 'rm -f "$HITS_FILE"' EXIT

# 走査対象ディレクトリごとに grep。
while IFS= read -r incdir; do
  [ -z "$incdir" ] && continue
  ABSDIR="$REPO_ROOT/$incdir"
  [ -d "$ABSDIR" ] || continue
  while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    grep -rEn "${GREP_EXCLUDE[@]}" --include='*.kt' --include='*.java' --include='*.xml' "$pat" "$ABSDIR" 2>/dev/null \
      | sed "s|^$REPO_ROOT/||" >> "$HITS_FILE" || true
  done <<< "$PATTERNS"
done <<< "$INCLUDE_DIRS"

# allowlist で除外。
if [ -n "$ALLOWLIST" ]; then
  while IFS= read -r al; do
    [ -z "$al" ] && continue
    grep -vE "$al" "$HITS_FILE" > "${HITS_FILE}.tmp" && mv "${HITS_FILE}.tmp" "$HITS_FILE"
  done <<< "$ALLOWLIST"
fi

# 重複除去。
sort -u "$HITS_FILE" -o "$HITS_FILE"
COUNT="$(wc -l < "$HITS_FILE" | tr -d ' ')"

if [ "$EMIT_JSON" = "1" ]; then
  printf '{"hits_count":%d,"hits":[' "$COUNT"
  first=1
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [ "$first" = "0" ] && printf ','
    printf '%s' "$(printf '%s' "$line" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip()))' 2>/dev/null || printf '"%s"' "${line//\"/\\\"}")"
    first=0
  done < "$HITS_FILE"
  printf ']}\n'
  exit 0
fi

if [ "$COUNT" = "0" ]; then
  echo "[OK] check_no_mocks: プロダクション側にモック/スタブ/TODO 残存なし（走査: $INCLUDE_DIRS）"
  exit 0
fi

echo "[FAIL] check_no_mocks: $COUNT 件のモック/スタブ/TODO 残存（FR-5.17 違反 / S10 IV1）"
cat "$HITS_FILE"
echo
echo "  → 各検出について autodev/inputs/修正対応/修正_デモック_<モジュール>.md を生成し、"
echo "     fix-loop で実プログラム化してください（規約12〜15）。"
echo "     正当な例外は autodev/config/integration.yaml::mock_scan.allowlist に追加し理由を明記。"

[ "$MODE" = "warn" ] && exit 0 || exit 1
