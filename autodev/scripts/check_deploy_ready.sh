#!/usr/bin/env bash
# デプロイ事前ゲート（Android 版）。使い方: check_deploy_ready.sh <source> <target>
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"
source "$SCRIPTS_DIR/_deploy_lib.sh"

SRC="${1:-}"; TGT="${2:-}"
[ -z "$SRC" ] || [ -z "$TGT" ] && { echo "[FAIL] 使い方: check_deploy_ready.sh <source> <target>"; exit 1; }
RC=0
ng(){ echo "[FAIL] $*"; RC=1; }
ok(){ echo "[OK] $*"; }

env_defined "$SRC" || ng "source 環境 '$SRC' が deploy.yaml に未定義"
env_defined "$TGT" || ng "target 環境 '$TGT' が deploy.yaml に未定義"

# promotions 許可（deploy.yaml はインライン形式 { from: X, to: Y } を前提に grep 判定）
if grep -qE '^promotions:' "$DEPLOY_YAML"; then
  if grep -E '^\s*-\s*\{' "$DEPLOY_YAML" | grep -E "from:\s*$SRC\b" | grep -qE "to:\s*$TGT\b"; then
    ok "promotion 許可: $SRC -> $TGT"
  else
    ng "promotion 未許可: $SRC -> $TGT（deploy.yaml の promotions を確認）"
  fi
else
  echo "[WARN] promotions 未定義。任意フローを許可（要承認）。"
fi

# 作業ツリーがクリーン（未コミット無し）
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  [ -z "$(git -C "$REPO_ROOT" status --porcelain)" ] && ok "git 作業ツリー clean" || ng "未コミットの変更あり（コミットしてから）"
else
  echo "[WARN] git リポジトリ未検出（バージョン追跡不可）"
fi

# target デバイスの可用性
KIND="$(dconf "environments.$TGT.kind" avd)"
if [ "$KIND" = "adb-device" ]; then
  SERIAL="$(dconf "environments.$TGT.serial" "")"
  if [ -n "$SERIAL" ]; then
    adb_devices | grep -qx "$SERIAL" && ok "実機 '$SERIAL' 接続中" || ng "実機 '$SERIAL' が未接続（USB/Wi-Fi adb を確認）"
  else
    [ -n "$(adb_devices | grep -v '^emulator-' | head -1)" ] && ok "実機（自動選択）接続中" || ng "実機が未接続"
  fi
else
  AVD="$(dconf "environments.$TGT.avd_name" "$(aconf avd.name autodev_api35)")"
  [ -x "$EMULATOR_BIN" ] && "$EMULATOR_BIN" -list-avds 2>/dev/null | grep -qx "$AVD" && ok "AVD '$AVD' 利用可" || ng "AVD '$AVD' 不在"
fi

# release ビルドの署名情報
BT="$(dconf "environments.$TGT.build_type" debug)"
if [ "$BT" = "release" ]; then
  if [ -f "$SECRETS_DIR/keystore.properties" ]; then ok "keystore.properties（release 署名）"; else echo "[WARN] keystore.properties 不在 → debug 署名フォールバック（setup.sh が生成するはず）"; fi
fi

# CHANGELOG 更新の有無（警告）
[ -f "$REPO_ROOT/CHANGELOG.md" ] || echo "[WARN] CHANGELOG.md が無い"

[ "$RC" = 0 ] && echo "[OK] デプロイ事前ゲート PASS ($SRC -> $TGT)" || echo "[FAIL] デプロイ事前ゲート NG"
exit "$RC"
