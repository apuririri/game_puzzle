---
name: autodev-resume
description: 「作業を再開して」「続きから」等の再開指示を受けたとき、または中断後の再起動時に発動。autodev/state/current.json と 開発進捗状況.md から直前の作業位置を復元し、ヘルスチェックと直前手順の ground-truth 再検証を行った上で、進行中のループ/タスクを記録位置から確実に継続する標準手順。
required_doc_version: "5.2"
---

<!-- version: 1.0 -->

# autodev-resume skill

## 適用条件

- 「作業を再開して」「続きから」「再開」等の指示を受けたとき。
- セッション中断・スリープ後の再起動（watchdog による自動再プロンプト含む）。

## 標準手順（R0）

1. **状況把握**：`autodev/開発進捗状況.md` と `autodev/scripts/check_resume_point.sh`（`current.json` を読む）で、mode / target / loop_phase / current_task_id / last_step / blocked を確認。
2. **blocked 判定**：`blocked=true` なら人手要因（質問・承認・環境）を提示し、解消するまで自動継続しない。
3. **環境健全性**：`autodev/scripts/healthcheck.sh` を実行（JDK/SDK / Gradle / デバイス（エミュレータ自動起動）/ アプリ起動マーカー / Maestro）。fail なら修復（`bash setup.sh` は冪等 / FR-5.8.3）。
4. **直前手順の ground-truth 再検証（案1 / FR-5.8.1）**：`current.json` の `last_step` を **done と鵜呑みにせず**、以下を順に実行する。`verify_resume_point.sh` がこの一連を実行する単一エントリポイント。
   - 4a. `autodev/scripts/check_state_consistency.sh` で state ファイル間の drift を検知（system.json / loops / attestations / persona_tests の整合）。
   - 4b. `last_step` 種別に応じた追加検証:
     - `*test*` / `*maestro*` / `*device*` / `*verify*` → attestation の `evidence.screenshots` パス実在を確認
     - `*commit*` / `*close*` / `*attestation*` → attestation の `gates[]` が全 `ok` であることを確認
   - 4c. `autodev/scripts/check_progress_md_sync.sh` で進捗.md と state mtime の同期確認。
   - 4d. 結果を `state/resume_verifications/<ts>.json` に永続化（passed/failed 内訳）。
   - **FAIL のとき**: 直前の安全なチェックポイント（最新コミット `git log -1`）まで巻き戻して再開、または `set_current.sh ... true "<理由>"` で blocked=true を立てて人手判断待ちにする。
5. **継続**：mode に対応するループ skill（autodev-system-loop / feature-loop / fix-loop / persona-test / deploy / cleanup）を、記録された loop_phase / task から再開。
6. **現在地更新**：各手順の冒頭で `autodev/scripts/set_current.sh <mode> <target> <phase> <task> "<step>"` を呼び、`current.json` を最新化（次回再開のため）。

## current.json 運用契約（watchdog の誤再開防止のため必須）

- **人手待ちで停止するとき**（質問・承認・環境破損など）は、必ず `set_current.sh <mode> <target> <phase> <task> "<step>" true "<理由>"` で **blocked=true** を立てる。watchdog はこれを見て再開しない。
- **作業が完全に完了したとき**は `set_current.sh "" "" "" "" ""`（mode を空に）で現在地をクリアする。watchdog は mode 空を「作業なし」とみなし再開しない。

## 完了条件

- `current.json` の位置からループ/タスクが継続され、進捗.md が最新化されている。
- blocked の場合は要因が提示され、ユーザー対応待ちで停止している。

## 失敗時の挙動

- current.json が無い/壊れている → 進捗.md と loops/system.json から推定して再開（check_resume_point.sh のフォールバック）。
- healthcheck 修復不能 → 人手介入待ちで停止。

## 関連参照

- スクリプト: `set_current.sh` / `check_resume_point.sh` / `healthcheck.sh`
- 無人自動再開: `autodev/scripts/watchdog.sh`（heartbeat 停止検知→同一セッションに本 skill を再プロンプト）
- 各ループ skill / 詳細仕様: 要件定義書 FR-5.8.1（冪等再開）
