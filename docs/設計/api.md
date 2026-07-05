# API 仕様概要（外部 API 連携）

> このファイルは実装（`app/.../data/remote/` の Retrofit interface）から同期される下流成果物です。
> 変更時は `autodev-design-sync` skill に従い、`autodev/scripts/check_design_sync.sh` で乖離を確認してください。

## エンドポイント一覧

（雛形時点では外部 API 連携は未定義。機能開発で `data/remote/` に Retrofit interface が追加され、ここに反映される。）

| メソッド | パス | 概要 |
|---|---|---|
| (なし) | - | - |

## 共通仕様

- HTTP クライアント: Retrofit + OkHttp。
- ベース URL は DataStore（`api_server_url`）または BuildConfig から実行時解決（ハードコードしない）。
- 単体テストは MockWebServer を使用可。実機検証を mock で代替することは禁止。
