# CPU 対戦モード（CpuBattleScreen）

## 機能概要

ユーザー vs CPU の 1 対 1 連鎖バトル。連鎖を組むと相手側におじゃまぷよを送り込む。

## 画面要素

- 画面ルート（`cpu_battle_root`）
- 2 つのプレイフィールドを上下に並べる
  - 自フィールド（`cpu_player_field`）
  - 敵フィールド（`cpu_enemy_field`）
- 各フィールド横にスコア・連鎖数・送られたおじゃまぷよ予告表示（`cpu_player_ojama` / `cpu_enemy_ojama`）
- CPU キャラ立ち絵表示（`cpu_enemy_character_image`）
- 操作 UI: エンドレスと同じ（`playfield_btn_*`）

## ユーザー操作

- 自分が n 連鎖達成 → CPU 側のフィールド上部におじゃまぷよ予告を蓄積
- 次に自分のぷよが着地したタイミングで予告分のおじゃまぷよが CPU 側に降る
- 一方がゲームオーバー条件を満たした時点で勝敗確定 → リザルト画面へ
- 難易度設定により CPU の連鎖力・操作速度が変化

## エラーケース

- 同時にゲームオーバー: ユーザー側を敗北として扱う（CPU 優位）
- 一時停止: CPU 思考も停止する

## データモデル

```kotlin
enum class CpuDifficulty(val maxChainTarget: Int, val thinkDelayMs: Long) {
  Easy(2, 800), Normal(3, 500), Hard(4, 300), Expert(6, 200)
}
data class CpuBattleUiState(val player: PlayUiState, val enemy: PlayUiState, val cpuDifficulty: CpuDifficulty)
```

CPU 思考: 着地直前に 4 連鎖を組めるかをビーム探索（深さ = maxChainTarget）。

## 受け入れ条件

- Given: CPU 対戦モードを難易度 Normal で開始
- When: 自プレイヤーが 4 連鎖を達成
- Then: CPU 側におじゃまぷよが送り込まれる演出が発生し、CPU フィールドが実際に埋まる（Compose UI Test fixture で 4 連鎖フィールド → ojama 反映を検証）。

## testTag 一覧

| testTag | 要素 |
|---|---|
| `cpu_battle_root` | 画面ルート |
| `cpu_player_field` | 自フィールド |
| `cpu_enemy_field` | 敵フィールド |
| `cpu_player_ojama` | 自おじゃま予告 |
| `cpu_enemy_ojama` | 敵おじゃま予告 |
| `cpu_enemy_character_image` | 敵キャラ立ち絵 |
| `playfield_btn_*` | 操作ボタン |
