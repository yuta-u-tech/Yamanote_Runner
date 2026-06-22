# 山手線ランナー

## 概要

山手線ランナーは、iPhoneの歩行・ランニング距離を「山手線上の進捗」に変換する、健康記録 × ゲーム体験アプリです。

東京にいなくても、自分が歩いた距離・走った距離によって山手線を進み、駅を通過し、一周達成を目指すことができます。

## コンセプト

通常の歩数・距離記録アプリでは、ユーザーは「今日は何km歩いたか」を確認するだけで終わりがちです。

山手線ランナーでは、その距離を山手線の駅間に対応させることで、

- 今日はどの駅まで進んだか
- 次の駅まであと何kmか
- 山手線を何周したか
- 一周達成まであとどれくらいか

を楽しく確認できます。

目的は、運動習慣を楽しく継続できる体験を作ることです。

## 想定ユーザー

- 運動習慣をつけたい人
- ウォーキングを楽しく続けたい人
- ランニング距離に意味づけが欲しい人
- 普通の歩数アプリでは続かなかった人
- ゲーム感覚で日々の移動距離を記録したい人

## v0.1 MVP 方針

初期リリースでは、山手線ステージのみを実装します。

### v0.1で実装する機能

- HealthKit連携
- 今日の歩行・ランニング距離の取得
- 前回同期との差分だけチャレンジ距離に加算
- アプリ起動時、Home表示時、バックグラウンド復帰時の距離再取得
- 山手線ステージ
- スタート駅選択
  - 主要駅から選択
  - 全駅から選択
  - ランダム出発
- 内回り・外回りの進行方向選択
- 今日の移動距離表示
- 山手線上の現在位置表示
- 次の駅までの距離表示
- 駅通過イベント表示
- 周回数表示
- 山手線一周達成演出
- 最小限のバッジ・称号機能

### v0.1では実装しない機能

- 中央線ステージ
- 京浜東北線ステージ
- 複数路線の解放
- 乗り換え機能
- カスタムルート
- SNS共有
- ランキング
- 広告
- アプリ内課金
- 詳細な統計グラフ

## 距離と歩幅の扱い

v0.1 では HealthKit から今日の歩行・ランニング距離を取得し、その距離を山手線進捗へ反映します。歩数も HealthKit から取得し、取得距離と歩数から実績歩幅を計算して Home に表示します。

- 既定身長: 170cm
- 実績歩幅: `HealthKit距離 / 歩数`
- 推定歩幅: `身長(cm) * 0.415`

歩数が0、または距離が0の場合は実績歩幅を計算できないため、身長ベースの推定歩幅を表示します。身長は設定画面から変更できます。

## 開発方針

本プロジェクトでは、Codexを活用したIssue駆動開発を前提とします。

Xcodeでの手作業をできるだけ減らし、日常的な実装・修正・ドキュメント更新は以下を中心に進めます。

- GitHub Issue
- Codex
- VS Code
- CLI
- Swiftファイル
- Markdownドキュメント

ただし、iOSアプリ開発の性質上、以下の作業ではXcodeを使用します。

- 初期プロジェクト作成
- Signing & Capabilities設定
- HealthKit Capability設定
- 実機ビルド
- SwiftUI Preview確認
- App Store提出前の確認

## 技術スタック

予定している主な技術は以下です。

- Swift
- SwiftUI
- HealthKit
- UserDefaults または SwiftData
- XCTest
- xcodebuild
- xcrun simctl

## ディレクトリ構成案

```text
YamanoteRunner/
├── YamanoteRunner/
│   ├── App/
│   ├── Models/
│   ├── Views/
│   ├── ViewModels/
│   ├── Services/
│   ├── Data/
│   └── Utilities/
├── YamanoteRunnerTests/
├── docs/
│   ├── requirements.md
│   ├── development.md
│   └── issue-policy.md
├── .vscode/
│   └── tasks.json
├── README.md
└── Makefile
```

## 開発環境

- Xcode 16.2 以降
- iOS 17.0 以降
- SwiftUI
- CLI ビルド: `xcodebuild`
- シミュレータ実行: `xcrun simctl`

## CLI でのビルドと実行

```bash
make build
make test
make run
```

既定のシミュレータは `iPhone 17`、Bundle ID は `com.youbo0129ueno.YamanoteRunner` です。

詳細な手順は [docs/development.md](docs/development.md) を参照してください。

永続化設計は [docs/persistence.md](docs/persistence.md)、App Store 提出前の確認項目は [docs/app-store-checklist.md](docs/app-store-checklist.md) を参照してください。

## v0.1の既知の制限

- HealthKitの実データ取得は実機確認が必要です。
- シミュレータでは歩行・ランニング距離が0kmになる場合があります。
- バッジはv0.1向けの最小セットのみです。
- Vol.2の散歩マップ機能はサブスク枠として別Issueで扱います。土台方針は [docs/vol2-foundation.md](docs/vol2-foundation.md) を参照してください。
