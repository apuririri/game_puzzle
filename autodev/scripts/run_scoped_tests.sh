#!/usr/bin/env bash
# 変更領域限定テスト（FR-5.5.1 / 修正方針 §6-4）。
# 使い方: run_scoped_tests.sh <変更ファイル>...
#  変更ファイルの場所に応じて必要なテストだけ走らせ、最後にビルドスモーク（assembleDebug）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

RUN_UNIT=0
RUN_UI=0
declare -a MAESTRO_FLOWS=()

for f in "$@"; do
  case "$f" in
    app/src/main/*/ui/*|app/src/main/*ui*)       RUN_UNIT=1; RUN_UI=1 ;;
    app/src/main/*)                              RUN_UNIT=1 ;;
    app/src/test/*)                              RUN_UNIT=1 ;;
    app/src/androidTest/*)                       RUN_UI=1 ;;
    maestro/*.yaml)                              MAESTRO_FLOWS+=("$f") ;;
  esac
done

# 引数なしなら単体テストのみ（軽量）
if [ "$#" -eq 0 ]; then RUN_UNIT=1; fi

RC=0
if [ "$RUN_UNIT" = "1" ]; then
  log_info "単体テスト (test_unit.sh)"
  "$SCRIPTS_DIR/test_unit.sh" || RC=1
fi
if [ "$RUN_UI" = "1" ]; then
  log_info "UI テスト (test_ui.sh)"
  "$SCRIPTS_DIR/test_ui.sh" || RC=1
fi
for fl in ${MAESTRO_FLOWS[@]+"${MAESTRO_FLOWS[@]}"}; do
  log_info "Maestro flow: $fl"
  "$SCRIPTS_DIR/test_maestro.sh" "$fl" scoped || RC=1
done

# 全体スモーク: assembleDebug（Web版の Vite build 相当）
log_info "全体スモーク: assembleDebug"
"$SCRIPTS_DIR/run_gradle.sh" assembleDebug -q >/dev/null 2>&1 && log_info "assembleDebug OK" || { log_error "assembleDebug 失敗"; RC=1; }

[ "$RC" = "0" ] && echo "[OK] scoped tests PASS" || echo "[FAIL] scoped tests に失敗あり"
exit "$RC"
