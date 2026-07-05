# 画面遷移・testTag 一覧

> このファイルは実装（`app/.../ui/screen/` の Composable + `ui/navigation/` の NavHost）から同期される下流成果物です。
> 画面・testTag を追加したら必ずここを更新してください（テスト作成時の参照地図）。

## 画面一覧と Navigation ルート

| 画面 | Composable | ルート | 概要 |
|---|---|---|---|
| ホーム | HomeScreen | home | 起動直後の画面。サンプルメモ一覧 + 追加 |

## 画面遷移図

```
[起動] → home
```

## testTag 一覧（命名: <画面>_<要素>_<種別>）

| 画面 | testTag | 要素 |
|---|---|---|
| home | home_root | 画面ルート |
| home | home_memo_input | メモ入力欄 |
| home | home_add_button | 追加ボタン |
| home | home_memo_list | メモ一覧 |
| home | home_error_text | エラーメッセージ（エラー時のみ表示） |
