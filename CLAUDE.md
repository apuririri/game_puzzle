<!-- ルート CLAUDE.md: 最小ポインタ（FR-5.1.2）。本体規約は autodev/CLAUDE_MAIN.md。 -->

# AutoDev for Android — ルート規約（最小ポインタ）

このリポジトリは **AutoDev for Android**（Android アプリ自動開発ツール）で開発される。
AIエージェント（`claude --dangerously-skip-permissions`）は、起動したら必ず次を順に読み込むこと。

1. **`autodev/CLAUDE_MAIN.md`** — 本ツールの中核規約（起動プロトコル、ラッパー経由運用、進捗.md 同期、hooks / skills 一覧）。
2. **`autodev/開発進捗状況.md`** — 前回までの進捗（冪等再開のため最初に読む。FR-5.8.1）。
3. 各サブ規約: `app/CLAUDE.md`, `maestro/CLAUDE.md`。
4. 詳細仕様（FR-x.y / 付録X の出典）: **`autodev/docs/要件定義書.md`**（AutoDev 設計仕様 v5.0 Android版）。

## 絶対に守る不変条件（詳細は autodev/CLAUDE_MAIN.md）

- gradle / gradlew / adb / emulator / avdmanager / sdkmanager / maestro / apksigner は **必ず `autodev/scripts/` のラッパー経由**で実行する。素のコマンドは PreToolUse hook で fail する。
- 実機検証は **エミュレータ/実機 + Compose UI Test / Maestro + ADB スクショ + logcat** で行う。Robolectric / プレビュー / mock での代替は禁止。
- 開発は **直列**。並列化しない。
- 主要UI要素（ボタン・入力欄・リスト・画面ルート）には **必ず testTag を付与**し、座標タップ前提の実装・テストは書かない。
- 状態 JSON を更新したら **`autodev/開発進捗状況.md` を同期更新**する（PostToolUse hook が自動実行）。
- 本ツール本体は `autodev/` と `.claude/` に集約。リリース時はこの2つ＋本ファイルを削除する（付録I / `autodev/scripts/check_release_clean.sh`）。

> このファイルと `autodev/`・`.claude/` は顧客提供物ではない。リリース手順は `autodev/CLAUDE_MAIN.md` の「リリース」節を参照。
