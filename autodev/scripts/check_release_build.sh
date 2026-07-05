#!/usr/bin/env bash
# S14 RG1 リリースビルドの成立を機械検証（FR-5.19.2）。
# build.sh release が PASS / 署名検証 / minify 反映 / versionCode 単調増加 / APK サイズ閾値 を確認する。
#
# 使い方:
#   check_release_build.sh         # 検査。NG で exit 1
#   check_release_build.sh --warn  # exit 0
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

MODE="strict"
[ "${1:-}" = "--warn" ] && MODE="warn"

CONF="$AUTODEV_DIR/config/release.yaml"

FAIL=0

# 1) build.sh release を実行（成功すれば APK パスを stdout の最終行で返す）
log_info "build.sh release を実行..."
RELEASE_APK="$("$SCRIPTS_DIR/build.sh" release 2>&1 | tee /dev/stderr | tail -1)"
if [ -z "$RELEASE_APK" ] || [ ! -f "$RELEASE_APK" ]; then
  echo "[FAIL] release APK が生成されませんでした"
  FAIL=1
fi

# 2) 署名検証（apksigner）
if [ -n "$RELEASE_APK" ] && [ -f "$RELEASE_APK" ]; then
  APKSIGNER="$ANDROID_SDK_ROOT/build-tools/$(ls "$ANDROID_SDK_ROOT/build-tools" 2>/dev/null | sort -V | tail -1)/apksigner"
  if [ -x "$APKSIGNER" ]; then
    if "$APKSIGNER" verify --verbose "$RELEASE_APK" >/dev/null 2>&1; then
      echo "[OK] APK 署名検証 PASS"
    else
      echo "[FAIL] APK 署名検証 NG: $RELEASE_APK"
      FAIL=1
    fi
  else
    log_warn "apksigner が見つかりません（署名検証スキップ）"
  fi

  # 3) APK サイズ閾値
  SIZE_MAX="$(conf_get "$CONF" apk_size_max_bytes 0)"
  if [ -n "$SIZE_MAX" ] && [ "$SIZE_MAX" != "0" ]; then
    SIZE="$(stat -c %s "$RELEASE_APK" 2>/dev/null || stat -f %z "$RELEASE_APK" 2>/dev/null || echo 0)"
    if [ "$SIZE" -gt "$SIZE_MAX" ]; then
      echo "[FAIL] APK サイズ ${SIZE} > 閾値 ${SIZE_MAX}"
      FAIL=1
    else
      echo "[OK] APK サイズ ${SIZE} <= 閾値 ${SIZE_MAX}"
    fi
  fi
fi

# 4) versionCode 単調増加（前回 deploy 記録があれば比較）
GRADLE_KTS="$APP_DIR/build.gradle.kts"
if [ -f "$GRADLE_KTS" ]; then
  CUR_VC="$(grep -E 'versionCode\s*=\s*[0-9]+' "$GRADLE_KTS" | head -1 | grep -oE '[0-9]+' | tail -1 || echo "")"
  LAST_VC=""
  if command -v jq >/dev/null 2>&1; then
    LAST_VC="$(find "$STATE_DIR/deploys" -name '*.json' -type f 2>/dev/null \
      | xargs -I {} jq -r '.version // empty' {} 2>/dev/null \
      | grep -oE '[0-9]+' | sort -n | tail -1 || true)"
  fi
  if [ -n "$CUR_VC" ] && [ -n "$LAST_VC" ]; then
    if [ "$CUR_VC" -le "$LAST_VC" ]; then
      echo "[FAIL] versionCode が単調増加していません: 現在=$CUR_VC, 前回=$LAST_VC"
      FAIL=1
    else
      echo "[OK] versionCode: $LAST_VC → $CUR_VC"
    fi
  elif [ -n "$CUR_VC" ]; then
    echo "[OK] versionCode=$CUR_VC（前回デプロイ記録なし）"
  fi
fi

# 5) minify 反映の簡易検証（release マッピングファイルの存在）
MAPPING="$APP_DIR/build/outputs/mapping/release/mapping.txt"
if [ -f "$MAPPING" ]; then
  echo "[OK] minify/R8 mapping: ${MAPPING#$REPO_ROOT/}"
else
  log_warn "minify/R8 mapping.txt が見つかりません（release で minify が有効か確認: app/build.gradle.kts isMinifyEnabled=true）"
fi

if [ "$FAIL" = "1" ]; then
  echo "[FAIL] check_release_build: NG"
  [ "$MODE" = "warn" ] && exit 0 || exit 1
fi
echo "[OK] check_release_build: PASS"
exit 0
