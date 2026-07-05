#!/usr/bin/env bash
# 高レベル実機検証ラッパー（run_real_browser_check.sh の後継 / 修正方針 §3-3）。
# 使い方: run_real_device_check.sh <対象名> [検証指定]
#   検証指定:
#     *.yaml          → Maestro flow（相対なら maestro/ 配下）
#     <FQCN>          → Compose UI Test クラス（例 com.karakurai.prismalink.ui.LoginScreenTest）
#     省略時          → maestro/<対象名>.yaml があればそれ、無ければ androidTest 全体
# 処理: デバイス確保 → logcat クリア → build → install → 起動 → 検証実行
#       → ADB スクショ → logcat ダンプ + クラッシュスキャン → attestation へ証跡記録
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

TARGET="${1:-}"
[ -z "$TARGET" ] && { log_error "使い方: run_real_device_check.sh <対象名> [maestro_flow.yaml|テストクラスFQCN]"; exit 1; }
VERIFY="${2:-}"

SHOT_DIR="$EVIDENCE_DIR/screenshots/$TARGET"
LOGCAT_DIR="$EVIDENCE_DIR/logcat/$TARGET"
mkdir -p "$SHOT_DIR" "$LOGCAT_DIR"

# 1) デバイス確保（無ければエミュレータ起動）
SERIAL="$(pick_device "")" || SERIAL=""
if [ -z "$SERIAL" ]; then
  SERIAL="$("$SCRIPTS_DIR/start_emulator.sh" | tail -1)" || { log_error "デバイス確保に失敗"; exit 1; }
fi
stabilize_device "$SERIAL"

# 2) logcat クリア
"$ADB_BIN" -s "$SERIAL" logcat -c 2>/dev/null || true

# 3) build → install → 起動
"$SCRIPTS_DIR/build.sh" debug >/dev/null || { log_error "ビルド失敗"; exit 1; }
"$SCRIPTS_DIR/install.sh" "$(apk_path debug)" "$SERIAL" >/dev/null || exit 1
"$SCRIPTS_DIR/run.sh" "$SERIAL" || { log_error "アプリ起動失敗"; exit 1; }

# 4) 検証実行
RC=0
if [ -z "$VERIFY" ] && [ -f "$MAESTRO_DIR/$TARGET.yaml" ]; then VERIFY="$MAESTRO_DIR/$TARGET.yaml"; fi
case "$VERIFY" in
  *.yaml)
    log_info "実機検証（Maestro）: $VERIFY"
    "$SCRIPTS_DIR/test_maestro.sh" "$VERIFY" "$TARGET" || RC=$?
    ;;
  "")
    log_info "実機検証（Compose UI Test 全体）"
    "$SCRIPTS_DIR/test_ui.sh" || RC=$?
    ;;
  *)
    log_info "実機検証（Compose UI Test）: $VERIFY"
    "$SCRIPTS_DIR/test_ui.sh" "$VERIFY" || RC=$?
    ;;
esac

# 5) スクリーンショット（最終画面）
"$SCRIPTS_DIR/screenshot.sh" "$TARGET" "final_$(date +%H%M%S)" "$SERIAL" >/dev/null || log_warn "スクショ取得失敗"
SHOTS="$(find "$SHOT_DIR" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')"
log_info "スクショ枚数: $SHOTS （${SHOT_DIR#$REPO_ROOT/}）"

# 6) logcat ダンプ + クラッシュスキャン
LOG_OUT="$LOGCAT_DIR/logcat_$(date +%Y%m%d_%H%M%S).txt"
dump_logcat "$SERIAL" "$LOG_OUT" >/dev/null
if ! scan_logcat_crash "$LOG_OUT"; then
  log_error "logcat にクラッシュ痕跡（${LOG_OUT#$REPO_ROOT/}）"
  RC=1
fi

# 7) attestation へ証跡記録（real_device_evidence + evidence.* / 修正方針 §3-3）
ATT="$STATE_DIR/attestations/$TARGET.json"
if [ -f "$ATT" ] && command -v jq >/dev/null 2>&1; then
  TMP="$(mktemp "${ATT%/*}/.att.XXXXXX")"
  jq --arg sdir "autodev/evidence/screenshots/$TARGET" \
     --arg ldir "autodev/evidence/logcat/$TARGET" \
     --arg ts "$(date -Iseconds 2>/dev/null || date)" \
     --arg serial "$SERIAL" \
     '.real_device_evidence = {screenshots_dir: $sdir, logcat_dir: $ldir, verified_at: $ts, device_serial: $serial}
      | .evidence.screenshots = $sdir
      | .evidence.logcat = $ldir' \
     "$ATT" > "$TMP" && mv "$TMP" "$ATT"
  log_info "attestation に証跡パスを記録: ${ATT#$REPO_ROOT/}"
fi

if [ "$RC" -ne 0 ]; then log_error "実機検証 FAIL (target=$TARGET)"; exit "$RC"; fi
log_info "実機検証 PASS (target=$TARGET)"
