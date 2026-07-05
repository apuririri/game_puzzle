#!/usr/bin/env bash
# 網羅テスト（FR-5.5.1 / 修正方針 §6-4）。別フェーズ・S10 全体スモーク用。
# 単体テスト全部 + Compose UI Test 全部 + maestro/ 全 flow（smoke.yaml 先頭）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

RC=0
log_info "単体テスト（全部）"
"$SCRIPTS_DIR/test_unit.sh" || RC=1

# デバイス確保（無ければエミュレータ）
SERIAL="$(pick_device "")" || SERIAL=""
[ -z "$SERIAL" ] && SERIAL="$("$SCRIPTS_DIR/start_emulator.sh" | tail -1)"
[ -z "$SERIAL" ] && { log_error "デバイス確保に失敗"; exit 1; }

log_info "最新ビルドをインストール"
"$SCRIPTS_DIR/build.sh" debug >/dev/null && "$SCRIPTS_DIR/install.sh" "$(apk_path debug)" "$SERIAL" >/dev/null || RC=1

log_info "Compose UI Test（全部）"
"$SCRIPTS_DIR/test_ui.sh" || RC=1

log_info "Maestro 全 flow"
FLOWS="$(ls "$MAESTRO_DIR"/*.yaml 2>/dev/null || true)"
if [ -n "$FLOWS" ]; then
  # smoke.yaml を先頭に
  for fl in $( { echo "$FLOWS" | grep '/smoke.yaml$'; echo "$FLOWS" | grep -v '/smoke.yaml$'; } ); do
    "$SCRIPTS_DIR/test_maestro.sh" "$fl" full || RC=1
  done
else
  log_warn "maestro/*.yaml がありません。"
fi

[ "$RC" = "0" ] && echo "[OK] full tests PASS" || echo "[FAIL] full tests に失敗あり"
exit "$RC"
