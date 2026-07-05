# 共通基盤_ScreenCapture（スクリーンショット取得 + OS シェアシート）

## 機能概要

リザルト画面・プレイ画面の一時停止メニュー等から呼び出され、現在の View をビットマップ化して FileProvider 経由で
`ACTION_SEND` を投げる。専用バックエンドは持たない（要件 §機能: スクリーンショット共有）。

## 画面要素

なし（共通機能。「シェア」ボタンを持つ画面側に testTag を置く）。

## ユーザー操作

なし（呼び出し側 ResultScreen / PlayScreen から起動）。

## エラーケース

- View が描画途中: `Choreographer.postFrameCallback` を 1 フレーム待ってから再試行（最大 3 回）。失敗時は再試行案内 Toast。
- 共有先アプリ未インストール: OS シェアシートの標準挙動に委ねる。

## データモデル

```kotlin
class ScreenCapture(context: Context) {
  suspend fun captureAndShare(view: View, title: String): Result<Unit>
}
```

`FileProvider.getUriForFile()` を使い `context.cacheDir/shared_screenshots/<timestamp>.png` を作成 → `Intent.createChooser` を起動。

## 受け入れ条件

- Given: ResultScreen 表示中
- When: ScreenCapture.captureAndShare(view, "美少女連鎖パズル") を呼び出す
- Then: cacheDir に PNG が作成され、ACTION_SEND の Intent が `Intent.createChooser` で起動する（Compose UI Test では Intents.intended で検証）。

## testTag 一覧

該当なし（呼び出し側に `share_button` を持たせる責務）。
