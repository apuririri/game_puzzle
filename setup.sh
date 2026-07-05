#!/usr/bin/env bash
# =============================================================================
# AutoDev for Android — ゼロタッチセットアップ（修正方針 §6-7）
#
# 目標: `git clone` → `bash setup.sh` だけで、クリーンな Ubuntu から
#       「自動開発を開始できる状態」（healthcheck PASS + 初期スモーク PASS）まで無人で到達する。
#
# 設計原則:
#   - 完全非対話（SDK ライセンス自動同意。プロンプトを出さない）
#   - sudo 非依存（JDK/SDK/Maestro はユーザー領域へ。apt/KVM のみ sudo 可なら自動試行 + フォールバック）
#   - バージョン固定（autodev/config/android_env.yaml のピン留めに従う）
#   - 冪等・再開可能（導入済みステップはスキップ。失敗後の再実行で続きから）
#   - 自己完結したパス解決（シェル設定を書き換えない。ラッパーが解決する）
#
# 使い方:
#   bash setup.sh             # フルセットアップ
#   bash setup.sh --doctor    # 診断のみ（何も導入しない）
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
SCRIPTS="$ROOT/autodev/scripts"

say()  { echo -e "\n\033[1;36m==> $*\033[0m"; }
ok()   { echo -e "  \033[1;32m[OK]\033[0m $*"; }
warn() { echo -e "  \033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "  \033[1;31m[ERROR]\033[0m $*" >&2; }

# ---- 診断モード ----
if [ "${1:-}" = "--doctor" ]; then
  say "診断モード（--doctor）: 充足状況のみ表示します"
  bash "$SCRIPTS/check_android_setup.sh" || true
  exit 0
fi

START_TS="$(date +%s)"
say "AutoDev for Android セットアップを開始します（完全非対話・冪等）"
echo "  目安: 初回はダウンロード数GB・30〜60分程度。再実行時は導入済みステップをスキップします。"

# =============================================================================
say "1) ホスト検査"
# =============================================================================
case "$(uname -s 2>/dev/null)" in
  Darwin) OS="macos" ;;
  Linux)  OS="linux" ;;
  *) err "対応OSは Linux(Ubuntu) / macOS です。Windows は WSL2 のエミュレータ制約があるため非推奨です。"; exit 1 ;;
esac
ARCH="$(uname -m 2>/dev/null || echo unknown)"
[ "$ARCH" = "x86_64" ] && ok "アーキテクチャ: $ARCH" || warn "x86_64 以外 ($ARCH)。android_env.yaml の system_image / JDK URL の調整が必要な場合があります。"

# WSL 判定
if [ "$OS" = "linux" ] && grep -qi microsoft /proc/version 2>/dev/null; then
  warn "WSL を検出。エミュレータはネスト仮想化制約で動かない場合があります（実機 adb 接続は可）。"
fi

# ディスク空き（15GB 目安）
AVAIL_KB="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2{print $4}')"
if [ -n "${AVAIL_KB:-}" ] && [ "$AVAIL_KB" -lt $((15*1024*1024)) ]; then
  warn "ホームのディスク空きが 15GB 未満です（$((AVAIL_KB/1024/1024))GB）。SDK+依存で不足する可能性があります。"
else
  ok "ディスク空き"
fi

# KVM（Linux のみ）
if [ "$OS" = "linux" ]; then
  if [ -w /dev/kvm ]; then
    ok "KVM 利用可"
  else
    warn "KVM が利用できません。エミュレータは低速な -no-accel になります。"
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
      warn "sudo が利用可能なため KVM 設定を試行します（グループ反映には再ログインが必要）..."
      sudo apt-get install -y qemu-kvm >/dev/null 2>&1 || true
      sudo usermod -aG kvm "$USER" 2>/dev/null && warn "kvm グループに追加しました。**再ログイン後に有効**になります。" || true
    else
      warn "対処（sudo 必要）: sudo apt install -y qemu-kvm && sudo usermod -aG kvm \$USER → 再ログイン"
    fi
  fi
fi

# =============================================================================
say "2) 基本ツール（git / curl / unzip / jq + エミュレータ用ライブラリ）"
# =============================================================================
PM=""
if   command -v apt-get >/dev/null 2>&1; then PM="apt"
elif command -v dnf     >/dev/null 2>&1; then PM="dnf"
elif command -v brew    >/dev/null 2>&1; then PM="brew"
fi
APT_OK=0
if [ "$PM" = "apt" ] && command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then APT_OK=1; fi

need_pkgs=()
for c in git curl unzip jq python3; do
  command -v "$c" >/dev/null 2>&1 || need_pkgs+=("$c")
done
if [ "${#need_pkgs[@]}" -gt 0 ]; then
  warn "不足ツール: ${need_pkgs[*]} → 自動導入を試行"
  case "$PM" in
    apt)  if [ "$APT_OK" = 1 ]; then sudo apt-get update -y >/dev/null 2>&1; sudo apt-get install -y "${need_pkgs[@]}"; else warn "sudo 不可のため自動導入できません。手動で導入してください: ${need_pkgs[*]}"; fi ;;
    dnf)  sudo dnf install -y "${need_pkgs[@]}" || true ;;
    brew) brew install "${need_pkgs[@]}" || true ;;
    *)    warn "パッケージマネージャ未検出。手動で導入してください: ${need_pkgs[*]}" ;;
  esac
fi
FATAL=0
for c in git curl unzip; do
  command -v "$c" >/dev/null 2>&1 && ok "$c" || { err "$c は必須です。導入後に再実行してください。"; FATAL=1; }
done
command -v jq >/dev/null 2>&1 && ok "jq" || warn "jq 無し（hooks の検査機能が制限されます。導入を強く推奨）"
command -v python3 >/dev/null 2>&1 && ok "python3" || warn "python3 無し（設定読み出しが既定値フォールバックになります。導入を推奨）"
[ "$FATAL" = 1 ] && exit 1

# エミュレータ実行に必要な共有ライブラリ（Linux / best-effort）
if [ "$OS" = "linux" ] && [ "$APT_OK" = 1 ]; then
  sudo apt-get install -y libpulse0 libgl1 libnss3 libxcomposite1 libxcursor1 libxi6 libxtst6 libasound2t64 >/dev/null 2>&1 \
    || sudo apt-get install -y libpulse0 libgl1 libnss3 libxcomposite1 libxcursor1 libxi6 libxtst6 libasound2 >/dev/null 2>&1 \
    || warn "エミュレータ用ライブラリの導入に一部失敗（起動時に不足があれば SETUP.md 参照）"
  ok "エミュレータ用ライブラリ（best-effort）"
fi

# config 検証用 python モジュール（best-effort。無くても SKIP されるだけ）
if command -v python3 >/dev/null 2>&1; then
  python3 -c "import yaml, jsonschema" >/dev/null 2>&1 || {
    if [ "$APT_OK" = 1 ]; then sudo apt-get install -y python3-yaml python3-jsonschema >/dev/null 2>&1 || true; fi
    python3 -c "import yaml" >/dev/null 2>&1 || pip3 install --user pyyaml jsonschema >/dev/null 2>&1 || true
  }
fi

# =============================================================================
say "3) git リポジトリと hooks の有効化"
# =============================================================================
if [ ! -d "$ROOT/.git" ]; then
  warn ".git 不在。git init します（手動 push する前提）。"
  git init -q "$ROOT"
fi
git -C "$ROOT" config core.hooksPath autodev/hooks
chmod +x autodev/scripts/*.sh autodev/hooks/claude/*.sh autodev/hooks/pre-commit autodev/hooks/pre-push 2>/dev/null || true
ok "core.hooksPath = autodev/hooks、スクリプトに実行権限を付与"

# =============================================================================
say "4) JDK / Android SDK / AVD / Gradle wrapper（android_env.yaml のピン留め版数）"
# =============================================================================
if bash "$SCRIPTS/setup_android_env.sh"; then ok "Android 環境セットアップ完了"; else err "Android 環境セットアップ失敗（ログを確認して再実行。冪等です）"; exit 1; fi

# =============================================================================
say "5) Maestro CLI"
# =============================================================================
if bash "$SCRIPTS/setup_maestro.sh"; then ok "Maestro 準備完了"; else err "Maestro 導入失敗"; exit 1; fi

# =============================================================================
say "6) release 署名 keystore（自動生成・git 管理外）"
# =============================================================================
SECRETS="$ROOT/autodev/secrets"
mkdir -p "$SECRETS"
if [ -f "$SECRETS/keystore.properties" ] && [ -f "$SECRETS/release.keystore" ]; then
  ok "keystore（既存）"
else
  # keytool はラッパーと同じ規則で解決（android_env.yaml::jdk.dir → 既定ディレクトリ → PATH）
  KEYTOOL="keytool"
  JDK_DIR_CONF=""
  command -v python3 >/dev/null 2>&1 && JDK_DIR_CONF="$(python3 "$SCRIPTS/_conf.py" "$ROOT/autodev/config/android_env.yaml" jdk.dir "" 2>/dev/null)"
  if [ -n "$JDK_DIR_CONF" ] && [ -x "$JDK_DIR_CONF/bin/keytool" ]; then KEYTOOL="$JDK_DIR_CONF/bin/keytool"
  elif [ -x "$HOME/.autodev-android/jdk/bin/keytool" ]; then KEYTOOL="$HOME/.autodev-android/jdk/bin/keytool"
  fi
  PASS="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 24)"
  "$KEYTOOL" -genkeypair -v -keystore "$SECRETS/release.keystore" -alias release \
    -keyalg RSA -keysize 2048 -validity 10950 \
    -storepass "$PASS" -keypass "$PASS" \
    -dname "CN=AutoDev, OU=Dev, O=AutoDev, L=Local, S=Local, C=JP" >/dev/null 2>&1 \
    || { err "keystore 生成失敗（keytool）"; exit 1; }
  cat > "$SECRETS/keystore.properties" <<KPROP
storeFile=$SECRETS/release.keystore
storePassword=$PASS
keyAlias=release
keyPassword=$PASS
KPROP
  chmod 600 "$SECRETS/keystore.properties" "$SECRETS/release.keystore"
  ok "keystore 生成完了（autodev/secrets/）"
  warn "**keystore は必ずバックアップしてください**（紛失すると実機の上書き更新ができなくなります）"
fi

# =============================================================================
say "7) .claude/skills の同期"
# =============================================================================
bash "$SCRIPTS/sync_claude_dir.sh" && ok ".claude/skills 同期完了" || warn "skills 同期に注意"

# =============================================================================
say "8) 初回ビルド（assembleDebug。依存DLのため時間がかかります。進捗を表示します）"
# =============================================================================
if bash "$SCRIPTS/build.sh" debug; then ok "assembleDebug 成功"; else err "初回ビルド失敗（autodev/logs/ の gradle ログを確認）"; exit 1; fi

# =============================================================================
say "9) ヘルスチェック + 初期実機検証（エミュレータ起動 → install → smoke flow）"
# =============================================================================
bash "$SCRIPTS/update_progress_md.sh" >/dev/null 2>&1 || true

HEALTH_OK=1
if bash "$SCRIPTS/healthcheck.sh"; then ok "ヘルスチェック PASS"; else warn "ヘルスチェックに失敗あり（上のログを確認）"; HEALTH_OK=0; fi

SMOKE_OK=1
if bash "$SCRIPTS/run_real_device_check.sh" smoke maestro/smoke.yaml; then
  ok "初期スモーク（maestro/smoke.yaml）PASS — スクショ: autodev/evidence/screenshots/smoke/"
else
  warn "初期スモークに失敗あり。詳細: autodev/evidence/ / autodev/logs/"
  SMOKE_OK=0
fi

# =============================================================================
say "セットアップ完了（所要 $((($(date +%s)-START_TS)/60)) 分）"
# =============================================================================
if [ "$HEALTH_OK" = 1 ] && [ "$SMOKE_OK" = 1 ]; then
  echo -e "  \033[1;32mすべて PASS。自動開発を開始できます。\033[0m"
else
  echo -e "  \033[1;33m一部に警告/失敗があります。'bash setup.sh --doctor' と上のログを確認してください（setup.sh は再実行可能）。\033[0m"
fi
cat <<'NEXT'

  次のステップ:
    1) 入力ファイルを用意（テンプレート: autodev/inputs/_テンプレート/）
         例: cp autodev/inputs/_テンプレート/要件定義書.md autodev/inputs/要件定義/要件定義書.md
    2) AI エージェントを起動
         claude --dangerously-skip-permissions
    3) プロンプトを1回送信
         > 要件定義書.mdのシステムを自動で開発してください
    4) 進捗確認（別端末でも可）
         tail -f autodev/開発進捗状況.md

  便利コマンド:
    診断のみ       : bash setup.sh --doctor
    エミュレータGUI : HEADFUL=1 autodev/scripts/start_emulator.sh
    ビルド+起動    : autodev/scripts/build_install_run.sh
NEXT
exit 0
