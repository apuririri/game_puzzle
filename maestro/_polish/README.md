# maestro/_polish/ — UI 改善 動的状態スクショ用 flow（S11 UP2 / UP6）

このディレクトリは `autodev-ui-polish` skill（S11）が `capture_all_screens.sh` から実行する
**動的状態（loading / empty / error）の発火専用 flow** を置く場所。

通常の before / after スクショは `capture_all_screens.sh` が自動生成する flow で取得するため、
このディレクトリは「特定の状態を再現するための flow」のみを置く。

## 命名

`_state_<screen_id>_<state>.yaml`

- `<screen_id>` は `autodev/state/ui_polish/inventory.json::screens[].screen_id`
  （route 名のスラッシュ・波カッコをアンダースコアに置換した値。例: `product/{id}` → `product_id`）。
- `<state>` は `autodev/config/ui_polish.yaml::dynamic_states` の値（loading / empty / error）。

例:
- `_state_home_loading.yaml` — ホーム画面の loading 状態を発火
- `_state_home_empty.yaml` — ホーム画面の empty 状態（データ 0 件）を発火
- `_state_home_error.yaml` — ホーム画面の error 状態（通信エラー）を発火

## 規約

- testTag 参照のみ。**座標タップ禁止**。
- **この flow は「状態を画面に出すだけ」が責務。`takeScreenshot` は書かない**。
  スクショは `capture_all_screens.sh` が `adb exec-out screencap` で `evidence_dir/<screen_id>/<phase>_<state>.png`
  に保存する（phase=before/after の出し分けはスクリプト側が行う）。
- 状態発火に外部状態が必要（DB 0 件 / API エラー注入）の場合は `runScript` で `run_adb.sh` を呼ぶ。
- 発火が困難な画面は `autodev/config/ui_polish.yaml::dynamic_state_optional` に screen_id（または route）
  を登録すれば省略可。

## 雛形

このディレクトリには **雛形（_state_home_*.yaml）のみ** 同梱。プロジェクトの画面に応じて
list_screens.sh の inventory.json をもとに skill が自動生成・追記する。
