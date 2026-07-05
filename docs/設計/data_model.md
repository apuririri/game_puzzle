# データモデル（Room スキーマ + DataStore キー概要）

> このファイルは実装（`app/.../data/local/` の @Entity/@Dao + `app/schemas/` の exportSchema 出力、
> および `app/.../settings/` の DataStore キー）から同期される下流成果物です。
> 変更時は `autodev-design-sync` skill に従い、`autodev/scripts/check_design_sync.sh` で乖離を確認してください。

## Room テーブル一覧

（雛形時点のサンプル。機能開発で `data/local/entity/` に追加される。）

| テーブル | Entity | 用途 | 主なカラム |
|---|---|---|---|
| memos | MemoEntity | 動作確認用サンプルメモ | id, title, body, createdAt |

## マイグレーション

- `exportSchema = true`。schema JSON は `app/schemas/<DB名>/` に git tracked。
- schema バージョンを上げたら Migration 定義 + MigrationTest（androidTest）必須（`check_room_schema.sh` が検査）。

## DataStore キー一覧（settings/AppSettingsDataStore.kt）

| キー | 型 | 用途 |
|---|---|---|
| api_server_url | String | API サーバー URL（必要時） |
| last_screen | String | 最後に開いた画面ルート |
