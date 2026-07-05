#!/usr/bin/env bash
# Maestro E2E 実行。使い方: test_maestro.sh <flow.yaml|ディレクトリ> [対象名]
# 証跡（スクショ・ログ）は autodev/evidence/maestro/<対象名>/ に保存。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

FLOW="${1:-}"
TARGET="${2:-maestro}"
[ -z "$FLOW" ] && { echo "使い方: test_maestro.sh <flow.yaml|ディレクトリ> [対象名]"; exit 1; }
[ -e "$FLOW" ] || { [ -e "$REPO_ROOT/$FLOW" ] && FLOW="$REPO_ROOT/$FLOW"; }
[ -e "$FLOW" ] || FLOW="$MAESTRO_DIR/$(basename "$1")"
[ -e "$FLOW" ] || { log_error "flow が見つかりません: $1"; exit 1; }
# 絶対パス化（run_maestro.sh は REPO_ROOT に cd して実行するため）
case "$FLOW" in /*) ;; *) FLOW="$(cd "$(dirname "$FLOW")" && pwd)/$(basename "$FLOW")" ;; esac
S="$(device_required "")" || exit 1
stabilize_device "$S"
OUT="$EVIDENCE_DIR/maestro/$TARGET/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"
"$SCRIPTS_DIR/run_maestro.sh" test --debug-output "$OUT" "$FLOW"
RC=$?
log_info "maestro 証跡: ${OUT#$REPO_ROOT/}"
[ "$RC" = "0" ] && echo "[OK] maestro PASS" || echo "[FAIL] maestro 失敗（証跡: ${OUT#$REPO_ROOT/}）"
exit "$RC"
