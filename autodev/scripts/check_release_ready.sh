#!/usr/bin/env bash
# S14 RG1 リリース最終ゲート（FR-5.19.2）。
# 11 種の静的ゲートを順次実行し、1 件でも fail なら NG。
# release.yaml::gates で個別ゲートを無効化できる（非推奨。HARNESS_NOTES.md に記録すること）。
#
# 使い方:
#   check_release_ready.sh            # 検査
#   check_release_ready.sh --gate     # 検査 + exit code 厳格化（pre-deploy 用）
#   check_release_ready.sh --warn     # exit 0
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MODE="strict"
GATE_MODE="0"
while [ $# -gt 0 ]; do
  case "$1" in
    --gate) GATE_MODE="1"; shift ;;
    --warn) MODE="warn"; shift ;;
    --strict) MODE="strict"; shift ;;
    *) echo "[FAIL] 不明な引数: $1"; exit 2 ;;
  esac
done

CONF="$AUTODEV_DIR/config/release.yaml"

# release.yaml::gates.<name> の真偽値
enabled() {  # enabled <gate_name>
  local v
  v="$(conf_get "$CONF" "gates.$1" "true")"
  [ "$v" = "true" ]
}

# ゲート定義: name → スクリプト
GATES=(
  "release_clean:check_release_clean.sh"
  "no_mocks:check_no_mocks.sh"
  "design_sync:check_design_sync.sh"
  "room_schema:check_room_schema.sh"
  "dead_assets:check_dead_assets.sh"
  "testtag_coverage:check_testtag_coverage.sh"
  "no_debug_artifacts:check_no_debug_artifacts.sh"
  "manifest_release:check_manifest_release.sh"
  "release_build:check_release_build.sh"
  "release_strings:check_release_strings.sh"
  "dependencies:check_dependencies.sh"
)

FAIL=0
RESULTS_JSON="["
first=1

run_gate() {  # run_gate <name> <script>
  local name="$1" script="$2"
  if ! enabled "$name"; then
    echo "[SKIP] $name (release.yaml::gates.$name=false)"
    [ "$first" = "0" ] && RESULTS_JSON="$RESULTS_JSON,"
    RESULTS_JSON="$RESULTS_JSON{\"gate\":\"$name\",\"result\":\"skipped\"}"
    first=0
    return 0
  fi
  if [ ! -f "$SCRIPTS_DIR/$script" ]; then
    echo "[FAIL] $name: スクリプト不在 $SCRIPTS_DIR/$script"
    FAIL=1
    [ "$first" = "0" ] && RESULTS_JSON="$RESULTS_JSON,"
    RESULTS_JSON="$RESULTS_JSON{\"gate\":\"$name\",\"result\":\"missing\"}"
    first=0
    return 1
  fi
  echo "----- gate: $name -----"
  local rc=0
  # --gate オプションを受け付けるスクリプトはそれを使う。
  # 実行は `bash <script>` 経由でファイルモード（+x の有無）に依存しない。
  if grep -qE '^\s*--gate\)' "$SCRIPTS_DIR/$script" 2>/dev/null; then
    bash "$SCRIPTS_DIR/$script" --gate || rc=$?
  else
    bash "$SCRIPTS_DIR/$script" || rc=$?
  fi
  if [ "$rc" = "0" ]; then
    [ "$first" = "0" ] && RESULTS_JSON="$RESULTS_JSON,"
    RESULTS_JSON="$RESULTS_JSON{\"gate\":\"$name\",\"result\":\"pass\"}"
  else
    FAIL=1
    [ "$first" = "0" ] && RESULTS_JSON="$RESULTS_JSON,"
    RESULTS_JSON="$RESULTS_JSON{\"gate\":\"$name\",\"result\":\"fail\",\"exit_code\":$rc}"
  fi
  first=0
}

for entry in "${GATES[@]}"; do
  run_gate "${entry%%:*}" "${entry##*:}"
done

RESULTS_JSON="$RESULTS_JSON]"

# 結果を attestation 用 JSON として state に書き出し（次のステップ run_release_smoke + RG4 で取り込む）。
OUT="$STATE_DIR/release_gate_last.json"
mkdir -p "$STATE_DIR"
printf '{"checked_at":"%s","gates":%s,"all_pass":%s}\n' \
  "$(date -Iseconds 2>/dev/null || date)" "$RESULTS_JSON" \
  "$([ "$FAIL" = "0" ] && echo true || echo false)" > "$OUT"
log_info "結果記録: ${OUT#$REPO_ROOT/}"

echo
if [ "$FAIL" = "1" ]; then
  echo "[FAIL] check_release_ready: NG"
  echo "  → fail を 修正_リリース_<項目>.md として生成し fix-loop で対応してください（RG3）。"
  [ "$MODE" = "warn" ] && exit 0 || exit 1
fi
echo "[OK] check_release_ready: 全 11 ゲート PASS"
exit 0
