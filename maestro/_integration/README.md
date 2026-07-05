# maestro/_integration/ — 機能横断シナリオ（S10 IV3）

このディレクトリは `autodev-integration-verify` skill（S10）が `run_integration_check.sh` から実行する
**機能横断シナリオ**の Maestro flow を置く場所。

機能ごとの受け入れ条件 flow は `maestro/<機能名>.yaml` に置く。ここには「複数機能をまたぐ動線」
「リリース後の挙動を想定した実機操作」のみを置く。

## 同梱の雛形（命名は固定）

- `login_to_logout.yaml` — ログイン→主要動線→ログアウトの連結
- `kill_restart_state.yaml` — アプリ kill → 再起動 で状態保持を確認
- `background_restore.yaml` — バックグラウンド退避→復帰
- `offline_recovery.yaml` — 機内モード（オフライン）→オンライン復帰
- `rotation.yaml` — 画面回転で状態保持
- `permission_denied.yaml` — 権限拒否時の画面遷移

## 命名規則（追加 flow を作る場合）

- 機能間連結シナリオは内容を表す動詞句で命名する（例: `cart_to_purchase.yaml` / `signup_to_first_post.yaml`）。
- 1 flow 1 目的。複数の主要動線を1ファイルに詰めない（fail 時の特定が困難になる）。

## 規約

- appId は `autodev/config/loop.yaml::application_id` と一致させる。
- testTag（resource-id）参照のみ。**座標タップ禁止**。
- 端末操作（回転・機内モード・権限変更）は `run_adb.sh` 経由で `runScript` または `runFlow` で挟む。
- スクショは `takeScreenshot: autodev/evidence/_integration/screenshots/<flow>_<step>` 形式で保存。
- 1 flow あたりの目安は 1〜3 分。長すぎる場合は分割する。

## 実行方法

通常は `autodev/scripts/run_integration_check.sh` から自動実行される。
個別実行: `autodev/scripts/test_maestro.sh maestro/_integration/<flow>.yaml _integration_<name>`
