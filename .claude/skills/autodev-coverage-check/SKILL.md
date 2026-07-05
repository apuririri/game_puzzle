---
name: autodev-coverage-check
description: 要件↔設計↔タスク↔実装の紐付け漏れを機械検査する標準手順。システムループ S6.5（全機能設計書 先行作成＆要件カバレッジ確認）、機能ループ F5.5（要件⇄設計⇄実装トレーサビリティ照合）、修正ループ R5.5（修正対応書の要件⇄影響範囲⇄実装照合）の3スコープで発動。Android 固有の layer × カテゴリ マッピング・testTag 候補 grep・Room Entity ファイル確認・Maestro flow / Compose UI Test 紐付け確認を行い、ギャップ検出時は設計書追記または追加タスク生成でループへ戻し、PASS まで反復する。
required_doc_version: "5.2"
---

<!-- version: 1.0 -->

# autodev-coverage-check skill

## 適用条件

本 skill は次の3スコープで発動する。スコープに応じて検査対象と発動契機が変わる。

| scope | 発動契機 | 検査対象 | 失敗時の対応 |
|---|---|---|---|
| `system` | システムループ S6.5（依存順ソート S6 と ペルソナテスト計画 S7 の間）。`loop.yaml::coverage_check.enabled=true`（既定）で発動。FR-5.21.1。 | 要件定義書 / 機能要件書 ⇄ 全体設計書 + 機能別設計書（testTag 候補含む） | 機能別設計書を新規作成 or 既存設計書に追記 → 必要なら機能リストへ新規機能追加 → 再走査 |
| `feature:<機能名>` | 機能ループ F5.5（F5 全体レビュー後・F6 実機検証前）。`loop.yaml::feature_loop.traceability_enabled=true`（既定）で発動。FR-5.21.2。 | 機能要件書 ⇄ `docs/設計/features/<機能名>.md` ⇄ `tasks/<機能名>.json`（layer 含む）⇄ 変更ファイル（Compose / ViewModel / UseCase / Room Entity / Maestro / androidTest） | 追加タスクを `tasks/<機能名>.json` に push（`source: "traceability_gap"` / `layer` 必須）→ F4 イテレーションループへ戻る |
| `fix:<修正名>` | 修正ループ R5.5（R5 イテレーション後・R6 実機検証前）。`loop.yaml::fix_loop.traceability_enabled=true`（既定）で発動。FR-5.21.3。 | 修正対応書 ⇄ R2 の `impact_analysis` ⇄ 関連設計書 ⇄ `tasks/<修正名>.json` ⇄ 変更ファイル | 追加タスクを push → R5 イテレーションループへ戻る |

**規約15 ホワイトリスト**: `coverage_check.enabled=false` / `feature_loop.traceability_enabled=false` / `fix_loop.traceability_enabled=false` は **明示的な OFF**（段階導入用）であり、AI 判断による省略とは区別される。`check_no_skip_excuses.sh` は本フラグ由来のスキップを許容する。

## 標準手順

### scope=system（S6.5）

1. **設計のみ先行パス**:
   - `autodev/state/loops/system.json::features[]` の依存順ソート済みリストを順に走査。
   - 各機能について、**F2 のみを直列実行**して `docs/設計/features/<機能名>.md` を新規作成または既存読込（実装 F3 以降は実行しない）。
   - 雛形は全体設計書から該当セクションを引用し、機能要件書（または要件定義書内の該当セクション）の要素を反映。FR-5.4.1 既存例外（事前作成許容）に従う。
   - 必須骨組み: `## 機能概要 / ## 画面要素 / ## ユーザー操作 / ## エラーケース / ## データモデル / ## 受け入れ条件 / ## testTag 一覧（placeholder。F2-in-S9 で確定）`。

2. **カバレッジ照合**:
   - `autodev/scripts/check_requirement_design_coverage.sh --cycle <N>` を実行。
   - 出力 `autodev/state/attestations/coverage.json`（**Android 単一ファイル方式** / 内部 `cycles[]` で履歴保持）を確認:
     - `uncovered_features`（設計未マッピングの要件機能）
     - `missing_subsections`（設計書に欠落する画面要素 / ユーザー操作 / 受け入れ条件）
     - `missing_testtag_candidates`（要件書に testTag 候補があるが設計書に `## testTag 一覧` 欠落）
     - `unreferenced_designs`（要件側に存在しない設計書 = レビュー対象）

3. **ギャップ解消**:
   - **未カバー要件**: 既存機能設計書に追記して吸収できる場合は当該設計書を更新。吸収できない場合は新規機能として `docs/設計/features/<新機能名>.md` を作成し、`system.json::features[]` にも atomic に追加（依存順は再ソート / `ui_required` フィールドを適切に設定 / DB 基盤など UI なし機能は `ui_required: false`）。
   - **欠落サブセクション**: 該当機能設計書に「## 画面要素 / ## ユーザー操作 / ## 受け入れ条件」等を補完。
   - **testTag 候補欠落**: 設計書に `## testTag 一覧` セクションを追加し、要件書の候補（例: `login_email_input`）を一覧化する placeholder を配置。
   - **未参照設計書（WARN）**: AI が「要件不足 or 設計過剰」を判定。要件不足なら要件定義書に追記要否を最小質問、設計過剰なら設計書を削除 or マージ。

4. **再照合**:
   - 修正後、再度 `check_requirement_design_coverage.sh --cycle <N+1>` を実行し、`passed=true` となるまで反復。
   - 上限: `loop.yaml::coverage_check.max_cycles`（既定 2）。超過時は `blocking_issues` に集約 → `blocked=true` で停止（S7 へ進まない / 規約12 準拠）。

5. **完了記録**:
   - `system.json::s6_5_result` に `coverage_attestation_ref: autodev/state/attestations/coverage.json` と `passed: true` を記録。
   - PostToolUse hook が `autodev/開発進捗状況.md` を再生成。
   - S7（ペルソナテスト計画）へ進む。

### scope=feature:<機能名>（F5.5）

1. **照合**:
   - `autodev/scripts/check_traceability.sh <機能名> --scope feature --cycle <N>` を実行。
   - 出力 `autodev/state/traceability/<機能名>.json` を確認:
     - `items[]` の各要件項目について `expected_layers` / `design_section` / `task_ids` / `task_layers` / `layer_match` / `implementation_evidence` / `testtag_candidates` / `testtag_hits` / `covered` を点検。
     - `items_with_gap > 0` ならギャップあり。

2. **layer × カテゴリ マッピング（Android 固有 / FR-5.21.2.3）**:

   | 要件カテゴリ | expected_layers | extra_check |
   |---|---|---|
   | 画面要素 | `[ui]` | testTag 候補 → `app/src/main/.../ui/` で `Modifier.testTag("候補")` grep |
   | ユーザー操作 | `[ui, viewmodel]` | - |
   | エラーケース | `[ui, viewmodel, domain]` | - |
   | データモデル | `[data]` | 大文字始まり token → `app/src/main/.../data/` で `class\|object\|@Entity Token` grep |
   | 受け入れ条件 | `[test]` | `maestro/*.yaml` または `app/src/androidTest/*Test.kt` に対象名/testTag 参照あり |
   | API | `[data, domain]` | - |
   | 影響範囲（scope=fix 主眼） | `[]`（layer 不問） | ファイルパス/ファイル名 token を `app/src/` と `maestro/` で grep |

   タスクの `layer` が `expected_layers` のいずれかにマッチすれば `layer_match=true`。`expected_layers=[]` の場合は layer 検査スキップ（影響範囲・ui_required=false 機能の UI カテゴリなど）。

3. **ui_required: false の例外**:
   - `system.json::features[<機能名>].ui_required == false` のとき、`extract_requirement_items` が **「画面要素」「ユーザー操作」カテゴリを抽出対象から除外**する（DB 基盤など UI なし機能の正常パターン / FR-5.21.2.4）。要件書にこれらの項目が記載されていても items[] に含まれず、誤ギャップを生まない。

4. **入力ファイル選択の優先順位**:
   - `scope=feature`: 機能要件書（`autodev/inputs/要件定義/機能要件_<機能名>.md`）を優先。無ければ要件定義書（`autodev/inputs/要件定義/要件定義書.md`）をフォールバック。**ただし要件定義書を渡す場合は文書全体の「画面要素」セクション等が混在抽出されるため、AI は当該機能名のセクション範囲のみを検査対象とみなす**（複数機能の要件項目混在に注意）。
   - `scope=fix`: 修正対応書（`autodev/inputs/修正対応/修正_<修正名>.md`）。修正対応書には「## 4. 影響範囲」「## 5. 受け入れ条件」セクションがある想定。

5. **AI 判定（grep ベース検査の補完）**:
   - スクリプトは英数字トークン・testTag・Entity 名・ファイル名の grep で判定するため、日本語のみの要件項目は false-negative になりうる。
   - AI は出力 JSON を読み、`covered=false` の項目について実装の実体（Compose Composable / ViewModel / UseCase / Repository / Room Entity / Maestro flow / Compose UI Test）を直接確認。
   - false-negative なら `items[].covered_by_ai=true` を立て、**根拠を `items[].ai_reason` に必ず記述する**（実体確認した実装ファイル名・関数名・grep が false-negative になった原因など。空文字列禁止 / 言い訳語禁止 / NFR-6.3.1 + 規約14）。
   - **承継仕様**: 次サイクルで `check_traceability.sh` を再実行すると、既存 JSON の `covered_by_ai` / `ai_reason` を `(category, item)` 一致で自動承継する。AI が一度付けた判定は維持されるため、追加タスクの実装完了後に再走査しても PASS は失われない。
   - 真のギャップなら次手順。

6. **追加タスク生成**:
   - 真のギャップごとに `tasks/<機能名>.json::tasks[]` に追加タスクを push。各タスクは下記を必須とする:
     - `id`: 既存 max + 1
     - `title`: ギャップ要件項目を1文で記述
     - `design_doc_ref`: `{ "file": "docs/設計/features/<機能名>.md", "section": "<対応セクション>" }`（規約5）
     - `layer`: 期待 layer 集合のいずれか（規約10 関連 / Android 必須）
     - `source`: `"traceability_gap"`
     - `cycle`: 検出された `cycle` 値
     - `status`: `"pending"`

7. **F4 イテレーションループへ戻る**:
   - 追加タスクを直列消化 → F5 全体レビュー → F5.5 再走査。
   - 上限: `loop.yaml::feature_loop.traceability_max_cycles`（既定 2）。超過時は残ギャップを `blocking_issues` に集約 → `blocked=true` で停止（F6 へ進まない / 規約12）。

8. **F6 / F7 への引き渡し**:
   - PASS したら `state/loops/<機能名>.json::f5_5_result` に `traceability_ref: <パス>` と `passed: true` を記録。
   - F6 機能実機検証へ進む。
   - F7 クローズゲートで `check_traceability.sh <機能名> --scope feature --gate` を再実行（最新の `tasks/<機能名>.json` を反映した最終確認）。

### scope=fix:<修正名>（R5.5）

1. **照合**:
   - `autodev/scripts/check_traceability.sh <修正名> --scope fix --cycle <N>` を実行。
   - 検査対象は修正対応書のセクション（受け入れ条件 / 影響範囲）、R2 で記録された `impact_analysis`（`files / screens / room_entities / dao / apis / permissions`）、`tasks/<修正名>.json`、変更ファイル。
   - `state/loops/<修正名>.json::impact_analysis` の各要素がタスク化＋実装されているかも検査する（AI 判定で補完）。

2. **AI 判定 / 追加タスク生成**: feature と同じ手順・同じ layer マッピングで実施。`source: "traceability_gap"` で push。

3. **R5 イテレーションループへ戻る**:
   - 上限: `loop.yaml::fix_loop.traceability_max_cycles`（既定 2）。超過時は `blocking_issues` 集約・`blocked=true` 停止（R6 へ進まない / 規約12）。

4. **R6 / R7 への引き渡し**: feature と同様、R7 クローズゲートで再走査する。

## 既存ゲートとの責務分離

| ゲートスクリプト | 検査範囲 |
|---|---|
| `check_task_design_link.sh`（既存） | タスク↔設計書セクション網羅（F3 / R4 時点） |
| `check_design_sync.sh`（既存） | 設計書↔実装 staleness（API / Room schema） |
| `check_room_schema.sh`（既存） | Room schema export + Migration テスト |
| `check_testtag_coverage.sh`（既存） | 主要 UI 要素への testTag 付与網羅 |
| `check_requirement_design_coverage.sh`（新規） | 要件書↔設計書（機能セクション網羅 + 必須サブセクション + testTag 候補 / システム単位） |
| `check_traceability.sh`（新規） | 要件↔設計↔タスク↔実装ファイル の4層連鎖（layer マッピング + Android 固有 extra_check / 機能・修正単位） |

これらは重ならず補完関係になる。

## 完了条件

- 出力 JSON の `passed=true`（または AI 判定で `covered_by_ai=true` 補完後の最終 `passed=true`）。
- スコープ別の呼び出し元 state に `coverage_attestation_ref` / `traceability_ref` が記録されている。
- 追加タスクが生成された場合は全タスクが `status=done` まで消化されている。
- 進捗.md が PostToolUse hook により再生成済み。

## 失敗時の挙動

- 上限 cycles 到達: 残ギャップを `blocking_issues` に集約し、呼び出し元ループ（system / feature / fix）の state に `blocked=true` で停止記録。
- スクリプト exit 2（jq 不在・引数不正）: ハーネス障害として停止し、`HARNESS_NOTES.md` に記録。
- スクリプト exit 0 だが AI が false-negative を多数発見した場合: `items[].covered_by_ai=true` + `items[].ai_reason="<根拠>"` を AI が JSON に書き込み、次サイクルでスクリプトが承継して `passed=true` となる。`items_with_ai_pass` が肥大化する場合は、grep ベース判定の token 抽出ロジックを改善すべきシグナルとして `HARNESS_NOTES.md` に記録。

## ループ無限化の防止

- `traceability_gap` 由来の追加タスクからは新たな `traceability_gap` を派生させない（AI は同 source タグのタスクに対して F5.5/R5.5 のギャップ判定を抑制する）。
- `coverage_check.max_cycles` / `feature_loop.traceability_max_cycles` / `fix_loop.traceability_max_cycles` を全て小さく設定（既定 2）。
- 上限超過時は必ず `blocked=true` で停止（規約12 準拠）。

## 関連参照

- [autodev-system-loop](../autodev-system-loop/SKILL.md)（S6.5 から発動）
- [autodev-feature-loop](../autodev-feature-loop/SKILL.md)（F5.5 から発動）
- [autodev-fix-loop](../autodev-fix-loop/SKILL.md)（R5.5 から発動）
- [autodev-design-sync](../autodev-design-sync/SKILL.md)（設計書同期）
- スクリプト: `check_requirement_design_coverage.sh` / `check_traceability.sh`
- 詳細仕様: 要件定義書 FR-5.21 / 9.2(S6.5) / 9.3(F5.5) / 9.4(R5.5) / 付録B.12 / B.13
