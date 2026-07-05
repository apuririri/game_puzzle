#!/usr/bin/env bash
# 直近成功デプロイの前世代 APK へロールバック（Android 版）。使い方: rollback.sh <target> [--apply]
# 注意: release 署名 APK の versionCode 後退 install は通常拒否されるため、
#       -r 失敗時は uninstall→install（アプリデータ消失）にフォールバックする。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"
source "$SCRIPTS_DIR/_deploy_lib.sh"

TGT="${1:-}"; APPLY=0; [ "${2:-}" = "--apply" ] && APPLY=1
[ -z "$TGT" ] && { echo "使い方: rollback.sh <target> [--apply]"; exit 1; }

PREV="$(ls -t "$STATE_DIR/deploys/$TGT"/*.json 2>/dev/null | sed -n '2p' || true)"
[ -z "$PREV" ] && { log_error "ロールバック先（前回成功デプロイ）が見つかりません"; exit 1; }
PREV_APK_REL="$(jq -r '.apk_path // ""' "$PREV" 2>/dev/null)"
PREV_APK="$REPO_ROOT/$PREV_APK_REL"
[ -f "$PREV_APK" ] || { log_error "前世代 APK が見つかりません: $PREV_APK_REL（artifact_keep を確認）"; exit 1; }

log_info "ロールバック対象 $TGT → $(basename "$PREV") (apk=$PREV_APK_REL)"
if [ "$APPLY" != "1" ]; then
  echo "[dry-run] --apply で実行。前世代 APK を install します（versionCode 後退時は uninstall=データ消失を伴います）。"
  exit 0
fi

SERIAL="$(resolve_target_device "$TGT")" || exit 1
if ! "$ADB_BIN" -s "$SERIAL" install -r -d "$PREV_APK" 2>/dev/null; then
  log_warn "install -r -d 失敗 → uninstall→install にフォールバック（アプリデータ消失）"
  "$ADB_BIN" -s "$SERIAL" uninstall "$APP_ID" >/dev/null 2>&1 || true
  "$ADB_BIN" -s "$SERIAL" install "$PREV_APK" || { log_error "ロールバック install 失敗"; exit 1; }
fi
"$SCRIPTS_DIR/run.sh" "$SERIAL" || log_warn "起動確認に失敗（手動確認を推奨）"
log_info "ロールバック完了"
