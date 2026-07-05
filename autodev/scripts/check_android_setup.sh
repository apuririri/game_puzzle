#!/usr/bin/env bash
# Android 環境セットアップ検証（check_playwright_setup.sh の後継 / 修正方針 §3-8）。
# JDK / SDK / adb / emulator / AVD / Maestro / jq / gradlew の充足を確認する。導入はしない。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

FAIL=0
ok(){ echo "  [OK]   $*"; }
ng(){ echo "  [FAIL] $*"; FAIL=1; }

command -v jq >/dev/null 2>&1 && ok "jq" || ng "jq 不在（setup.sh で導入）"

if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
  ok "JDK ($JAVA_HOME)"
elif command -v java >/dev/null 2>&1; then
  ok "JDK（システム java）"
else
  ng "JDK 不在（setup.sh が自動導入）"
fi

[ -d "$ANDROID_SDK_ROOT" ] && ok "ANDROID_SDK_ROOT ($ANDROID_SDK_ROOT)" || ng "SDK 不在: $ANDROID_SDK_ROOT"
{ [ -x "$ANDROID_SDK_ROOT/platform-tools/adb" ] || command -v adb >/dev/null 2>&1; } && ok "platform-tools (adb)" || ng "platform-tools 不在"
[ -x "$EMULATOR_BIN" ] && ok "emulator" || ng "emulator 不在"
[ -x "$SDKMANAGER_BIN" ] && ok "cmdline-tools (sdkmanager)" || ng "cmdline-tools 不在"

PLATFORM="$(aconf sdk.platform android-35)"
[ -d "$ANDROID_SDK_ROOT/platforms/$PLATFORM" ] && ok "platforms;$PLATFORM" || ng "platforms;$PLATFORM 不在"

AVD="$(aconf avd.name autodev_api35)"
if [ -x "$EMULATOR_BIN" ] && "$EMULATOR_BIN" -list-avds 2>/dev/null | grep -qx "$AVD"; then
  ok "AVD '$AVD'"
else
  ng "AVD '$AVD' 不在（setup_android_env.sh で作成）"
fi

[ -x "$REPO_ROOT/gradlew" ] && ok "gradlew" || ng "gradlew 不在（リポジトリ直下）"
[ -f "$REPO_ROOT/local.properties" ] && ok "local.properties" || ng "local.properties 不在（run_gradle.sh が自動生成可）"

if [ -x "$MAESTRO_HOME/bin/maestro" ] || command -v maestro >/dev/null 2>&1; then
  ok "Maestro CLI"
else
  ng "Maestro 不在（setup_maestro.sh で導入）"
fi

if [ "$AUTODEV_OS" = "linux" ]; then
  [ -w /dev/kvm ] && ok "KVM" || echo "  [WARN] KVM 不可（エミュレータは低速な -no-accel になります）"
fi

[ "$FAIL" = "0" ] && { echo "[OK] Android セットアップ確認 PASS"; exit 0; }
echo "[FAIL] Android セットアップに不足あり（bash setup.sh を実行してください）"
exit 1
