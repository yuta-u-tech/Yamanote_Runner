# Issue 運用方針

## 基本方針

このプロジェクトは GitHub Issue 単位で Codex に作業を依頼します。Issue には、目的、背景、やること、完了条件をできるだけ明確に書きます。

## Issue に含める内容

- 目的
- 背景
- 変更対象の画面または機能
- 実装すること
- 実装しないこと
- 完了条件
- 確認方法

## Codex に依頼しやすい粒度

1 Issue では、1 つの画面、1 つの機能、1 つのリファクタリング、1 つのドキュメント更新に絞ります。複数の大きな変更をまとめる場合は、先に親 Issue で分割方針を決めます。

## Codex / CLI で扱う作業

- SwiftUI 画面の追加と修正
- ViewModel、Model、Service の実装
- HealthKit 連携コードの追加
- 山手線データと距離計算ロジックの追加
- XCTest の追加
- README と docs の更新
- `xcodebuild` によるビルド確認
- `xcrun simctl` によるシミュレータ起動確認

## Xcode で扱う作業

- Signing & Capabilities 設定
- HealthKit Capability 設定
- SwiftUI Preview での細かい見た目確認
- 実機での権限確認
- App Store 提出
- Instruments によるパフォーマンス確認

## 完了報告に含める内容

- 変更した主なファイル
- 実装した内容
- 実行した確認コマンド
- 未確認事項または Xcode で確認が必要な事項
