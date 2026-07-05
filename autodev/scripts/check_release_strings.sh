#!/usr/bin/env bash
# S14 RG1 文字列リソースのリリース時整合確認（FR-5.19.2）。
# - ハードコード日本語文字列の locale 露出（Composable / View で非リソース指定）
# - res/values-<locale>/strings.xml の未翻訳 placeholder（"TODO" / "FIXME" / "翻訳中"）
#
# 使い方:
#   check_release_strings.sh         # 検査
#   check_release_strings.sh --warn  # exit 0
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MODE="strict"
[ "${1:-}" = "--warn" ] && MODE="warn"

CONF="$AUTODEV_DIR/config/release.yaml"
LOCALES="$(conf_list "$CONF" locales)"
RES_DIR="$APP_DIR/src/main/res"

FAIL=0

# 1) ハードコード日本語文字列の Composable 露出（Text("漢字...") 等）
# strings.xml にあるべきものを inline 文字列で書いてないかチェック。
SRC="$APP_DIR/src/main"
if [ -d "$SRC" ]; then
  HARDCODE="$(grep -rEn --include='*.kt' \
    --exclude-dir=build \
    'Text\([[:space:]]*"[^"]*[一-龯ぁ-んァ-ヶー]+[^"]*"' "$SRC" 2>/dev/null || true)"
  if [ -n "$HARDCODE" ]; then
    echo "[FAIL] Composable 内に日本語のハードコード文字列があります（stringResource(R.string.xxx) へ）:"
    echo "$HARDCODE" | sed "s|^$REPO_ROOT/||" | head -50
    FAIL=1
  fi
fi

# 2) locale ごとの未翻訳 placeholder
if [ -n "$LOCALES" ] && [ -d "$RES_DIR" ]; then
  while IFS= read -r loc; do
    [ -z "$loc" ] && continue
    LOC_DIR="$RES_DIR/values-$loc"
    LOC_XML="$LOC_DIR/strings.xml"
    if [ ! -f "$LOC_XML" ]; then
      echo "[FAIL] 未生成: $LOC_XML (locale=$loc / release.yaml::locales 指定)"
      FAIL=1
      continue
    fi
    PLACEHOLDERS="$(grep -nE '(TODO|FIXME|XXX|翻訳中|untranslated)' "$LOC_XML" || true)"
    if [ -n "$PLACEHOLDERS" ]; then
      echo "[FAIL] $LOC_XML: 未翻訳 placeholder あり"
      echo "$PLACEHOLDERS" | head -20
      FAIL=1
    fi
  done <<< "$LOCALES"
fi

if [ "$FAIL" = "1" ]; then
  echo "[FAIL] check_release_strings: NG"
  [ "$MODE" = "warn" ] && exit 0 || exit 1
fi
echo "[OK] check_release_strings: PASS"
exit 0
