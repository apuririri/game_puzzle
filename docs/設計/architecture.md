# アーキテクチャ概要

## ディレクトリ地図

```
app/src/main/java/com/example/myapp/
  MainActivity.kt        エントリポイント（NavHost を保持、testTagsAsResourceId 有効化）
  ui/
    screen/              画面 Composable（*Screen.kt。主要要素に testTag）
    component/           再利用 UI 部品
    navigation/          NavHost・ルート定義
    viewmodel/           ViewModel（StateFlow で UI 状態を保持）
    theme/               Material 3 テーマ
  data/
    local/               Room（AppDatabase / dao/ / entity/。exportSchema=true）
    repository/          リポジトリ（local/remote を抽象化）
    remote/              Retrofit interface・DTO（必要時）
  domain/
    model/               ドメインモデル
    usecase/             ユースケース
  settings/              DataStore（AppSettingsDataStore.kt。設定キーはここに集約）
  util/                  AppLogger.kt（統一タグ AppLog/ApiLog/DbLog/UiLog、APP_STARTED マーカー）
app/src/test/            JUnit 単体テスト
app/src/androidTest/     Compose UI Test（testTag 操作）
app/schemas/             Room exportSchema 出力（git tracked。migration の根拠）
maestro/                 Maestro E2E flow（smoke.yaml ほか。testTag 参照）
docs/設計/               設計書（実装から同期される地図）
```

## コンポーネント間の関係

```
画面(Compose) ── collectAsState ──▶ ViewModel(StateFlow) ── UseCase ──▶ Repository ──▶ Room(SQLite)
                                                                    └──▶ Retrofit ──▶ 外部 API（必要時）
設定: DataStore（settings/）
検証: エミュレータ/実機 ─ Compose UI Test・Maestro（testTag）─ ADB screenshot ─ logcat（統一タグ）
```

## 不変条件（変更してはならない前提 / 8.6）

1. 単一 dev 環境マスタ（並列ワーカー・複数 worktree・symlink ファームを使わない）。
2. 開発は直列のみ。
3. 機能・修正の完了には実機検証（エミュレータ/実機 + Compose UI Test / Maestro + ADB スクショ + logcat）が必須。Robolectric/プレビュー/mock 代替は禁止。
4. ツール本体は `autodev/` + `.claude/` に集約（リリース時に削除で分離）。
5. タスクは設計書セクションと紐付ける（`design_doc_ref` 必須）。
6. ペルソナ駆動テストを正式フェーズとして実施。
7. Gradle/ADB/Maestro 実行は必ずラッパースクリプト経由。
8. 主要UI要素に testTag 必須（`<画面>_<要素>_<種別>`）。ルートで `testTagsAsResourceId = true`。
9. 状態 JSON 更新と `autodev/開発進捗状況.md` を同期。
10. ハーネス遵守は hooks で機械強制、標準手順は skills で配信。

## 運用フェイズ（デプロイ）

- デプロイ先は開発者のスマートフォン（`adb install`）。ストア公開は対象外。
- release ビルドは独自 keystore で署名（`autodev/secrets/`）。APK は `autodev/artifacts/` に世代保管。
- スモークは起動マーカー（APP_STARTED）+ `maestro/smoke.yaml` + logcat クラッシュスキャン。
