---
name: autodev-system-loop
description: 起動プロンプト「要件定義書.mdのシステムを自動で開発してください」を受信したときに発動。要件定義書を入力に、ペルソナ定義・全体設計書作成・機能リスト補完・依存順ソートを経て、各機能設計書 先行作成＆要件カバレッジ確認（S6.5）、各機能ループとペルソナ駆動テストを直列実行し、全体結合確認・UIデザイン改善・全体スモーク・顧客向けドキュメント・リリース最終確認・完了報告まで（S1〜S15）を完結させる標準手順。
required_doc_version: "5.2"
---

<!-- version: 2.1 -->

# autodev-system-loop skill

## 適用条件

- 起動プロンプト「要件定義書.mdのシステムを自動で開発してください」（または意味的に等価な表現）を受信したとき。
- 入力: `autodev/inputs/要件定義/要件定義書.md`。

## 標準手順（S1〜S15 / 詳細は要件定義書 9.2）

1. **S1 要件整理**: 要件定義書を読み、未解決の不明点を整理。`autodev/state/loops/system.json` を生成。
2. **S2 機能リスト抽出**: 要件定義書から機能を抽出（不明確なら候補化）。
3. **S3 ペルソナ定義**: 3〜5体のペルソナを `autodev/state/personas/personas.json` に定義（[autodev-persona-test](../autodev-persona-test/SKILL.md) 参照）。**既存 `personas.json` がある場合は再生成せず、不足分のみ ID 末尾追加で差分追加する**（機能ループ F6.5 / 修正ループ R6.5 で生成された定義を上書きしないため。FR-5.9.1 改訂）。事前に `autodev/scripts/ensure_personas.sh` を実行し、exit 0 ならそのまま再利用、exit 2 なら新規定義 or 補充する。
4. **S4 全体設計書作成**: `docs/設計/全体設計書.md` を新規作成（機能間関係・画面遷移（Navigation ルート）・データフロー・Room データモデル・共通機能・共通スタイル・testTag 命名方針）。
5. **S5 機能リスト補完**: 全体設計書から共通機能・基盤機能（DB 基盤、設定画面、共通 UI 部品等）を抽出し機能リストへ追加（要件定義書に明示が無くても漏らさない）。
6. **S6 依存順ソート**: Room スキーマ/認証/画面/共通機能の依存を考慮して機能リストを並べ替え。
7. **S6.5 全機能設計書 先行作成＆要件カバレッジ確認**（[autodev-coverage-check](../autodev-coverage-check/SKILL.md) を `scope=system` で発動 / FR-5.21.1）:
    - `loop.yaml::coverage_check.enabled=false` のときはスキップ可（既定 true / 規約15 ホワイトリスト）。AI 判断による省略は禁止。
    - **設計のみ先行パス**: ソート済み機能リストを順に走査し、各機能の **F2 のみ**（`docs/設計/features/<機能名>.md` 新規作成）を直列実行。実装（F3 以降）はまだ走らせない。骨組み: `## 機能概要 / ## 画面要素 / ## ユーザー操作 / ## エラーケース / ## データモデル / ## 受け入れ条件 / ## testTag 一覧（placeholder / F2-in-S9 で確定）`。
    - **カバレッジ照合**: `autodev/scripts/check_requirement_design_coverage.sh --cycle <N>` で要件 ⇄ 設計のセクション網羅 + testTag 候補抽出を機械検査。
    - **ギャップ解消**: 未マッピング要件は既存設計書追記 or 新規機能を機能リストに追加（`system.json::features[]` を atomic 更新 / `ui_required` 設定）→ F2 再実行。
    - **再照合**: `passed=true` まで反復。上限 `loop.yaml::coverage_check.max_cycles`（既定 2）。超過時は `blocking_issues` に集約 → `blocked=true` で停止（S7 へ進まない / 規約12）。
    - 完了時に `state/attestations/coverage.json`（単一ファイル / 内部 cycles[] で履歴保持）を出力、`system.json::s6_5_result.coverage_attestation_ref` を更新。
8. **S7 ペルソナテスト計画**: 機能 N 個に対し floor(N/3)+1 回。`system.json` に計画記録。
9. **S8 state 記録**: 機能リスト・進捗・ペルソナテスト計画を `system.json` に確定。
10. **S9 機能ループ実行**: 各機能で [autodev-feature-loop](../autodev-feature-loop/SKILL.md) を発動。**機能ループ内では F5.5 + F6.5 が必ず走り、各機能完了前に トレーサビリティ照合（FR-5.21.2）と `scope=feature:<機能名>` のペルソナテスト（FR-5.9.8）を実施する**（既定で有効）。それと並行して、S7 で立てた計画に従い 3機能完了ごとに `scope=system` の [autodev-persona-test](../autodev-persona-test/SKILL.md) を実施し（FR-5.9.2）、改善要望を [autodev-fix-loop](../autodev-fix-loop/SKILL.md) で対応。全機能完了後に最終ペルソナテストを実施。F6.5（機能単体観点）と S7/S9 ペルソナテスト（機能横断・統合観点）は目的が異なるため重複ではない。**いずれのフェーズも省略は規約15 違反。実施不能なら blocked=true で停止する。**
11. **S10 全体結合確認・改善**: [autodev-integration-verify](../autodev-integration-verify/SKILL.md) を発動。
    - IV1: `autodev/scripts/check_no_mocks.sh` でモック/スタブ/TODO 残存を機械検出。
    - IV2: 検出箇所ごとに `autodev/inputs/修正対応/修正_デモック_<モジュール>.md` を生成 → fix-loop で実プログラム化。
    - IV3: `autodev/scripts/run_integration_check.sh` で HEADFUL 全機能 + 機能横断シナリオを実機検証（リリース後の挙動を想定）。
    - IV4: 各ペルソナの利用目的視点で実機ロールプレイ評価し改善要望を `修正_統合_<項目>.md` として生成。
    - IV5: 改善要望 fix-loop → IV3 再走（fail 0 まで、`max_integration_cycles` 超過で blocked）。
    - IV6: `autodev/state/attestations/integration.json` を出力。
12. **S11 UIデザイン改善**: [autodev-ui-polish](../autodev-ui-polish/SKILL.md) を発動。
    - UP1: `autodev/scripts/list_screens.sh` で全 NavHost ルートを `autodev/state/ui_polish/inventory.json` に列挙。
    - UP2: `autodev/scripts/capture_all_screens.sh` で全画面 before スクショを HEADFUL で取得。動的状態（loading / empty / error）も `maestro/_polish/_state_<screen>.yaml` で発火させ撮影。
    - UP3: `autodev/config/ui_polish.yaml::criteria[]` の評価軸（視認性 / レイアウト / 一貫性 / 操作性 / 動的状態 / Material 3 / 余白 / アクセシビリティ）で改善案を `autodev/state/ui_polish/<screen>.json::issues[]` に列挙。
    - UP4: 改善案を `修正_UI_<screen>_<項目>.md` として生成。共通スタイル変更は全体設計書 §共通スタイル への反映指示を含める。
    - UP5: fix-loop で順次対応（実機検証必須）。
    - UP6: `capture_all_screens.sh --after` で after スクショと差分を出力。
    - UP7: `autodev/state/attestations/ui_polish.json` を出力（`check_ui_polish_evidence.sh` PASS が前提）。
13. **S12 全体スモーク**: アプリを一度 `autodev/scripts/uninstall.sh` でクリーンアンインストールした上で `autodev/scripts/run_full_tests.sh`（単体全部 + Compose UI Test 全部 + maestro/ 全 flow）。logcat クラッシュスキャンを含む。証跡は `autodev/evidence/_smoke/` に保存し、`autodev/state/attestations/system.json::smoke_evidence` に記録する。
14. **S13 顧客向けドキュメント整備**: `README.md`・`docs/操作手順書.md`・`docs/インストール手順.md`（実機への adb install 手順）を整備。
15. **S14 デプロイ・リリース最終確認**: [autodev-release-gate](../autodev-release-gate/SKILL.md) を発動。
    - RG1: `autodev/scripts/check_release_ready.sh` で 11 種の静的ゲート群を一括実行（release_clean / no_mocks / design_sync / room_schema / dead_assets / testtag_coverage / no_debug_artifacts / manifest_release / release_build / release_strings / dependencies）。
    - RG2: `autodev/scripts/run_release_smoke.sh` で署名済み release APK を実機（または HEADFUL emulator）にクリーンインストールし smoke + 全 maestro flow + logcat クラッシュスキャン。
    - RG3: fail を `修正_リリース_<項目>.md` として fix-loop に渡し、全 PASS まで反復（`max_release_cycles` 超過で blocked）。
    - RG4: `autodev/state/attestations/release.json` に「即リリース可」判定を出力（APK パス / 署名情報 / チェックリスト / 証跡）。
    - RG5: 進捗.md に「emulator から device へデプロイしてください で即実行可能」を明示。実 deploy は [autodev-deploy](../autodev-deploy/SKILL.md) に委譲（規約7 例外で要承認）。
16. **S15 完了報告（完了宣言の絶対前提あり）**:
    1. **必須前ゲート**: `autodev/scripts/check_system_completion.sh` を実行し PASS を確認する。PASS しない限り、進捗.md に「✅ システム完了」と書いてはならず、`set_current.sh "" ... false ""` で mode を空にすることもできない（set_current.sh が機械的に拒否する）。同スクリプトは **S6.5 coverage attestation + 全機能/修正 attestation の `traceability_passed`** + S10 / S11 / S14 の 3 attestation の存在も検査する。
    2. 全機能 + attestation パス、ペルソナテスト履歴、統合確認 / UI 改善 / リリース判定 attestation のパス、S12 スモーク結果、リリース APK パス（autodev/artifacts/）、顧客向けドキュメントパスを報告。
    3. `set_current.sh "" "" "" "" "" false ""` で完了状態に遷移し、進捗.md を「✅ システム完了」に再生成する。

各ステップで state を更新するたび、PostToolUse hook が `autodev/開発進捗状況.md` を再生成する。

## フェーズ省略・スコープ縮小の禁止（CLAUDE_MAIN.md 規約12〜15）

- **S1〜S15 のいずれのステップも、AI が自己判断で省略・後回し・打ち切ることを禁止する**。S10〜S11・S14 の3 新フェーズも同様。
- 「時間制約」「コンテキスト圧迫」「スコープ調整」「後続作業として」「将来対応」「次セッションで」「TODO として残す」等を理由としたスキップは **すべて規約違反**である。
- 実施が不可能な場合の正規ルート:
  1. `set_current.sh <mode> <target> <phase> <task> <step> true "<理由>"` で `blocked=true` の人手介入待ち停止にする（phase 例: `S10_integration` / `S11_ui_polish` / `S14_release_gate`）。
  2. 追加で対応が必要な改善・派生作業は `autodev/inputs/修正対応/修正_<理由>.md` を生成し修正ループに渡す。
- 「✅ システム完了」「完了報告」を進捗.md / attestation / state に書き込んでよいのは、`check_system_completion.sh` が PASS した後だけ。
- 言い訳語の混入は `check_no_skip_excuses.sh` が機械検出し、PostToolUse hook が即時警告する。

## 完了条件

- S1〜S15 全完了 / **S6.5 coverage attestation 出力済み（passed=true）** / 全体スモーク (S12) PASS / 顧客向けドキュメント整備済み / 最終ペルソナテスト完了 / **S10 統合確認 attestation 出力済み** / **S11 UI 改善 attestation 出力済み** / **S14 リリース判定 attestation 出力済み** / **全機能/修正 attestation の `traceability_passed=true`** / `check_system_completion.sh` PASS。
- 上記のいずれかが満たされない状態でシステム完了を宣言してはならない。

## 失敗時の挙動

- 進捗ゼロが既定時間（`autodev/config/loop.yaml` の `no_progress_timeout_min`）継続したら停止し報告（FR-5.8.2）。
- 環境破損は修復試行上限まで自動修復（`bash setup.sh` は冪等）、超過で停止（FR-5.8.3）。
- 上記以外の事情（時間・スコープ・トークン）でフェーズを省略してはならない。停止が必要なら必ず `blocked=true` で人手介入待ちにする。

## 関連参照

- [autodev-feature-loop](../autodev-feature-loop/SKILL.md) / [autodev-fix-loop](../autodev-fix-loop/SKILL.md) / [autodev-persona-test](../autodev-persona-test/SKILL.md)
- [autodev-coverage-check](../autodev-coverage-check/SKILL.md)（S6.5 から発動）
- [autodev-integration-verify](../autodev-integration-verify/SKILL.md) / [autodev-ui-polish](../autodev-ui-polish/SKILL.md) / [autodev-release-gate](../autodev-release-gate/SKILL.md) / [autodev-deploy](../autodev-deploy/SKILL.md)
- 詳細仕様: 要件定義書 9.2 / 9.6 / FR-5.2 / FR-5.10 / FR-5.17 / FR-5.18 / FR-5.19 / FR-5.21
