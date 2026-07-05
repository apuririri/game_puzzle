# 美少女連鎖パズル

Android 向けの落下連鎖パズルゲーム。Kotlin + Jetpack Compose + Material 3 で実装。
**派手な連鎖演出 / オリジナル美少女キャラ / 可愛いボイス** の 3 要素で SNS 映えを狙います。

## 主要機能

- **4 ゲームモード**: エンドレス / スコアアタック / ストーリー / CPU 対戦
- **6 キャラ × 10 立ち絵**: 通常 / 喜 / 怒 / 哀 / 連鎖中 / 大連鎖 / 敗北 / ウインク / 思考 / 勝利ポーズ（v0.2 で「あぷりりり」追加）
- **連鎖演出システム**: 拡大パーティクル / 画面シェイク / カラーフラッシュ / キャラ立ち絵差替え / 5+ 連鎖で BGM 高揚
- **大連鎖クリップ自動保存**: 5 連鎖以上で mp4 をギャラリーに自動保存（OFF 可）
- **ローカルランキング TOP10**: モード別
- **オート＋手動セーブ**: 中断復帰
- **オフライン完結**: バックエンド不要 / インターネット権限不要（リリース版）

<img width="478" height="1064" alt="gamen3" src="https://github.com/user-attachments/assets/2001f4ca-25dc-494a-8dc7-221b44c170d1" />
<img width="475" height="1064" alt="gamen2" src="https://github.com/user-attachments/assets/59e3ad8b-ba2d-4c3b-a167-8f2f464938cf" />


## ドキュメント

- 操作手順: [docs/操作手順書.md](docs/操作手順書.md)
- インストール: [docs/インストール手順.md](docs/インストール手順.md)
- 設計書: [docs/設計/全体設計書.md](docs/設計/全体設計書.md) / [docs/設計/features/](docs/設計/features/)

## 動作環境

| 項目 | 値 |
|---|---|
| 最低 Android | 8.0 (API 26) |
| ターゲット Android | 15 (API 35) |
| 画面向き | Portrait 固定 |
| 言語 | 日本語 |
| 通信 | 不要（オフライン完結） |

## ビルド

Debug APK ビルド:

    autodev/scripts/build.sh debug
    # 出力: app/build/outputs/apk/debug/app-debug.apk

Release APK ビルド（署名済み、要 keystore 環境変数）:

    RELEASE_STORE_FILE=... RELEASE_STORE_PASSWORD=... RELEASE_KEY_ALIAS=... RELEASE_KEY_PASSWORD=... \
        autodev/scripts/build.sh release
    # 出力: app/build/outputs/apk/release/app-release.apk

リリース時はツール本体ディレクトリ（autodev/, .claude/, CLAUDE.md）を削除して顧客提供物を分離します。

## ライセンス

開発者から直接ライセンス供与。

---

## 開発者向け（AutoDev for Android）

このリポジトリは Claude Code 上の AutoDev エージェントで自動開発されています。
ツール本体の詳細は `README.md.autodev_orig` および `autodev/CLAUDE_MAIN.md` を参照してください。
