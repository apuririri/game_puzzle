# 共通基盤_ChainEffectRenderer

## 機能概要

ChainEngine が発火した `ChainEvent` に応じて、画面全体に派手な演出を描画する Composable 層。
要件 §機能: 連鎖演出システム の演出要素を全て実装する。

## 画面要素

オーバーレイ Composable として呼び出し画面（プレイ画面）に重ねる。

- `chain_particle_layer`（消去ぷよ拡大 + パーティクル）
- `chain_count_overlay`（連鎖数ズーム表示）
- `chain_screen_shake`（画面シェイク）
- `chain_background_flash`（背景フラッシュ／カラーグラデ）
- `chain_character_overlay`（キャラ立ち絵差し替え: 通常 → 連鎖中 → 大連鎖）
- `chain_bgm_intensify`（5 連鎖以上で BGM 高揚スイッチ。AudioManager 経由）

## ユーザー操作

なし（連鎖イベントで自動発火）。

## エラーケース

- 端末性能不足でフレームレート < 30fps: パーティクル数を `ChainEffectConfig.particleCount` で動的削減（fallback ではなく仕様）。
- BGM スイッチ中に連鎖終了: 元の BGM パートにフェードバック（要件のとおり）。

## データモデル

```kotlin
data class ChainEffectConfig(val particleCount: Int = 80, val shakeStrengthDp: Float = 8f)
@Composable
fun ChainEffectOverlay(events: Flow<ChainEvent>, characterId: String, modifier: Modifier = Modifier)
```

連鎖 level に応じて段階的に派手さが増す（パーティクル数・シェイク強度・カラーフラッシュ alpha を level でスケール）。

## 受け入れ条件

- Given: ChainEngine から `ChainEvent(level=5)` が流れる
- When: `ChainEffectOverlay` がそれを受信
- Then: パーティクル発生・画面シェイク・大連鎖カラーフラッシュ・キャラ立ち絵が `bigChain` へ差し替わり、`chain_bgm_intensify` で BGM が `play_intense` にスイッチする（Compose UI Test で各 testTag の表示と AudioManager のスナップショットを検証）。

## testTag 一覧

| testTag | 要素 |
|---|---|
| `chain_particle_layer` | パーティクル描画レイヤー |
| `chain_count_overlay` | 連鎖数ズーム表示 |
| `chain_screen_shake` | 画面シェイク適用 Box（Modifier ラッパー） |
| `chain_background_flash` | 背景フラッシュレイヤー |
| `chain_character_overlay` | キャラ立ち絵差し替えレイヤー |
| `chain_bgm_intensify` | BGM 高揚状態をマーカーする透明 Composable（テスト用） |
