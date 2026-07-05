# 変更履歴（CHANGELOG）

本ファイルは [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に倣い、
[セマンティック バージョニング](https://semver.org/lang/ja/) を採用する。

AutoDev Agent は機能・修正・デプロイの完了時、および洗い替え（autodev-cleanup）前に、
完了項目の要約をここへ追記する（詳細証跡をアーカイブ/削除しても履歴が残るようにするため）。

## [Unreleased]
### Added
- **要件定義書 v5.2 へ昇格 / システムループ S6.5 / 機能ループ F5.5 / 修正ループ R5.5: 要件↔設計↔実装 トレーサビリティ確認フェーズを追加**（FR-5.21.1 / FR-5.21.2 / FR-5.21.3）。
  - **S6.5（システム単位）**: 依存順ソート S6 とペルソナテスト計画 S7 の間に挿入。ソート済み機能リストを順に F2 のみ直列実行して各機能設計書（`docs/設計/features/<機能名>.md`）を先行作成し、`check_requirement_design_coverage.sh` で要件 ⇄ 設計のセクション網羅 + testTag 候補抽出を機械検査。未マッピング要件は既存設計書追記 or 新規機能を機能リストに atomic 追加（依存順再ソート / `ui_required` 設定）→ 再走査。上限 `coverage_check.max_cycles`（既定 2）超過で `blocked=true` 停止（S7 へ進まない）。
  - **F5.5（機能単位）**: F5 全体レビューと F6 実機検証の間に挿入。`check_traceability.sh <機能名> --scope feature` で「要件項目 ⇄ 設計セクション ⇄ tasks（layer 含む）⇄ files_changed」の4層連鎖を機械検査。
  - **R5.5（修正単位）**: R5 イテレーションと R6 実機検証の間に挿入。F5.5 と同じ手順を `scope=fix` で実施。R2 の `impact_analysis` の全要素がタスク化＋実装されていることも検査。
  - **Android 固有強化**: layer × カテゴリ マッピング（画面要素=`[ui]` / ユーザー操作=`[ui,viewmodel]` / エラーケース=`[ui,viewmodel,domain]` / データモデル=`[data]` / 受け入れ条件=`[test]`）+ testTag 候補 grep（`Modifier.testTag("候補")` 実体確認）+ Room Entity Kotlin ファイル存在 + Maestro flow / Compose UI Test 紐付け確認。`system.json::features[<対象>].ui_required==false` のとき UI 系検査を明示的にスキップ。
  - **AI 補完承継**: AI が `covered_by_ai=true` + `ai_reason="<根拠>"` を JSON に書き込むと、次サイクルでスクリプトが `(category, item)` 一致で承継。追加タスク実装後の再走査でも PASS は維持される（FR-5.5.5 ground-truth 補完の踏襲）。
  - 新規 skill `autodev-coverage-check`（3 スコープ対応 / v1.0）。`--scope system|feature:<名>|fix:<名>` で呼び分け（既存 `autodev-persona-test` と同じパターン）。
  - 新規 script: `check_requirement_design_coverage.sh`（S6.5）/ `check_traceability.sh`（F5.5 / R5.5）。
  - 新規 state スキーマ: B.12 `state/attestations/coverage.json`（Android 単一ファイル方式 / 内部 `cycles[]` で履歴保持）/ B.13 `state/traceability/<対象名>.json`。
  - `loop.yaml` に `coverage_check`（enabled / max_cycles）と、`feature_loop` / `fix_loop` 各々に `traceability_enabled` / `traceability_max_cycles` を追加。`_schema/loop.schema.yaml` も同期。
  - F7 / R7 attestation（B.5）に `traceability_ref` / `traceability_passed` フィールドを追加。`system.json` に `s6_5_result` / `loops/<対象名>.json` に `f5_5_result` / `r5_5_result` を追加。`tasks/<対象名>.json` に `source: "traceability_gap"` + `cycle` フィールドの記述例を追加。
  - F7 / R7 クローズゲートに `check_traceability.sh --gate` を挿入（既存 `check_testtag_coverage.sh` の後、実機検証より前）。
  - `check_system_completion.sh` に S6.5 PASS / 全機能 attestation の `traceability_passed=true` 検査を追加（S15 完了宣言の絶対前提）。
  - `update_progress_md.sh` の機能リスト進捗テーブルに `F5.5 (gap/AI補完)` 列を追加 / システムループ進捗に S6.5 行を追加。
  - 既存ゲートとの責務分離: `check_task_design_link.sh`（タスク↔設計書セクション / 既存）/ `check_design_sync.sh`（設計書↔実装 / 既存）/ `check_room_schema.sh`（Room schema / 既存）/ `check_testtag_coverage.sh`（testTag 網羅 / 既存）/ 新規2件（要件↔設計 / 要件↔設計↔タスク↔実装）が補完関係。
  - 規約15 ホワイトリスト拡張: `coverage_check.enabled=false` / `feature_loop.traceability_enabled=false` / `fix_loop.traceability_enabled=false` を明示的 OFF として `check_no_skip_excuses.sh` の AI 判断省略と区別。
  - 受け入れチェックリスト 14.4 に S6.5 / F5.5 / R5.5 / `traceability_ref` の項目を追加。
  - 要件定義書 版数を **5.1 → 5.2** へ昇格（改訂履歴に v5.2 行追加 / 全 SKILL.md の `required_doc_version` を 5.2 へ同期 / `check_doc_sync.sh` PASS 確認済み）。
  - `autodev/CLAUDE_MAIN.md` の §3 ループ構造に S6.5 / F5.5 / R5.5 を追記、§4 skill 一覧に `autodev-coverage-check` を追記、§6 主要スクリプトに新規 2 本を追記、§7 state ディレクトリに `attestations/coverage.json` / `traceability/<対象名>.json` を追記、版数表記 v5.1 → v5.2。

### Fixed / Reviewed (S6.5/F5.5/R5.5 のセルフレビュー指摘を反映)
- **`ui_required: false` 機能の判定が壊れていたバグを修正**: `check_traceability.sh` および `check_system_completion.sh` で `jq '.ui_required // "true"'` を使っていたが、jq の `//` 演算子は `null` だけでなく `false` 値も置換してしまうため、`ui_required: false` の機能でも `true` と誤判定されていた（DB 基盤など UI なし機能の検査が破綻）。両スクリプトとも `(.ui_required == false)` で boolean を直接比較する形に修正。`check_system_completion.sh` 側の同一バグは Web 版から継承された既存問題（規約15 関連）で、本コミットで併せて修正。
- **`ui_required: false` 機能で要件書「画面要素」「ユーザー操作」項目を抽出スキップ**: 修正前は items[] に含まれて files=[] のため誤ギャップを生んでいた。`extract_requirement_items` に `ui_req` パラメータを追加し、awk 内で `ui_required=false` のときこれら2カテゴリを抽出対象から除外。
- **`scope=fix` の「影響範囲」カテゴリを抽出対象に追加**: 修正対応書テンプレートに「## 4. 影響範囲」セクションがあるが、F5.5 用に作った awk パターンでは抽出されず R5.5 で検査品質が低下していた。awk に `else if (line ~ /影響範囲/) category="影響範囲"` を追加し、`expected_layers=[]`（layer 不問）として実装証跡 grep のみ実施。影響範囲項目はファイルパス/ファイル名を含むことが多いため、basename token を抽出して `app/src/` と `maestro/` で grep し、ヒットしなければ通常の token grep にフォールバック。
- **テンプレ guide 文除外パターンを拡張**: 修正対応書テンプレートの「優先度: 高 / 中 / 低」「理由:」も `extract_requirement_items` の guide 文除外に追加。
- **入力ファイル選択優先順位を SKILL.md に明記**: `scope=feature` で機能要件書が無く要件定義書をフォールバック使用する場合、文書全体の「画面要素」セクション等が混在抽出されるため、AI は当該機能名のセクション範囲のみを検査対象とみなす旨を `autodev-coverage-check` SKILL.md に追加。
- 要件定義書 FR-5.21.2.3 / FR-5.21.2.4 を実装に合わせて更新。`expected_layers=[]` の layer 検査スキップ動作、影響範囲カテゴリの追加、jq boolean 判定方法を明記。

### Verified (post-review)
- `ui_required=false` 機能で「画面要素」が抽出されず items_total=1（データモデルのみ）で PASS することを確認
- `scope=fix` で「影響範囲」項目が抽出され、ファイルパス token から basename を抽出して正しく実体検出（`LoginForm.kt` ヒット）することを確認
- 既存テストケース（regression）が引き続き同じ結果を返すことを確認
- `check_doc_sync.sh` / `check_config.sh` / `sync_claude_dir.sh --check` 全 PASS

- **要件定義書 v5.1 へ昇格 / 機能ループ F6.5 / 修正ループ R6.5: 機能単位開発モード・修正対応モードでもペルソナ駆動テストを必須化**（FR-5.9.8 / FR-5.9.9）。
  - 機能追加時: F6（受け入れ条件の実機検証）後、F7（クローズ）前に `scope=feature:<機能名>` でペルソナテストを実施。新機能を主動線とし、既存連携動線も含めて Maestro 実機（エミュレータ/実機）で検証。Maestro flow に `takeScreenshot` を要所に挿入して画面キャプチャを取得。
  - 修正対応時: R6 後、R7 前に `scope=fix:<修正名>` でペルソナテストを実施。R2 の `impact_analysis` を入力にリグレッション観点を必須化。
  - Android 固有操作（戻る / 回転 / バックグラウンド退避→復帰 / プロセス kill / 機内モード / 権限拒否）を最低1つ織り込む。
  - 改善要望（機能改善 / UI 改善 / Android 作法）を `修正_persona_<scope>_<対象>_<改善名>.md` として自動生成し、サブ修正ループで F7 / R7 クローズ前にすべて消化。
  - 上限は `feature_loop.persona_test_max_cycles` / `fix_loop.persona_test_max_cycles`（既定 2）。超過時は `blocking_issues` に集約し `blocked=true` で停止。
  - R6.5 のスキップ判定（判定主体は AI）: ①`fix_loop.persona_test_enabled=false`、②severity 足切り（`fix_loop.persona_test_severity_threshold` 既定 `low`）、③`source_scope` が `feature`/`fix`（無限ループ防止）。
  - 規約15 ホワイトリスト: `feature_loop.persona_test_enabled=false` / `fix_loop.persona_test_enabled=false` は明示的な OFF として `check_no_skip_excuses.sh` で AI 判断の省略と区別する。
- 新規 script: `ensure_personas.sh`（`personas.json` 存在 + 最低人数チェック / フォールバック発火）、`check_persona_test_evidence.sh`（F7 / R7 クローズゲート / `test_number` の数値降順で最新 attestation を判定）。
- `run_persona_tests.sh` に `--scope system|feature:<名>|fix:<名>` を追加。flow 命名と証跡サブパスを scope 別に分離（`maestro/persona/persona_<番号>_{feature_<名>|fix_<名>}_*.yaml` / `evidence/persona_tests/<番号>/{feature_<名>|fix_<名>}/`）。
- `loop.yaml` に `feature_loop` / `fix_loop` セクション（`persona_test_enabled` / `persona_test_max_cycles` / `persona_test_severity_threshold`）と `_schema/loop.schema.yaml` を同期。
- `autodev/state/persona_tests/<番号>.json` スキーマに `scope` / `target` / `triggered_from` / `blocking_issues` / `result` / `cycles_used` / `cycles_max` / `r6_5_skipped` / `r6_5_skip_reason` を拡張（B.7）。
- 機能/修正の attestation に `persona_test_ref: <番号>` / `persona_test_passed: <bool>` を併記する規約を追加（B.5 / FR-5.9.7）。
- ペルソナテスト実施番号の採番ルール（全 scope 通し連番 / `max(.test_number) + 1`）を要件定義書 B.7 と `autodev-persona-test` SKILL.md に明記。scope=system / feature / fix が同ディレクトリを共有するため衝突防止。
- 受け入れチェックリスト 14.4 に F6.5 / R6.5 / ペルソナ再利用ルール / 規約15 ホワイトリスト整理の項目を追加。
- 要件定義書版数 5.0 → 5.1 へ昇格。改訂履歴に v5.1 行を追加（S10〜S15 拡張 + F6.5 / R6.5 を束ねる）。全 SKILL.md（autodev/skills/ + .claude/skills/ ミラー）の `required_doc_version` を 5.0 → 5.1 に同期更新（`check_doc_sync.sh` PASS）。
- `autodev/CLAUDE_MAIN.md` の要件定義書バージョン表記 v5.0 → v5.1、§3 ループ構造に F6.5 / R6.5 と判定主体・スキップ条件を明記、§6 主要スクリプトに `check_persona_test_evidence.sh` / `ensure_personas.sh` / `run_persona_tests.sh --scope` を追記。
- `on_user_prompt_submit.sh` で機能/修正開発モード判定時に F6.5 / R6.5・クローズゲート・無限ループ防止ルールを通知。
- `update_progress_md.sh` のペルソナテスト履歴テーブルに `scope` / `target` / `triggered_from` / 残課題数 列を追加（B.7 スキーマ整合）。
- `check_no_skip_excuses.sh` のヘッダに規約15 ホワイトリスト方針（`r6_5_skip_reason` は禁止語句にひっかからない条件式で記述）を明記。

### Fixed / Reviewed (F6.5/R6.5 一連修正のセルフレビュー反映)
- `autodev-feature-loop` SKILL.md の完了条件「F7 の **9 ステップ**」を F6.5 追加後の **11 ステップ**に修正。`check_persona_test_evidence.sh <機能名> feature` を含む旨も併記。
- `autodev/CLAUDE_MAIN.md` 規約13 の機能/修正ループ完了ゲート列挙に **`check_persona_test_evidence.sh <機能名> feature`（FR-5.9.8）** / **`check_persona_test_evidence.sh <修正名> fix`（FR-5.9.9）** を明示。attestation に `persona_test_ref` 併記の必須化も明記。
- `check_state_consistency.sh` / `check_system_completion.sh` の `persona_tests/<番号>.json` 探索ロジックをゼロ詰めあり/なし両形式の fallback に変更。新採番ルール（`max(.test_number)+1` / 非ゼロ詰めが正規）と既存運用（2 桁ゼロ詰め）の衝突を回避し、誤判定「実施記録あり / schedule完了済みなのに不在」の隠れバグを是正。
- 要件定義書 B.7 にファイル名規約（`<test_number>.json`・ゼロ詰めなしが正規 / 互換のため両形式を許容）を明示。
- `autodev-system-loop` SKILL.md S9 に F6.5 を明示。「機能ループ内では F6.5 が必ず走る」「F6.5（機能単体観点）と S7/S9 ペルソナテスト（機能横断・統合観点）は目的が異なるため重複ではない」と区別。
- `update_progress_md.sh` の機能リスト進捗テーブルに **persona_test_ref 列**を追加。各機能 attestation を開いて `persona_test_ref` を抽出し追跡可能性を上げる（attestation 不在/未付与の機能は "-"）。
- `maestro/CLAUDE.md` を更新。scope 別 flow 命名規約（system / feature:<名> / fix:<名>）、Android 固有操作（戻る/回転/バックグラウンド復帰/プロセス kill/機内モード/権限拒否）の最低1つ織り込み必須、flow 要所での `takeScreenshot` 必須、F6.5 / R6.5 のシナリオ範囲（連携動線・リグレッション観点）を明文化。

### Changed
- `autodev-persona-test` SKILL.md を v1.0 → v2.0 に拡張。3 スコープ（system / feature / fix）対応。ペルソナ定義フォールバック・実施番号採番ルール・UI 観点吸収・Android 固有操作・スコープ別 flow 命名・サイクル間デバイス再利用を明文化。
- `autodev-feature-loop` SKILL.md を v1.0 → v2.0 に拡張。F6.5 を追加し、F7 クローズゲートに `check_persona_test_evidence.sh <機能名> feature` を挿入。attestation に `persona_test_ref` を含める。
- `autodev-fix-loop` SKILL.md を v1.0 → v2.0 に拡張。R6.5 を追加。判定主体（AI）・参照フィールド（R1 で state に転記済みの `source_scope` / `severity`）・スキップ時 state 記録（`r6_5_skipped` / `r6_5_skip_reason`）・severity 比較基準（low < medium < high）を明示。R7 クローズゲートに `check_persona_test_evidence.sh <修正名> fix` を挿入。
- `autodev-system-loop` SKILL.md S3 で既存 `personas.json` を再生成せず ID 末尾追加のみとする規約を明記（FR-5.9.1 改訂）。
- 要件定義書 シナリオ B / シナリオ C を F6.5 / R6.5 の実施前提に書き換え。FR-5.11.3 / FR-5.12.1 / FR-5.12.2 に F6.5 / R6.5 の必須化を反映。9.3 / 9.4 フロー図に F6.5 / R6.5 を追加。

- 初期雛形（AutoDev for Android）。auto_dev_agent（Web 版）を修正方針.md に基づき Android アプリ自動開発向けにリメイク。
  - 対象スタック: Kotlin + Jetpack Compose + Room + DataStore + Retrofit / JUnit + Compose UI Test + Maestro
  - 検証: エミュレータ/実機 + ADB screenshot + logcat（統一タグ） / デプロイ: 開発者実機へ adb install
  - setup.sh によるゼロタッチ環境構築（JDK/SDK/AVD/Maestro 自動導入・非対話・冪等）
- **フェーズ省略・完了宣言の機械強制**（CLAUDE_MAIN.md 絶対規約 12〜15）。
  AI エージェントが「時間制約」「後続作業」「TODO として残す」等の理由でペルソナテストや UI 実装を
  自己判断スキップし、未完成のまま完了宣言する事象を構造的に防止する。
  - `autodev/scripts/check_no_skip_excuses.sh`: 言い訳語の機械検出（9パターンの正規表現で
    進捗.md / state / attestation / current.json[blocked=false] を走査）。
  - `autodev/scripts/check_system_completion.sh`: S12 完了宣言の事前ゲート9項目
    （features 全 done / attestation 揃い / persona_test_plan 全 completed / UI 層タスク存在 /
    顧客向けドキュメント3種 / S10 スモーク証跡 / 言い訳語ゲート PASS 等）。
  - `autodev/scripts/set_current.sh`: mode を空にする操作（完了宣言）の前に
    check_system_completion.sh PASS を必須化（緊急時 `AUTODEV_FORCE_COMPLETE=1` でバイパス可）。
  - PostToolUse(Edit|Write) hook: 進捗.md/state 編集時に言い訳語を warn 検出、
    「✅ システム完了」書き込み時に完了ゲートを即時実行。
  - skills 補強: autodev-system-loop / autodev-feature-loop / autodev-persona-test に
    省略禁止の不変条件と完了条件の機械ゲート化を明文化。
  - UI 必須機能の構造化: `system.json::features[].ui_required` (既定 true)、
    `tasks/<feature>.json::tasks[].layer` ("ui"/"viewmodel"/"domain"/"data"/"test") を導入。

