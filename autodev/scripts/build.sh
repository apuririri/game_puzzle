#!/usr/bin/env bash
# APK ビルド。使い方: build.sh [debug|release]（既定 debug）
# release は autodev/secrets/keystore.properties の署名情報を環境変数で注入する
# （app/ 側は env 不在時 debug 署名にフォールバックするため、ツール非依存を保つ）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

BT="${1:-debug}"
case "$BT" in debug|release) ;; *) echo "使い方: build.sh [debug|release]"; exit 1 ;; esac

if [ "$BT" = "release" ]; then
  KS_PROP="$SECRETS_DIR/keystore.properties"
  if [ -f "$KS_PROP" ]; then
    # keystore.properties: storeFile / storePassword / keyAlias / keyPassword
    export RELEASE_STORE_FILE="$(grep '^storeFile=' "$KS_PROP" | cut -d= -f2-)"
    export RELEASE_STORE_PASSWORD="$(grep '^storePassword=' "$KS_PROP" | cut -d= -f2-)"
    export RELEASE_KEY_ALIAS="$(grep '^keyAlias=' "$KS_PROP" | cut -d= -f2-)"
    export RELEASE_KEY_PASSWORD="$(grep '^keyPassword=' "$KS_PROP" | cut -d= -f2-)"
    log_info "release 署名: $RELEASE_STORE_FILE"
  else
    log_warn "keystore.properties 不在（$KS_PROP）。debug 署名で release をビルドします（setup.sh が生成するはず）。"
  fi
  "$SCRIPTS_DIR/run_gradle.sh" assembleRelease || exit 1
else
  "$SCRIPTS_DIR/run_gradle.sh" assembleDebug || exit 1
fi

APK="$(apk_path "$BT")"
[ -f "$APK" ] || { log_error "APK が見つかりません: $APK"; exit 1; }
log_info "ビルド成功: ${APK#$REPO_ROOT/}"
echo "$APK"
