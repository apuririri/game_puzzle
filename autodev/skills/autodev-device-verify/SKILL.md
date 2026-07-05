---
name: autodev-device-verify
description: 機能ループ F6・修正ループ R6・ペルソナテストなどの実機検証フェーズで発動。Robolectric/プレビュー/モックで代替せず、エミュレータまたは実機でアプリをビルド・インストール・起動し、Compose UI Test / Maestro で受け入れ条件を検証して ADB スクリーンショット + logcat 証跡を残すための標準手順。
required_doc_version: "5.2"
---

<!-- version: 1.0 -->

# autodev-device-verify skill

## 適用条件

- 機能・修正ループの実機検証（F6 / R6）、ペルソナ駆動テスト、イテレーション中の画面確認。

## 検証3層の使い分け（修正方針 §3-3）

| 層 | 手段 | 用途 | タイミング |
|---|---|---|---|
| 単体 | JUnit（`test_unit.sh`） | UseCase/Repository/ViewModel ロジック | 各イテレーション |
| UI | Compose UI Test（`test_ui.sh`、testTag 操作） | 画面単位の操作・表示・遷移 | 各イテレーション〜クローズ |
| E2E | Maestro（`test_maestro.sh`、YAML flow） | 機能横断の主要動線 | クローズ（F6）・スモーク・ペルソナ |

## 標準手順

1. **ヘルスチェック**: `autodev/scripts/healthcheck.sh` で環境健全性を確認（デバイス無しならエミュレータ自動起動）。
2. **テスト作成/更新**: 受け入れ条件から Compose UI Test（`app/src/androidTest/`）または Maestro flow（`maestro/<対象名>.yaml`）を作成。UI 要素は **testTag** で参照（座標タップ禁止）。
3. **実行（必ずラッパー/高レベルスクリプト経由）**:
   - 高レベル（デバイス確保 + build + install + 起動 + 検証 + スクショ + logcat + attestation 追記）:
     `autodev/scripts/run_real_device_check.sh <対象名> [maestro/<flow>.yaml|テストクラスFQCN]`
   - 個別: `test_ui.sh [FQCN]` / `test_maestro.sh <flow> <対象名>` / `screenshot.sh <対象名>` / `logcat.sh <対象名>`
4. **ヘッドフル（任意）**: 既定はヘッドレスエミュレータ。人間が見たいときのみ `HEADFUL=1 autodev/scripts/start_emulator.sh`。
5. **エラー調査**: fail 時は `logcat_error.sh <対象名>` で FATAL/ANR/統一タグ（AppLog/ApiLog/DbLog/UiLog）を抽出して原因特定。
6. **証跡確認**: `autodev/scripts/check_real_device_evidence.sh <対象名>` でスクショ + logcat + クラッシュ無しを確認。
7. **記録**: 証跡パスが attestation（`real_device_evidence`）に記録され、進捗.md が再生成されていることを確認。

## 完了条件

- 受け入れ条件のシナリオが実機/エミュレータで PASS / スクショが `autodev/evidence/screenshots/<対象名>/`、logcat が `autodev/evidence/logcat/<対象名>/` に存在 / クラッシュ痕跡なし。

## 失敗時の挙動

- テスト fail → fail 内容と logcat を入力にイテレーションループへ戻る。
- デバイス/エミュレータが起動しない → `check_android_setup.sh` で環境確認、`start_emulator.sh` 再試行。
- **Robolectric / プレビュー / モック画面での代替は禁止**（FR-5.14.5 相当）。

## 関連参照

- 規約: `app/CLAUDE.md` / `maestro/CLAUDE.md`
- 詳細仕様: 要件定義書 FR-5.3 / FR-5.14 / 付録F
