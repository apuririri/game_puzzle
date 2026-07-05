---
name: autodev-design-sync
description: イテレーションループ I2 で発動。変更した実装（Room Entity/Dao / Retrofit / Composable 画面 / UseCase / DataStore / テスト）に対応する設計書セクションを実装から再生成・差分同期し、設計書を実装の地図（下流成果物）として最新に保つための標準手順。
required_doc_version: "5.2"
---

<!-- version: 1.0 -->

# autodev-design-sync skill

## 適用条件

- イテレーションループの I2「設計書同期」ステップ。
- 機能ループ F7 / 修正ループ R7 のクローズ前 staleness 確認。

## 標準手順（同期対応表は修正方針 §3-7）

1. 変更ファイルの領域を判定し、対応する設計書を同期する。

   | 変更領域 | 同期先設計書 | 同期手段 |
   |---|---|---|
   | `app/.../data/local/entity/` `dao/` | `docs/設計/data_model.md` | @Entity/@Dao 定義 + `app/schemas/` の exportSchema JSON から再生成 |
   | `app/.../data/remote/` | `docs/設計/api.md` | Retrofit interface（@GET/@POST 等のパス・型）から生成 |
   | `app/.../ui/screen/` `ui/navigation/` | `docs/設計/screen_flow.md` + `features/<機能名>.md` | Composable 画面一覧・NavHost ルート・**testTag 一覧**を抜粋 |
   | `app/.../domain/usecase/` | `docs/設計/features/<機能名>.md` | UseCase 一覧 + KDoc を抜粋 |
   | `app/.../settings/` | `docs/設計/data_model.md`（設定キー節） | DataStore キー定義を抜粋 |
   | `app/src/androidTest/` `maestro/` | `docs/設計/features/<機能名>.md` | テストシナリオ一覧を抜粋 |
   | 共通機能・基盤 | `docs/設計/全体設計書.md` | 該当セクションを実装と突き合わせ更新 |

2. 設計書は薄く保つ（1ファイル 500 行以内 / FR-5.4.5）。超えそうなら分割。
3. **testTag 一覧の維持**: 画面追加・変更時は features 設計書の testTag 一覧を必ず更新（テスト作成時の参照地図）。
4. **staleness 確認**: `autodev/scripts/check_design_sync.sh`（クローズ前は `--gate`）で実装との乖離が無いことを確認。

## 完了条件

- 変更領域に対応する設計書が実装と一致 / `check_design_sync.sh` PASS。

## 失敗時の挙動

- 乖離検出 → 設計書を実装に合わせて更新（実装が正 / FR-5.4.1）。

## 関連参照

- 詳細仕様: 要件定義書 FR-5.4 / 9.8
