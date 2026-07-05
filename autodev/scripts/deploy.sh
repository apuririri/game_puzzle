#!/usr/bin/env bash
# デプロイ orchestrator（Android 版 D1〜D8 / 修正方針 §3-6）。
# 使い方: deploy.sh <source> <target> [--apply] [--approve] [--strategy rebuild|promote]
#   既定は dry-run（計画提示＋事前ゲートのみ。実変更しない）。--apply で実行。
#   target.requires_approval=true のときは --approve が必須（AI はユーザー承認後に付与）。
# デプロイ先は AVD（エミュレータ）または開発者実機（adb install）。ストア公開は対象外。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"
source "$SCRIPTS_DIR/_deploy_lib.sh"

SRC="${1:-}"; TGT="${2:-}"; shift 2 2>/dev/null || true
APPLY=0; APPROVE=0; STRAT_OVERRIDE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --approve) APPROVE=1 ;;
    --strategy) shift; STRAT_OVERRIDE="$1" ;;
    *) log_warn "不明な引数: $1" ;;
  esac; shift
done
[ -z "$SRC" ] || [ -z "$TGT" ] && { echo "使い方: deploy.sh <source> <target> [--apply] [--approve] [--strategy rebuild|promote]"; exit 1; }

echo "==== Deploy $SRC -> $TGT (apply=$APPLY) ===="

# D1/D2 事前ゲート
"$SCRIPTS_DIR/check_deploy_ready.sh" "$SRC" "$TGT" || { log_error "事前ゲート NG。中止。"; exit 1; }

# 承認ゲート
REQ_APPROVAL="$(dconf "environments.$TGT.requires_approval" false)"
if [ "$REQ_APPROVAL" = "true" ] && [ "$APPROVE" != "1" ]; then
  log_warn "target '$TGT' は承認必須です。ユーザー承認を得てから --approve を付けて再実行してください。"
  [ "$APPLY" = "1" ] && exit 3
fi

# アーティファクト解決
eval "$("$SCRIPTS_DIR/resolve_artifact.sh" "$SRC" "$TGT" | awk '{k=$1; sub(/^[^ ]+ ?/,""); gsub(/"/,"\\\""); printf "%s=\"%s\"\n",k,$0}')"
[ -n "$STRAT_OVERRIDE" ] && STRATEGY="$STRAT_OVERRIDE"
BT="$(dconf "environments.$TGT.build_type" debug)"
KIND="$(dconf "environments.$TGT.kind" avd)"
VERSION="$(date +%Y%m%d.%H%M%S)-${GITSHA:-unknown}"
ARTIFACT_KEEP="$(dconf defaults.artifact_keep 5)"

echo "  strategy=$STRATEGY  build_type=$BT  git_sha=${GITSHA:-?}  kind=$KIND  version=$VERSION"

if [ "$APPLY" != "1" ]; then
  cat <<PLAN

[dry-run] 実行計画:
  D3 ビルド/取得 : strategy=$STRATEGY
       rebuild → build.sh $BT（git ${GITSHA:-?}）→ autodev/artifacts/app_${VERSION}.apk へ世代保管
       promote → 直近アーティファクトを再利用（${PREV_APK:-無し}）
  D4 マイグレーション : Room migration は APK 内で実行（事前ゲート: check_room_schema.sh）
  D5 リリース   : $KIND へ adb install -r（versionCode 後退/署名不一致時は uninstall=データ消失の承認が必要）
  D6 スモーク   : run_smoke_device.sh（起動マーカー + maestro/smoke.yaml + logcat スキャン）
  D7 記録       : autodev/state/deploys/$TGT/<ts>.json + 進捗.md
  D8 ロールバック: 失敗時 auto_rollback=$(dconf defaults.auto_rollback true)（前世代 APK へ。データ消失を伴う場合あり）

  実行するには --apply を付けてください。$([ "$REQ_APPROVAL" = "true" ] && echo '（この環境は --approve も必須）')
PLAN
  exit 0
fi

# ---- 以降は実実行（--apply） ----
TS="$(date +%Y%m%d_%H%M%S)"
REC_DIR="$STATE_DIR/deploys/$TGT"; mkdir -p "$REC_DIR"; REC="$REC_DIR/$TS.json"
mkdir -p "$ARTIFACTS_DIR"

# Room schema ゲート（マイグレーション安全性）
"$SCRIPTS_DIR/check_room_schema.sh" || log_warn "Room schema ゲートに警告あり（続行）"

# D3 アーティファクト
APK=""
if [ "$STRATEGY" = "promote" ] && [ -n "${PREV_APK:-}" ] && [ -f "${PREV_APK:-}" ]; then
  log_info "promote: 既存アーティファクトを採用 (${PREV_APK#$REPO_ROOT/})"
  APK="$PREV_APK"
else
  log_info "rebuild: $BT ビルド（git ${GITSHA:-?}）"
  BUILT="$("$SCRIPTS_DIR/build.sh" "$BT" | tail -1)" || { log_error "ビルド失敗"; exit 1; }
  APK="$ARTIFACTS_DIR/app_${VERSION}.apk"
  cp "$BUILT" "$APK"
  log_info "アーティファクト保管: ${APK#$REPO_ROOT/}"
fi

# D5 リリース（デバイス解決 → install → 起動）
SERIAL="$(resolve_target_device "$TGT")" || { log_error "target デバイス解決に失敗"; exit 1; }
log_info "リリース実行: install -r → $SERIAL"
if ! "$ADB_BIN" -s "$SERIAL" install -r "$APK"; then
  log_error "インストール失敗。versionCode 後退または署名不一致の可能性。"
  log_error "復旧には uninstall（アプリデータ消失）が必要です: autodev/scripts/uninstall.sh の実行をユーザーに確認してください。"
  exit 1
fi

# D6 スモーク
SMOKE_OK=1
if [ "$(dconf defaults.require_smoke true)" = "true" ]; then
  "$SCRIPTS_DIR/run_smoke_device.sh" "$SERIAL" "deploy_$TGT" || SMOKE_OK=0
fi

# D7 記録
cat > "$REC" <<JSON
{
  "source": "$SRC", "target": "$TGT", "version": "$VERSION",
  "git_sha": "${GITSHA:-}", "build_strategy": "$STRATEGY", "build_type": "$BT",
  "apk_path": "${APK#$REPO_ROOT/}",
  "device_serial": "$SERIAL",
  "deployed_at": "$(date -Iseconds 2>/dev/null || date)",
  "approved": $( [ "$APPROVE" = 1 ] && echo true || echo false ),
  "smoke_passed": $( [ "$SMOKE_OK" = 1 ] && echo true || echo false )
}
JSON
"$SCRIPTS_DIR/update_progress_md.sh" >/dev/null 2>&1 || true

# アーティファクト世代整理（直近 N 世代）
ls -t "$ARTIFACTS_DIR"/*.apk 2>/dev/null | tail -n +"$((ARTIFACT_KEEP+1))" | while read -r old; do
  log_info "古いアーティファクトを削除: ${old#$REPO_ROOT/}"; rm -f "$old"
done

# D8 ロールバック
if [ "$SMOKE_OK" != "1" ] && [ "$(dconf defaults.auto_rollback true)" = "true" ]; then
  log_error "スモーク失敗 → 自動ロールバック"
  "$SCRIPTS_DIR/rollback.sh" "$TGT" --apply || log_error "ロールバックも失敗。手動対応が必要。"
  exit 1
fi

log_info "デプロイ完了: $SRC -> $TGT (version=$VERSION)  記録: ${REC#$REPO_ROOT/}"
