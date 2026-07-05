# SETUP — 環境構築の詳細（AutoDev for Android）

基本は **`bash setup.sh` の一発実行だけ**です（完全非対話・冪等・sudo 非依存）。本書は内部動作とトラブルシュートを説明します。

## setup.sh が行うこと（ゼロタッチ / 修正方針 §6-7）

| # | ステップ | 内容 | 導入先 |
|---|---|---|---|
| 1 | ホスト検査 | OS / x86_64 / ディスク15GB / KVM / WSL2 警告 | - |
| 2 | 基本ツール | git curl unzip jq（不足時 apt/brew で自動導入を試行。sudo 不可なら警告） | システム |
| 3 | JDK 17 | Temurin を取得・展開（チェックサムは android_env.yaml で指定可） | `~/.autodev-android/jdk` |
| 4 | Android SDK | cmdline-tools → sdkmanager で platform-tools / platforms / build-tools / emulator / system-image。`yes | sdkmanager --licenses` で自動同意 | `~/Android/Sdk`（既存再利用） |
| 5 | AVD | `avdmanager create avd`（hw.keyboard=yes 等の安定化設定込み） | `~/.android/avd` |
| 6 | Maestro | 公式インストーラ（版は android_env.yaml で固定可） | `~/.maestro` |
| 7 | Gradle wrapper + 初回ビルド | wrapper 未生成なら Gradle 配布版を取得して `gradle wrapper` で生成（git tracked 化は初回コミットで）→ `run_gradle.sh assembleDebug` | `~/.autodev-android/gradle-*` / `~/.gradle` |
| 8 | 署名キー | keytool で release 用 keystore + keystore.properties を自動生成 | `autodev/secrets/`（git 管理外） |
| 9 | ハーネス | git hooks 有効化（core.hooksPath）+ `.claude/skills` 同期 | リポジトリ内 |
| 10 | 初期実機検証 | healthcheck → エミュレータ起動 → install → 起動 → maestro/smoke.yaml → スクショ | `autodev/evidence/` |

- **バージョン固定**: すべて `autodev/config/android_env.yaml` を参照（スクリプトへのハードコード禁止）。
- **パス解決**: ラッパー（`autodev/scripts/_common.sh`）が ANDROID_SDK_ROOT / JAVA_HOME / PATH をスクリプト内で解決。
  **ユーザーの .bashrc 等は変更しません**。`local.properties` は自動生成（git 管理外）。
- **診断のみ**: `bash setup.sh --doctor`（何も導入せず充足状況を一覧表示）。

## 対応 OS

| OS | 対応 | 備考 |
|---|---|---|
| Ubuntu (x86_64) | ◎ 一次サポート | KVM 推奨（`sudo usermod -aG kvm $USER` 後に再ログイン） |
| macOS | ○ ベストエフォート | system_image / JDK URL の調整が必要な場合あり |
| Windows | △ 非推奨 | WSL2 はエミュレータのネスト仮想化制約あり。実機接続（adb）での利用は可 |

## 必要な外部 URL（プロキシ環境向け）

- `https://dl.google.com/android/repository/...`（cmdline-tools / SDK パッケージ）
- `https://api.adoptium.net/...`（JDK。リダイレクト先 GitHub releases 含む）
- `https://services.gradle.org/...`（Gradle 本体）
- Maven Central / `https://dl.google.com/dl/android/maven2/...`（依存ライブラリ）
- `https://get.maestro.mobile.dev`（Maestro。リダイレクト先 GitHub releases 含む）

## トラブルシュート

| 症状 | 対処 |
|---|---|
| エミュレータが極端に遅い | KVM 未設定。`ls -l /dev/kvm` を確認し、`sudo apt install qemu-kvm && sudo usermod -aG kvm $USER` → 再ログイン |
| エミュレータが起動しない（ライブラリ不足） | `sudo apt install -y libpulse0 libgl1 libnss3`（setup.sh も試行する） |
| `adb devices` に実機が出ない | USB デバッグ許可 / ケーブル確認 / `autodev/scripts/run_adb.sh kill-server` 後に再接続 |
| install 失敗（INSTALL_FAILED_UPDATE_INCOMPATIBLE） | 署名不一致。`autodev/scripts/uninstall.sh`（データ消失）後に再 install |
| Gradle が遅い / 失敗する | 初回は依存DLで時間がかかる。`autodev/scripts/run_gradle.sh --refresh-dependencies assembleDebug` |
| 環境を作り直したい | `bash setup.sh` を再実行（冪等）。SDK ごと消す場合は `~/Android/Sdk` を削除してから |

## keystore の管理（重要）

- `autodev/secrets/keystore.properties` と `release.keystore` は setup.sh が自動生成します（git 管理外）。
- **必ずバックアップしてください**。紛失すると、実機にインストール済みアプリへ上書き更新できなくなります
  （uninstall → 再 install = アプリデータ消失が必要になる）。
