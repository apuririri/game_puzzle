# 設計書（docs/設計/）

この配下はアプリ実装の「地図」となる設計書群です。**実装が正（上流）であり、設計書は実装に同期される下流成果物**です
（全体設計書・機能設計書の初版のみ、実装前に新規作成されることがあります）。顧客提供物の一部です。

## 構成

- `README.md` — 本ファイル。全体像・重要な落とし穴・不変条件。
- `architecture.md` — アーキテクチャ概要、ディレクトリ地図、不変条件。
- `全体設計書.md` — システム全体の機能間関係・画面遷移・データフロー・共通機能（システムループ S4 で AI が作成）。
- `data_model.md` — Room スキーマ + DataStore キー概要（実装から同期）。
- `api.md` — 外部 API IF 概要（Retrofit interface から同期）。
- `screen_flow.md` — 画面（Composable）一覧・Navigation ルート・testTag 一覧（実装から同期）。
- `features/<機能名>.md` — 各機能のローカル規約・データモデル・IF・testTag 一覧（機能ループ F2 で作成、F7 で同期）。

## 重要な落とし穴・不変条件

- 設計書とコードが食い違ったら **コードが正**。`autodev/scripts/check_design_sync.sh` が乖離を検出する。
- 1ファイル 500 行を超えそうなら分割する。
- DB スキーマは Room（`app/.../data/local/` + `app/schemas/` の exportSchema 出力）を唯一の源とし、設計書はそれを反映するだけ。
- 画面の testTag 一覧は設計書に必ず残す（Compose UI Test / Maestro 作成時の参照地図）。
