# 共通基盤_AudioManager（BGM / SE / Voice 再生統合）

## 機能概要

VoiceBOX で生成された各キャラのボイス、BGM、SE をアプリ内で管理・再生する共通基盤（要件 §機能: キャラクターボイス・BGM・SE 再生）。

- BGM: `MediaPlayer` 1〜2 個（クロスフェード対応）
- SE: `SoundPool`（同時多発前提）
- Voice: `MediaPlayer`（前のボイスを即停止して新規再生）
- AudioFocus 喪失（通話着信等）→ 復帰時に **BGM のみ再開**（SE/Voice はスキップ。要件のとおり）
- 設定 ON/OFF・音量は `SettingsRepository.observe()` を `collectLatest` で受けて即時反映

## 画面要素

なし（全画面から共通サービスとして呼び出される）。

## ユーザー操作

なし（プレイ操作・連鎖イベント・画面遷移 等からトリガされる）。

## エラーケース

- ファイル欠落: `assets.open()` 失敗時は再生をスキップし `AppLog::w` に警告のみ記録（要件のとおり）。
- AudioFocus 取得失敗: 取得できなければ再生しない（クラッシュさせない）。

## データモデル

```kotlin
sealed class AudioCue {
  data class Bgm(val sceneId: String) : AudioCue()
  data class Se(val eventId: String) : AudioCue()
  data class Voice(val characterId: String, val eventId: String) : AudioCue()
}
```

asset パス解決: `bgm/<sceneId>.ogg` / `se/<eventId>.ogg` / `voice/<characterId>/<eventId>.ogg`。

## 受け入れ条件

- Given: 設定でボイス ON / BGM ON / SE ON
- When: `AudioManager.play(AudioCue.Bgm("play_normal"))` 後に `AudioCue.Se("pop_small")` と `AudioCue.Voice("hina","chain_1")` を連続発火
- Then: BGM が継続再生されつつ SE とボイスがミックスされて出力される（logcat に `AudioLog` の再生ログが残る）。

## testTag 一覧

該当なし。
