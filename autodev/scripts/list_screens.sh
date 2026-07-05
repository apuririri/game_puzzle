#!/usr/bin/env bash
# S11 UP1 全画面棚卸し（FR-5.18.2）。
# app/src/main/.../navigation/ の NavHost ルート定義（composable("xxx")）と
# testTag("<画面>_root") を解析し、全 Navigation ルートを inventory.json に列挙する。
#
# 使い方:
#   list_screens.sh           # autodev/state/ui_polish/inventory.json を生成
#   list_screens.sh --print   # JSON を stdout にも出力
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

CONF="$AUTODEV_DIR/config/ui_polish.yaml"
INVENTORY="$REPO_ROOT/$(conf_get "$CONF" inventory_path "autodev/state/ui_polish/inventory.json")"
mkdir -p "$(dirname "$INVENTORY")"

PRINT="0"
[ "${1:-}" = "--print" ] && PRINT="1"

# 1) composable("ルート名") を全 Kotlin ファイルから抽出
ROUTES_FILE="$(mktemp)"
trap 'rm -f "$ROUTES_FILE" "$TAGS_FILE"' EXIT
TAGS_FILE="$(mktemp)"

if [ -d "$APP_DIR/src/main" ]; then
  grep -rEn --include='*.kt' 'composable\(\s*(route\s*=\s*)?"([^"]+)"' "$APP_DIR/src/main" 2>/dev/null \
    | sed -E 's|^.*composable\(\s*(route\s*=\s*)?"([^"]+)".*$|\2|' \
    | sort -u > "$ROUTES_FILE" || true

  grep -rEn --include='*.kt' 'testTag\(\s*"([^"]+_root)"' "$APP_DIR/src/main" 2>/dev/null \
    | sed -E 's|^.*testTag\(\s*"([^"]+_root)".*$|\1|' \
    | sort -u > "$TAGS_FILE" || true
fi

# 2) JSON 化: routes と root testTag を併記。route 名と testTag のマッチングは route 名のサフィックス推定。
NOW="$(date -Iseconds 2>/dev/null || date)"

# route 名をファイルシステム安全な screen_id にサニタイズ（"/" "{" "}" → "_" / 連続 "_" を1つに）
sanitize() { printf '%s' "$1" | sed -E 's#[/{}?]+#_#g; s#_+#_#g; s#^_##; s#_$##'; }

TMP="$(mktemp "${INVENTORY%/*}/.inv.XXXXXX")"
{
  printf '{\n  "generated_at": "%s",\n  "screens": [\n' "$NOW"
  first=1
  while IFS= read -r route; do
    [ -z "$route" ] && continue
    screen_id="$(sanitize "$route")"
    # route から testTag を推定（例: "login" → "login_root"）
    cand_tag="${route}_root"
    has_tag="false"
    if grep -qx "$cand_tag" "$TAGS_FILE" 2>/dev/null; then
      has_tag="true"
    else
      # ルート名から最初のセグメントだけを採用（例 "product/{id}" → "product"）
      seg="$(echo "$route" | sed -E 's|/.*||; s|\?.*||')"
      cand_tag2="${seg}_root"
      if grep -qx "$cand_tag2" "$TAGS_FILE" 2>/dev/null; then
        cand_tag="$cand_tag2"
        has_tag="true"
      else
        # screen_id ベースでもう一度試す
        cand_tag3="${screen_id}_root"
        if grep -qx "$cand_tag3" "$TAGS_FILE" 2>/dev/null; then
          cand_tag="$cand_tag3"
          has_tag="true"
        fi
      fi
    fi
    [ "$first" = "0" ] && printf ',\n'
    printf '    {"route": "%s", "screen_id": "%s", "root_test_tag": "%s", "root_test_tag_present": %s}' \
      "$route" "$screen_id" "$cand_tag" "$has_tag"
    first=0
  done < "$ROUTES_FILE"
  printf '\n  ],\n'
  # 漏れている root testTag（route が紐付かなかったもの）を列挙
  printf '  "unmatched_root_tags": ['
  first=1
  while IFS= read -r tag; do
    [ -z "$tag" ] && continue
    # 対応する route が見つかったか確認
    route_seg="${tag%_root}"
    if grep -qE "^${route_seg}(\$|/|\?)" "$ROUTES_FILE" 2>/dev/null; then continue; fi
    [ "$first" = "0" ] && printf ', '
    printf '"%s"' "$tag"
    first=0
  done < "$TAGS_FILE"
  printf ']\n}\n'
} > "$TMP"
mv "$TMP" "$INVENTORY"

ROUTE_N="$(wc -l < "$ROUTES_FILE" | tr -d ' ')"
TAG_N="$(wc -l < "$TAGS_FILE" | tr -d ' ')"

log_info "list_screens: routes=$ROUTE_N / root_tags=$TAG_N → ${INVENTORY#$REPO_ROOT/}"

if [ "$ROUTE_N" = "0" ]; then
  log_warn "NavHost の composable(\"...\") を検出できませんでした。"
  log_warn "  → app/src/main/.../navigation/ にルート定義があるか確認してください。"
fi

[ "$PRINT" = "1" ] && cat "$INVENTORY"
exit 0
