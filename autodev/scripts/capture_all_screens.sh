#!/usr/bin/env bash
# S11 UP2 / UP6 全画面スクショ取得（FR-5.18.3 / FR-5.18.7）。
# inventory.json に列挙された全 Navigation ルートを順に Maestro で表示し、
# autodev/evidence/ui_polish/<screen_id>/(before|after).png を取得する。
# 画面名（route）にスラッシュや波カッコが含まれる場合は screen_id にサニタイズ済み。
#
# 使い方:
#   capture_all_screens.sh --before    # before スクショ取得（UP2）
#   capture_all_screens.sh --after     # after スクショ取得 + diff.md 出力（UP6）
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

PHASE="${1:-}"
case "$PHASE" in
  --before) PHASE="before" ;;
  --after)  PHASE="after"  ;;
  *) echo "使い方: capture_all_screens.sh --before|--after"; exit 2 ;;
esac

CONF="$AUTODEV_DIR/config/ui_polish.yaml"
INVENTORY="$REPO_ROOT/$(conf_get "$CONF" inventory_path "autodev/state/ui_polish/inventory.json")"
EVIDENCE_OUT="$REPO_ROOT/$(conf_get "$CONF" evidence_dir "autodev/evidence/ui_polish")"
REQUIRE_HEADFUL="$(conf_get "$CONF" require_headful true)"
TIMEOUT_SEC="$(conf_get "$CONF" timeout_sec_per_screen 120)"
MAX_RETRY="$(conf_get "$CONF" max_capture_retry 3)"

[ -f "$INVENTORY" ] || { log_error "inventory.json が未生成です。先に list_screens.sh を実行してください。"; exit 1; }
command -v jq >/dev/null 2>&1 || { log_error "jq が必要です"; exit 2; }

# HEADFUL でデバイス確保
if [ "$REQUIRE_HEADFUL" = "true" ]; then export HEADFUL=1; fi
SERIAL="$(pick_device "")" || SERIAL=""
if [ -z "$SERIAL" ]; then
  SERIAL="$("$SCRIPTS_DIR/start_emulator.sh" | tail -1)" || { log_error "デバイス確保失敗"; exit 1; }
fi
stabilize_device "$SERIAL"

# クリーンアンインストール → debug ビルド install → 起動
"$SCRIPTS_DIR/uninstall.sh" "$SERIAL" >/dev/null 2>&1 || true
"$SCRIPTS_DIR/build.sh" debug >/dev/null || { log_error "ビルド失敗"; exit 1; }
"$SCRIPTS_DIR/install.sh" "$(apk_path debug)" "$SERIAL" >/dev/null || exit 1
"$SCRIPTS_DIR/run.sh" "$SERIAL" || { log_error "アプリ起動失敗"; exit 1; }

mkdir -p "$EVIDENCE_OUT"

# 一時 flow ファイルの後始末
TMP_FLOW=""
cleanup() { [ -n "$TMP_FLOW" ] && rm -f "$TMP_FLOW"; }
trap cleanup EXIT

# 1) 通常スクショ（各ルート）
RC=0
# screen_id を inventory から取得（route と並びで）。screen_id 不在の inventory との後方互換のため
# `screen_id // (route|gsub("/";"__")|gsub("[{}]";"_"))` でフォールバック生成。
ROUTES="$(jq -r '.screens[] | "\(.route)\t\(.root_test_tag)\t\(.screen_id // (.route|gsub("/";"__")|gsub("[{}]";"_")))"' "$INVENTORY" 2>/dev/null || true)"

adb_screencap() {  # adb_screencap <out_png>
  local out="$1"
  mkdir -p "$(dirname "$out")"
  "$ADB_BIN" -s "$SERIAL" exec-out screencap -p > "$out" || return 1
  [ -s "$out" ] || return 1
  return 0
}

# 状態を画面に出すための flow を実行（takeScreenshot は flow 内で行わない）。スクショは adb で別取得。
capture_route() {  # capture_route <route> <root_tag> <out_png>
  local route="$1" tag="$2" out="$3"
  TMP_FLOW="$(mktemp -t autodev_capture.XXXXXX)"
  mv "$TMP_FLOW" "${TMP_FLOW}.yaml"
  TMP_FLOW="${TMP_FLOW}.yaml"
  cat > "$TMP_FLOW" <<YAML
appId: $APP_ID
---
- launchApp:
    clearState: false
- assertVisible:
    id: "${tag}"
YAML
  local rc=0
  run_with_timeout "$TIMEOUT_SEC" "$SCRIPTS_DIR/test_maestro.sh" "$TMP_FLOW" "_ui_polish_capture" >/dev/null 2>&1 || rc=$?
  rm -f "$TMP_FLOW"; TMP_FLOW=""
  [ "$rc" = "0" ] || return $rc
  adb_screencap "$out" || return 1
  return 0
}

# 動的状態 flow を実行して画面を出す（その flow は takeScreenshot を持たない）。
# 出された状態を adb で別途撮影する。
capture_state() {  # capture_state <state_flow> <out_png>
  local flow="$1" out="$2"
  local rc=0
  run_with_timeout "$TIMEOUT_SEC" "$SCRIPTS_DIR/test_maestro.sh" "$flow" "_ui_polish_state" >/dev/null 2>&1 || rc=$?
  [ "$rc" = "0" ] || return $rc
  adb_screencap "$out" || return 1
  return 0
}

while IFS=$'\t' read -r route tag screen_id; do
  [ -z "$route" ] && continue
  screen_dir="$EVIDENCE_OUT/$screen_id"
  mkdir -p "$screen_dir"
  out_png="$screen_dir/${PHASE}.png"

  log_info "[$PHASE] $route (screen_id=$screen_id, tag=$tag) → ${out_png#$REPO_ROOT/}"
  ok=0
  i=1
  while [ "$i" -le "$MAX_RETRY" ]; do
    if capture_route "$route" "$tag" "$out_png"; then ok=1; break; fi
    log_warn "  リトライ $i/$MAX_RETRY: $route"
    sleep 2
    i=$((i+1))
  done
  if [ "$ok" = "0" ]; then
    log_error "スクショ取得失敗: $route"
    RC=1
  fi
done <<< "$ROUTES"

# 2) 動的状態スクショ（loading / empty / error）— maestro/_polish/_state_<screen_id>_<state>.yaml があれば実行
DYN_STATES="$(conf_list "$CONF" dynamic_states)"
[ -z "$DYN_STATES" ] && DYN_STATES="loading
empty
error"

while IFS=$'\t' read -r route tag screen_id; do
  [ -z "$route" ] && continue
  screen_dir="$EVIDENCE_OUT/$screen_id"
  for state in $DYN_STATES; do
    state_flow="$MAESTRO_DIR/_polish/_state_${screen_id}_${state}.yaml"
    [ -f "$state_flow" ] || continue
    out_png="$screen_dir/${PHASE}_${state}.png"
    log_info "[$PHASE/$state] $screen_id → ${out_png#$REPO_ROOT/}"
    if ! capture_state "$state_flow" "$out_png"; then
      log_warn "動的状態スクショ取得失敗 ($state): $screen_id"
    fi
  done
done <<< "$ROUTES"

# 3) after フェーズなら diff.md を出力
if [ "$PHASE" = "after" ]; then
  while IFS=$'\t' read -r route tag screen_id; do
    [ -z "$route" ] && continue
    screen_dir="$EVIDENCE_OUT/$screen_id"
    DIFF_MD="$screen_dir/diff.md"
    {
      echo "# UI 改善 before / after — $route"
      echo
      echo "- 画面ルート: \`$route\`"
      echo "- screen_id: \`$screen_id\`"
      echo "- root testTag: \`$tag\`"
      echo
      echo "| 状態 | before | after |"
      echo "|---|---|---|"
      for st in normal $DYN_STATES; do
        if [ "$st" = "normal" ]; then
          b="before.png"; a="after.png"
        else
          b="before_${st}.png"; a="after_${st}.png"
        fi
        [ -f "$screen_dir/$b" ] || [ -f "$screen_dir/$a" ] || continue
        echo "| $st | ![]($b) | ![]($a) |"
      done
    } > "$DIFF_MD"
  done <<< "$ROUTES"
fi

if [ "$RC" -ne 0 ]; then log_error "capture_all_screens $PHASE FAIL"; exit "$RC"; fi
log_info "capture_all_screens $PHASE PASS"
