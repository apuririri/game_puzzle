# AutoDev for Android 中核規約（CLAUDE_MAIN.md）

このファイルは AutoDev for Android の中核規約である。`claude --dangerously-skip-permissions` で起動した
AIエージェントは、ルート `CLAUDE.md` から本ファイルへ誘導され、ここに書かれた規約に従って Android アプリの自動開発を進める。

> 起動直後にまず `autodev/開発進捗状況.md` を読み、前回までの状況を把握すること（冪等再開 / FR-5.8.1）。
>
> 本書中の「FR-x.y / 付録X / 第N章」等はすべて **`autodev/docs/要件定義書.md`**（AutoDev 設計仕様 v5.2 Android版）を指す。詳細はそちらを参照（`autodev/` はリリース時に削除されるため顧客には渡らない）。
>
> 運用フェイズ（実機デプロイ・洗い替え）の追補は **`autodev/docs/本番運用フェイズ補足.md`**。
> Web 版（auto_dev_agent）からのリメイク方針は **`../修正方針.md`**（参考）。

---

## 1. 起動プロトコル（3形態＋運用3形態）

| モード | 起動プロンプト | 入力ファイル | 発動 skill |
|---|---|---|---|
| システム全体開発 | 「要件定義書.mdのシステムを自動で開発してください」 | `autodev/inputs/要件定義/要件定義書.md` | autodev-system-loop |
| 機能単位開発 | 「機能要件_<機能名>.mdの機能を自動で開発してください」 | `autodev/inputs/要件定義/機能要件_<機能名>.md` | autodev-feature-loop |
| 修正対応 | 「修正_<修正名>.mdの修正を自動で対応してください」 | `autodev/inputs/修正対応/修正_<修正名>.md` | autodev-fix-loop |
| デプロイ | 「<source> から <target> へデプロイしてください」 | `autodev/config/deploy.yaml` | autodev-deploy |
| 洗い替え | 「不要データを洗い替えしてください」 | `autodev/config/retention.yaml` | autodev-cleanup |
| 再開 | 「作業を再開して」 | `autodev/state/current.json` | autodev-resume |

意味的に等価な日本語表現も受理する。判定不能・入力ファイル不明・複数候補・フォーマット違反のときのみ質問する（NFR-6.2.1）。

## 2. 絶対規約（破ってはならない）

1. **ラッパー経由実行**: `gradle` `./gradlew` `adb` `emulator` `avdmanager` `sdkmanager` `maestro` `apksigner` を直接呼ばない。必ず `autodev/scripts/` のラッパー・高レベルスクリプト（`run_gradle.sh` `run_adb.sh` `build.sh` `test_ui.sh` 等）を使う。PreToolUse hook が違反を exit 2 で fail させる。
2. **実機検証必須**: 機能・修正ループのクローズには、エミュレータ/実機でビルド・インストール・起動し Compose UI Test / Maestro で検証した証跡（ADB スクショ + logcat）が必須。Robolectric / プレビュー / mock での代替は禁止（FR-5.3 / FR-5.14.5）。
3. **直列開発**: 並列化しない（機能・イテレーション・修正すべて直列）。
4. **設計書は下流**: 実装が正。設計書は実装に同期する地図（ただし全体設計書/機能設計書の初版は開発前に新規作成可）。
5. **タスクと設計書の紐付け**: 全タスクに `design_doc_ref` を持たせ、`check_task_design_link.sh` で分割漏れを防ぐ。
6. **状態と進捗.md の同期**: `autodev/state/*.json` を更新したら `autodev/開発進捗状況.md` を同期再生成（PostToolUse hook が自動実行）。
7. **無確認自動化**: 起動後は原則ユーザーに承認を求めない。例外は NFR-6.2.1 の列挙ケースのみ。（**開発者実機へのデプロイ（device）は例外で、必ずユーザーの明示確認を得てから実行する**。アプリデータ消失を伴う uninstall も同様）
8. **ハングしない**: 進捗ゼロが続いたら停止して報告。最大試行回数超過で停止。エミュレータ起動・Gradle ビルド・テストはラッパーがタイムアウトを適用する。
9. **ツール本体の分離**: ツール関連は `autodev/` と `.claude/` に集約。`app/ maestro/ docs/設計/` にツール依存を混入させない。
10. **UI実装規約（testTag）**: 主要UI要素（ボタン・入力欄・リスト・画面ルート）に必ず `Modifier.testTag("<画面>_<要素>_<種別>")` を付与する（例: `login_email_input` `login_button` `home_add_button`）。ルート Compose で `testTagsAsResourceId = true` を有効に保つ（Maestro/UIAutomator から参照可能にするため）。座標タップ前提の実装・テストは書かない。
11. **ログ規約**: ログは `util/AppLogger.kt` 経由で統一タグ（`AppLog` `ApiLog` `DbLog` `UiLog`）で出力。例外は stacktrace 込みで `Log.e`。起動マーカー `APP_STARTED` を維持する（healthcheck / run.sh が確認する）。`println` / `printStackTrace` 禁止。
12. **フェーズ・ステップの自己判断スキップ禁止**: 起動した skill の標準手順（S1〜S15 / F1〜F7 + F6.5 / R1〜R7 + R6.5 / I0〜I8 / ペルソナテスト手順）を AI が **自己判断で省略・後回し・打ち切ることを禁止**する。「時間制約」「スコープ調整」「コンテキスト圧迫」「後続作業として」「次セッションで」「将来対応」「TODO として残す」等を理由とした省略は **すべて規約違反**である。実施が不可能な事象は NFR-6.2.1 の列挙ケースのみ。それに該当しない停止は **`current.json::blocked=true` + `blocked_reason` 明記** で人手介入待ちにし、完了宣言してはならない。
13. **完了宣言は機械ゲート PASS が前提**: ループ・フェーズの完了宣言（「✅ 機能完了」「✅ システム完了」「✅ 修正完了」等を進捗.md・attestation・state に書き込む / mode を空にする / コミットメッセージに `closed:` を付ける）は、対応する完了ゲートが PASS した直後にのみ許可される。
    - 機能ループ完了: F7 の全ゲート（`check_design_sync.sh` / `check_dead_assets.sh` / `check_room_schema.sh` / `check_real_device_evidence.sh` / **`check_persona_test_evidence.sh <機能名> feature`（FR-5.9.8）** / `check_progress_md_sync.sh`）PASS + attestation 出力（`persona_test_ref` 併記）+ プッシュ完了。
    - 修正ループ完了: R7 の全ゲート PASS + impact_analysis 記録 + **`check_persona_test_evidence.sh <修正名> fix`（FR-5.9.9）** PASS + `persona_test_ref` 併記 + プッシュ完了。
    - ペルソナテスト完了: 計画した全 schedule の `state/persona_tests/<番号>.json` 存在 + schedule.status=completed + 派生改善要望の修正ループ全完了（または `blocking_issues` への明示転記）。
    - 統合確認 (S10) 完了: `check_no_mocks.sh` PASS + 統合実機シナリオ all PASS + `attestations/integration.json` 出力 + 派生改善要望全完了。
    - UI 改善 (S11) 完了: 全画面 before/after スクショ揃い + `check_ui_polish_evidence.sh` PASS + `attestations/ui_polish.json` 出力。
    - リリース最終確認 (S14) 完了: `check_release_ready.sh --gate` PASS + リリースビルドスモーク PASS + `attestations/release.json` 出力。
    - **システムループ完了**: `autodev/scripts/check_system_completion.sh` が PASS することが**完了宣言の絶対的前提**。`set_current.sh` で `mode=""` への遷移を行う前に必ず実行する。同スクリプトは S10 / S11 / S14 の 3 attestation の存在も検査する（規約 12〜15）。
14. **未完成領域を残してクローズ禁止**: 「後続作業」「将来対応」「次セッションで」「TODO として残す」「時間の都合上省略」「スコープ外として除外」のような語で **未着手・未完成のタスクや機能を残したままループをクローズしてはならない**。残したい場合は、明示的に `autodev/inputs/修正対応/修正_<理由>.md` を生成して修正ループに渡すか、人手介入待ちで停止すること。`autodev/scripts/check_no_skip_excuses.sh` が進捗.md / state / attestation / コミットメッセージ中の禁止語を機械検出する。
15. **ペルソナテストと UI 実装の構造的必須化**:
    - ペルソナテストはシステムループの正規フェーズである（中核思想7 / FR-5.9）。S7 で立てた計画 (`system.json::persona_test_plan.schedule[]`) は **全件実施**する。「時間がない」「機能が単純」「ペルソナテスト不要」等を理由にした省略は禁止。実施が完全に不可能な場合は人手介入待ちで停止する。
    - 機能ループ F6.5 / 修正ループ R6.5 のペルソナテストも正規フェーズである（FR-5.9.8 / FR-5.9.9）。F7 / R7 クローズ前に必ず実施し、改善要望をサブ修正ループで全消化する。**設定 OFF（`feature_loop.persona_test_enabled=false` / `fix_loop.persona_test_enabled=false`）は明示的な OFF（規約15 ホワイトリスト）として `check_no_skip_excuses.sh` で AI 判断の省略と区別する**。
    - 機能要件書に画面・UI操作の受け入れ条件が含まれる機能では、F3 のタスク分割で **`ui/screen/` 層のタスクを必ず生成**し、`run_real_device_check.sh` で実機 UI 動線を検証する。UI 実装を「後続作業」として除外することは禁止。

> 注: 会話履歴の `/compact` 連携はツールから撤去済み（compact はユーザー入力専用で自動化不可・組み込み自動 compact が安全網）。

## 3. ループ構造（詳細は要件定義書 第9章）

- **システムループ S1〜S15**: ペルソナ定義 → 全体設計書 → 機能リスト補完 → 依存順ソート → **S6.5 全機能設計書 先行作成＆要件カバレッジ確認（scope=system / FR-5.21.1）** → 機能ループ群（3機能ごとにペルソナテスト）→ **S10 全体結合確認・改善** → **S11 UIデザイン改善** → S12 全体スモーク → S13 顧客向けドキュメント → **S14 デプロイ・リリース最終確認** → S15 完了報告。
- **機能ループ F1〜F7**: 要件確認 → 設計書確認/作成 → タスク分割 → イテレーション群 → 全体レビュー → **F5.5 要件⇄設計⇄実装 トレーサビリティ照合（scope=feature / FR-5.21.2）** → 実機検証 → **F6.5 ペルソナ駆動テスト（scope=feature / FR-5.9.8）** → クローズ（ゲート → attestation → コミット・プッシュ）。
- **修正ループ R1〜R7**: 影響範囲分析を強化した機能ループ。R5 イテレーション後、**R5.5 要件⇄影響範囲⇄実装 トレーサビリティ照合（scope=fix / FR-5.21.3）** → R6 実機検証 → **R6.5 ペルソナ駆動テスト（scope=fix / FR-5.9.9）** を経て R7 クローズ。R6.5 のスキップ条件は loop.yaml の `fix_loop.persona_test_enabled` / severity 足切り / `source_scope` による無限ループ防止の 3 種（判定主体は AI / 規約15 ホワイトリスト）。
- **統合確認ループ IV1〜IV6**（S10）: モック検出 → モック廃止 fix-loop → HEADFUL 全機能統合実機検証 → 利用目的視点評価 → 改善 fix-loop → attestation。
- **UI 改善ループ UP1〜UP7**（S11）: 全画面棚卸し → before スクショ → 評価軸で改善案列挙 → fix-loop → after スクショ → 差分出力 → attestation。
- **リリース最終確認ループ RG1〜RG5**（S14）: 静的ゲート群 → 署名済み APK スモーク → fail を fix-loop → attestation → デプロイ即実行可能を明示。
- **イテレーション I0〜I8**: ヘルスチェック → 小さな実装 → 設計書同期 → レビュー → scoped tests → ground-truth 再実行 → ゲート → コミット → state 更新。

## 4. skills 一覧（`.claude/skills/` に同期配置）

`autodev-system-loop` / `autodev-feature-loop` / `autodev-fix-loop` / `autodev-persona-test` /
`autodev-coverage-check` / `autodev-integration-verify` / `autodev-ui-polish` / `autodev-release-gate` /
`autodev-gradle-env` / `autodev-device-verify` / `autodev-design-sync` / `autodev-progress-md` /
`autodev-deploy` / `autodev-cleanup` / `autodev-resume`

該当タスクに入ったら対応 skill を発動する。skill 実体は `autodev/skills/<名>/SKILL.md`、`.claude/skills/` へは
`autodev/scripts/sync_claude_dir.sh` で同期する。

## 5. hooks 一覧（`.claude/settings.json` で宣言、実体 `autodev/hooks/claude/`）

| hook | 役割 |
|---|---|
| SessionStart | 進捗.md を context 注入 + Android 環境警告 |
| UserPromptSubmit | モード判定・入力形式チェック |
| PreToolUse(Bash) | 禁止コマンド検出（ラッパー強制） |
| PostToolUse(Edit\|Write) | state JSON 更新時に進捗.md 自動再生成 |
| PostToolUse(Bash) | git commit 後の軽量ゲート |

緊急時のみ `AUTODEV_DISABLE_HOOKS=1` で全 hook を no-op 化できる（使用したら `HARNESS_NOTES.md` に記録 / FR-5.15.5）。

## 6. 主要スクリプト

- セットアップ: `setup.sh`（ルート。JDK/SDK/AVD/Maestro をゼロタッチ導入・冪等）`setup_android_env.sh` `setup_maestro.sh`
- ヘルスチェック: `healthcheck.sh` / 環境検証: `check_android_setup.sh`
- ラッパー: `run_gradle.sh` `run_adb.sh` `run_emulator.sh` `run_sdkmanager.sh` `run_maestro.sh`
- エミュレータ: `start_emulator.sh`（headless 既定。HEADFUL=1 で GUI）`stop_emulator.sh`
- 高レベル: `build.sh` `install.sh` `uninstall.sh` `run.sh` `build_install_run.sh` `screenshot.sh` `logcat.sh` `logcat_error.sh` `clean_logs.sh`
- テスト: `test_unit.sh`（JUnit）`test_ui.sh`（Compose UI Test）`test_maestro.sh`（E2E）`run_scoped_tests.sh` `run_full_tests.sh` `run_persona_tests.sh`（`--scope system\|feature:<名>\|fix:<名>`）
- ペルソナ補助: `ensure_personas.sh`（personas.json 存在/最低人数チェック・フォールバック発火）
- 実機検証: `run_real_device_check.sh`（build→install→起動→検証→スクショ→logcat→attestation）
- ゲート: `check_design_sync.sh` `check_dead_assets.sh` `check_room_schema.sh` `check_testtag_coverage.sh` `check_real_device_evidence.sh` `check_persona_test_evidence.sh`（F7/R7 ゲート / FR-5.9.8/9）`check_release_clean.sh` `check_task_design_link.sh` `check_progress_md_sync.sh` `check_requirement_design_coverage.sh`（S6.5 / FR-5.21.1）`check_traceability.sh`（F5.5 / R5.5 / FR-5.21.2/3）
- 整合性: `check_state_consistency.sh`（案4）`check_config.sh`（loop/deploy/retention/watchdog/android_env の JSON Schema 検証 / 案5）`check_doc_sync.sh`（SKILL.md::required_doc_version ↔ 要件定義書 / 案6）
- 完了強制: `check_system_completion.sh`（システムループ完了の事前ゲート / 規約13）`check_no_skip_excuses.sh`（言い訳語の機械検出 / 規約14）
- S10 統合確認: `check_no_mocks.sh`（モック/スタブ/TODO 残存検出）`run_integration_check.sh`（HEADFUL 全機能 + 機能横断シナリオ実機検証）
- S11 UI 改善: `list_screens.sh`（NavHost ルート列挙）`capture_all_screens.sh`（全画面 before/after スクショ）`check_ui_design.sh`（評価軸欠落検出）`check_ui_polish_evidence.sh`（before/after 揃い確認）
- S14 リリース最終確認: `check_release_ready.sh`（ラッパー）`check_no_debug_artifacts.sh` `check_manifest_release.sh` `check_release_build.sh` `check_release_strings.sh` `check_dependencies.sh` `run_release_smoke.sh`（署名済み APK 実機スモーク）
- 進捗: `update_progress_md.sh` / skills 同期: `sync_claude_dir.sh`
- デプロイ: `deploy.sh` `check_deploy_ready.sh` `resolve_artifact.sh` `run_smoke_device.sh` `rollback.sh`
- ライフサイクル: `cleanup.sh`（洗い替え）`archive_critical_evidence.sh`（attestation の screenshots/logcat を `evidence/_archived/` へ永続化 / 案7）
- 再開: `set_current.sh` `check_resume_point.sh` `verify_resume_point.sh`（ground-truth 再検証 / 案1）
- hook 補助: `resolve_hook_failures.sh`（案2）
- 無人運用(opt-in): `start_session.sh` `watchdog.sh` `setup_watchdog.sh` `teardown_watchdog.sh`

## 7. 状態ファイル（`autodev/state/`、git tracked）

`loops/system.json` / `loops/<対象名>.json` / `tasks/<対象名>.json` / `iterations/<対象名>/<番号>.json` /
`attestations/<対象名>.json` / `attestations/coverage.json`（S6.5 / FR-5.21.1 / B.12）/
`traceability/<対象名>.json`（F5.5 / R5.5 / FR-5.21.2/3 / B.13）/
`personas/personas.json` / `persona_tests/<番号>.json` / `history/`。
`current.json`（現在地ポインタ＝再開の起点 / tracked）。`heartbeat.json`（稼働検知 / ignore）。
> current.json 契約: 人手待ち停止時は blocked=true、完全完了時は mode を空に（`set_current.sh`）。watchdog の誤再開を防ぐ。
> attestation の実機検証証跡キーは `real_device_evidence`（screenshots_dir / logcat_dir / verified_at / device_serial）と `evidence.screenshots` / `evidence.logcat`。
スキーマは要件定義書 付録B。atomic 更新（tmp → rename）。

## 8. 技術スタック

- アプリ: Kotlin + Jetpack Compose（Material 3）+ ViewModel/StateFlow + Coroutines（`app/`）
- DB: Room（exportSchema=true、schema は `app/schemas/` に tracked。migration はテスト必須）/ 設定: DataStore
- API通信: Retrofit + OkHttp（必要時。単体テストは MockWebServer 可、実機検証の mock 代替は不可）
- ビルド: Gradle（Wrapper 同梱・Kotlin DSL・Version Catalog）。環境版数は `autodev/config/android_env.yaml` にピン留め
- 実行環境: エミュレータ（AVD・headless 既定）/ 開発者実機（adb）。`loop.yaml::application_id` が対象アプリID
- テスト: JUnit（src/test）/ Compose UI Test（src/androidTest・testTag 操作）/ Maestro（maestro/*.yaml・E2E）
- 検証手段: ADB screenshot（`screenshot.sh`）+ logcat（統一タグ・`logcat.sh` / `logcat_error.sh`）

## 9. リリース（顧客提供物の分離 / 付録I）

```bash
autodev/scripts/check_release_clean.sh        # コード/設計のツール依存チェック
# 納品 APK を確保（autodev/ 削除前に取り出す）
cp autodev/artifacts/<最新>.apk <納品先>/
rm -rf autodev/ .claude/ CLAUDE.md            # ツール本体を一括削除
rm -f app/CLAUDE.md maestro/CLAUDE.md
git checkout -b release-<バージョン> && git add -A && git commit -m "chore: strip AutoDev harness"
```

残った `app/ maestro/ docs/設計/ gradle一式 README.md docs/操作手順書.md docs/インストール手順.md` + 署名済み APK が顧客提供物。

---

本ツール（AI エージェント）は Claude Code 専用で **dev / 運用端末側でのみ**動かす。デプロイ先は開発者のスマートフォン（ストア公開は対象外）。詳細は `autodev/docs/本番運用フェイズ補足.md`。
