#!/usr/bin/env bash
# Android 開発環境の全自動セットアップ（修正方針 §6-7 / setup.sh から呼ばれる）。
# JDK・Android SDK（cmdline-tools / platform-tools / platforms / build-tools / emulator /
# system-images）・AVD を、android_env.yaml のピン留め版数に従いユーザー領域へ無人導入する。
# 冪等: 導入済みステップはスキップ。sudo 不要（apt 等は setup.sh 側で best-effort）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

ok()   { echo "  [OK]   $*"; }
ng()   { echo "  [FAIL] $*"; }
info() { echo "  [..]   $*"; }

FAIL=0
ARCH="$(uname -m 2>/dev/null || echo unknown)"
if [ "$AUTODEV_OS" != "linux" ] && [ "$AUTODEV_OS" != "macos" ]; then
  ng "対応OSは Linux(Ubuntu) / macOS です（検出: $AUTODEV_OS）。"
  exit 1
fi
if [ "$ARCH" != "x86_64" ]; then
  echo "  [WARN] x86_64 以外のホスト ($ARCH)。system_image / JDK URL を android_env.yaml で調整してください。"
fi

DL() { # DL <url> <out>
  curl -fSL --retry 3 --retry-delay 3 -o "$2" "$1"
}

# ---------- 1) JDK ----------
JDK_MAJOR="$(aconf jdk.major 17)"
JDK_DIR_CONF="$(aconf jdk.dir "")"
JDK_DIR="${JDK_DIR_CONF:-$HOME/.autodev-android/jdk}"
have_jdk() {
  local java_bin="$1"
  [ -x "$java_bin" ] || return 1
  "$java_bin" -version 2>&1 | grep -qE "version \"$JDK_MAJOR\." && return 0
  return 1
}
if have_jdk "$JDK_DIR/bin/java"; then
  ok "JDK $JDK_MAJOR ($JDK_DIR)"
elif have_jdk "$(command -v java || echo /nonexistent)"; then
  ok "JDK $JDK_MAJOR（システム導入済み）"
else
  if [ "$AUTODEV_OS" = "macos" ]; then
    ng "macOS では JDK の自動ダウンロード（linux-x64 URL）は使えません。'brew install --cask temurin@17' 等で JDK 17 を導入してから再実行してください。"
    exit 1
  fi
  info "JDK $JDK_MAJOR をダウンロード（Temurin）..."
  URL="$(aconf jdk.url_linux_x64 "")"
  SHA="$(aconf jdk.sha256 "")"
  [ -z "$URL" ] && { ng "android_env.yaml::jdk.url_linux_x64 が未設定"; exit 1; }
  TMP="$(mktemp -d)"
  if DL "$URL" "$TMP/jdk.tar.gz"; then
    if [ -n "$SHA" ]; then
      echo "$SHA  $TMP/jdk.tar.gz" | sha256sum -c - >/dev/null 2>&1 || { ng "JDK チェックサム不一致"; exit 1; }
    else
      echo "  [WARN] jdk.sha256 未設定のためチェックサム検証をスキップ。"
    fi
    mkdir -p "$JDK_DIR"
    tar -xzf "$TMP/jdk.tar.gz" -C "$TMP"
    INNER="$(find "$TMP" -maxdepth 1 -type d -name 'jdk*' | head -1)"
    [ -z "$INNER" ] && { ng "JDK アーカイブ展開に失敗"; exit 1; }
    rm -rf "$JDK_DIR"; mv "$INNER" "$JDK_DIR"
    rm -rf "$TMP"
    have_jdk "$JDK_DIR/bin/java" && ok "JDK $JDK_MAJOR 導入完了 ($JDK_DIR)" || { ng "JDK 導入失敗"; exit 1; }
  else
    ng "JDK ダウンロード失敗（$URL）。ネットワーク/プロキシを確認してください。"
    exit 1
  fi
fi
[ -x "$JDK_DIR/bin/java" ] && export JAVA_HOME="$JDK_DIR" && export PATH="$JAVA_HOME/bin:$PATH"

# ---------- 2) cmdline-tools ----------
CLT_VER="$(aconf sdk.cmdline_tools_version 11076708)"
mkdir -p "$ANDROID_SDK_ROOT"
if [ -x "$SDKMANAGER_BIN" ]; then
  ok "cmdline-tools ($ANDROID_SDK_ROOT/cmdline-tools/latest)"
else
  info "cmdline-tools をダウンロード（版 $CLT_VER）..."
  case "$AUTODEV_OS" in
    macos) CLT_OS="mac" ;;
    *)     CLT_OS="linux" ;;
  esac
  URL="https://dl.google.com/android/repository/commandlinetools-${CLT_OS}-${CLT_VER}_latest.zip"
  TMP="$(mktemp -d)"
  DL "$URL" "$TMP/clt.zip" || { ng "cmdline-tools ダウンロード失敗（$URL）"; exit 1; }
  unzip -q "$TMP/clt.zip" -d "$TMP"
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
  rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  mv "$TMP/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  rm -rf "$TMP"
  [ -x "$SDKMANAGER_BIN" ] && ok "cmdline-tools 導入完了" || { ng "cmdline-tools 導入失敗"; exit 1; }
fi

# ---------- 3) SDK パッケージ（ライセンス自動同意・非対話） ----------
PLATFORM="$(aconf sdk.platform android-35)"
BUILD_TOOLS="$(aconf sdk.build_tools 35.0.0)"
SYS_IMG="$(aconf sdk.system_image "system-images;android-35;google_apis;x86_64")"
info "SDK ライセンスへ自動同意..."
yes | "$SDKMANAGER_BIN" --licenses >/dev/null 2>&1 || true
need_pkgs=()
[ -x "$ANDROID_SDK_ROOT/platform-tools/adb" ] || need_pkgs+=("platform-tools")
[ -d "$ANDROID_SDK_ROOT/platforms/$PLATFORM" ] || need_pkgs+=("platforms;$PLATFORM")
[ -d "$ANDROID_SDK_ROOT/build-tools/$BUILD_TOOLS" ] || need_pkgs+=("build-tools;$BUILD_TOOLS")
[ -x "$ANDROID_SDK_ROOT/emulator/emulator" ] || need_pkgs+=("emulator")
IMG_DIR="$ANDROID_SDK_ROOT/$(echo "$SYS_IMG" | tr ';' '/')"
[ -d "$IMG_DIR" ] || need_pkgs+=("$SYS_IMG")
if [ "${#need_pkgs[@]}" -gt 0 ]; then
  info "SDK パッケージ導入: ${need_pkgs[*]}（数GB・時間がかかります）"
  # 注意: pipefail 下では `yes |` が SIGPIPE(141) になるため、sdkmanager 自体の終了コードで判定する。
  yes | "$SDKMANAGER_BIN" "${need_pkgs[@]}"
  SDKRC="${PIPESTATUS[1]}"
  [ "$SDKRC" = "0" ] || { ng "sdkmanager 導入失敗 (rc=$SDKRC)"; exit 1; }
fi
ok "SDK パッケージ（platform-tools / $PLATFORM / build-tools;$BUILD_TOOLS / emulator / system-image）"

# ---------- 4) AVD 作成 ----------
AVD="$(aconf avd.name autodev_api35)"
PROFILE="$(aconf avd.device_profile pixel_6)"
if "$ANDROID_SDK_ROOT/emulator/emulator" -list-avds 2>/dev/null | grep -qx "$AVD"; then
  ok "AVD '$AVD'（既存）"
else
  info "AVD '$AVD' を作成（image=$SYS_IMG, device=$PROFILE）..."
  echo no | "$AVDMANAGER_BIN" create avd -n "$AVD" -k "$SYS_IMG" --device "$PROFILE" --force >/dev/null \
    || { ng "AVD 作成失敗"; exit 1; }
  # 安定化設定
  AVD_CONFIG="$HOME/.android/avd/$AVD.avd/config.ini"
  if [ -f "$AVD_CONFIG" ]; then
    grep -q '^hw.keyboard' "$AVD_CONFIG" && sed -i.bak 's/^hw.keyboard.*/hw.keyboard=yes/' "$AVD_CONFIG" || echo "hw.keyboard=yes" >> "$AVD_CONFIG"
    rm -f "$AVD_CONFIG.bak"
  fi
  ok "AVD '$AVD' 作成完了"
fi

# ---------- 5) Gradle wrapper bootstrap ----------
# リポジトリは wrapper jar（バイナリ）を含まないため、初回に Gradle 配布版を取得して wrapper を生成する。
GR_VER="$(aconf gradle.version 8.9)"
if [ -f "$REPO_ROOT/gradlew" ] && [ -f "$REPO_ROOT/gradle/wrapper/gradle-wrapper.jar" ]; then
  ok "Gradle wrapper（既存）"
else
  GDIR="$HOME/.autodev-android/gradle-$GR_VER"
  if [ ! -x "$GDIR/bin/gradle" ]; then
    info "Gradle $GR_VER をダウンロード（wrapper 生成用）..."
    TMP="$(mktemp -d)"
    DL "https://services.gradle.org/distributions/gradle-${GR_VER}-bin.zip" "$TMP/gradle.zip" \
      || { ng "Gradle ダウンロード失敗（services.gradle.org）"; exit 1; }
    mkdir -p "$HOME/.autodev-android"
    unzip -q "$TMP/gradle.zip" -d "$HOME/.autodev-android"
    rm -rf "$TMP"
  fi
  info "Gradle wrapper を生成（gradle wrapper --gradle-version $GR_VER）..."
  # JAVA_HOME は JDK 導入時に export 済み（未設定なら PATH の java を使う。空文字で上書きしない）
  ( cd "$REPO_ROOT" && "$GDIR/bin/gradle" wrapper --gradle-version "$GR_VER" --distribution-type bin -q ) \
    || { ng "Gradle wrapper 生成失敗"; exit 1; }
  chmod +x "$REPO_ROOT/gradlew" 2>/dev/null || true
  [ -f "$REPO_ROOT/gradle/wrapper/gradle-wrapper.jar" ] && ok "Gradle wrapper 生成完了" || { ng "wrapper jar が生成されていません"; exit 1; }
fi

# ---------- 6) local.properties ----------
echo "sdk.dir=$ANDROID_SDK_ROOT" > "$REPO_ROOT/local.properties"
ok "local.properties（sdk.dir=$ANDROID_SDK_ROOT）"

# ---------- 7) KVM 確認（Linux のみ・情報提供） ----------
if [ "$AUTODEV_OS" = "linux" ]; then
  if [ -w /dev/kvm ]; then
    ok "KVM 利用可（/dev/kvm）"
  else
    echo "  [WARN] /dev/kvm が利用できません。エミュレータは -no-accel（非常に低速）になります。"
    echo "         対処（sudo 必要・再ログイン要）: sudo apt install -y qemu-kvm && sudo usermod -aG kvm \$USER"
  fi
fi

[ "$FAIL" = "0" ] && echo "[OK] Android 環境セットアップ完了" || { echo "[FAIL] Android 環境セットアップに失敗あり"; exit 1; }
