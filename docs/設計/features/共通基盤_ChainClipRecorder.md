# 共通基盤_ChainClipRecorder（5連鎖以上で mp4 自動保存）

## 機能概要

5 連鎖以上のイベントを ChainEngine 経由で検知したとき、その演出区間（直前 1 秒〜演出終了の最大 10 秒）を mp4 として
`MediaStore.Video` に自動保存する。要件 §機能: 大連鎖クリップ自動保存 を実装する。

## 画面要素

- 保存完了時の `chain_clip_saved_toast`（呼び出し側 EndlessScreen 等で Snackbar/Toast）

## ユーザー操作

なし（自動）。ただし設定画面の `settings_chain_clip_toggle` で ON/OFF。

## エラーケース

- ストレージ容量不足: 警告 Toast 表示しキャプチャを中止（プレイ自体は継続）
- 端末性能不足: 保存を断念し AppLog::w 警告ログ
- 権限拒否（Android 9 以下の WRITE_EXTERNAL_STORAGE 等）: 設定で OFF にする旨を Toast で案内
- MediaCodec encode 失敗: 例外を catch、当該クリップを破棄、AppLog::e に記録

## データモデル

```kotlin
class ChainClipRecorder(context: Context, settingsRepo: SettingsRepository) {
  suspend fun startCaptureIfBigChain(event: ChainEvent, surface: Surface)
  // 内部で MediaCodec H.264 + MediaMuxer。最長 10s。
}
```

`MediaStore.Video.Media` への INSERT（API 29+ は scoped storage、それ以下は WRITE_EXTERNAL_STORAGE 要求）。

## 受け入れ条件

- Given: `settings.chainClip.enabled = true`
- When: ChainEngine が `ChainEvent(level=5)` 以上を発火し、対応する surface フレームが供給される
- Then: ギャラリーに mp4 ファイル `美少女連鎖パズル_<timestamp>.mp4` が保存され、`chain_clip_saved_toast` が表示される（Maestro で MediaStore クエリと Toast 表示を検証）。

## testTag 一覧

| testTag | 要素 |
|---|---|
| `chain_clip_saved_toast` | 保存完了 Toast/Snackbar（プレイ画面右上） |
