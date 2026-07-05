# app/ 規約（AutoDev for Android）

このディレクトリは顧客提供物の Android アプリ本体（Kotlin + Jetpack Compose + Room + DataStore）。

## 必ず守る

1. **ラッパー経由実行**: 素の `gradle` / `./gradlew` / `adb` は禁止。`autodev/scripts/run_gradle.sh` `build.sh` `test_unit.sh` `test_ui.sh` 等を使う（PreToolUse hook が fail させる）。
2. **testTag 必須**: 主要UI要素（ボタン・入力欄・リスト・画面ルート）に `Modifier.testTag("<画面>_<要素>_<種別>")`（例 `login_email_input` `home_add_button`）。座標タップ前提の実装・テストは禁止。
3. **testTagsAsResourceId**: MainActivity のルート Compose で有効化済み。**削除禁止**（Maestro から testTag が見えなくなる）。
4. **ログ規約**: `util/AppLogger.kt` 経由・統一タグ（AppLog/ApiLog/DbLog/UiLog）。例外は stacktrace 込み。`println` / `printStackTrace` 禁止。起動マーカー `APP_STARTED`（App.kt）は削除禁止。
5. **Room**: `exportSchema = true` を維持。schema version を上げたら **Migration 定義 + MigrationTest（androidTest）必須**（`check_room_schema.sh` がゲート）。`app/schemas/` は git tracked。
6. **DataStore**: 設定キーは `settings/AppSettingsDataStore.kt` に集約。追加したら `docs/設計/data_model.md` を同期。
7. **構成**: ui/screen・ui/component・ui/navigation / data/local・repository・remote / domain/model・usecase / settings / util を維持。画面追加時は NavHost と `docs/設計/screen_flow.md` を同期。
8. **実機検証**: Robolectric/プレビュー/mock で実機検証を代替しない。クローズには `run_real_device_check.sh` の証跡（スクショ + logcat）が必須。
9. **コミット禁止物**: `build/` `local.properties` keystore 類（.gitignore 済み）。
   **秘密情報（API キー等）はソースにハードコード禁止**。必要なら `autodev/secrets/` か `local.properties` から Gradle 経由で BuildConfig に注入、またはユーザー入力値として DataStore に保存する。
10. **applicationId 変更時**: `autodev/config/loop.yaml::application_id` と `maestro/*.yaml` の appId も合わせる。
