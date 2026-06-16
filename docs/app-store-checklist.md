# App Store 提出前チェックリスト

## 実装・設定

| 項目 | 状態 | 確認方法 |
| --- | --- | --- |
| HealthKit Capability が有効 | 要確認 | Xcode の Signing & Capabilities |
| HealthKit entitlements が存在 | 実装済み | `YamanoteRunner/YamanoteRunner.entitlements` |
| 歩数読み取りの許可フロー | 実装済み | 初回起動時・未許可時の画面 |
| HealthKit距離と歩数に基づく歩幅表示 | 実装済み | 身長設定と Home 表示 |
| 初回設定フロー | 実装済み | 開始駅選択から Home 遷移 |
| 一周達成・バッジ解放 | 実装済み | 34.5km 到達テスト |

## Privacy / 文言

| 項目 | 状態 | 確認方法 |
| --- | --- | --- |
| HealthKit 使用説明文 | 要確認 | Info.plist / Xcode 設定 |
| Privacy Manifest | 未確認 | Xcode プロジェクト内の privacy 設定 |
| App Store のプライバシー回答 | 未対応 | App Store Connect |
| HealthKit データ用途の説明 | 実装済み | 権限画面・README |

## 素材

| 項目 | 状態 | 確認方法 |
| --- | --- | --- |
| App Icon | 未確認 | Assets catalog |
| アイコン外周余白 | 未確認 | 実機・ホーム画面表示 |
| スクリーンショット | 未対応 | 実機またはシミュレータで撮影 |
| バッジ画像 | 未確認 | 画像アセット追加後に確認 |

## 実機・表示確認

| 項目 | 状態 | 確認方法 |
| --- | --- | --- |
| HealthKit 許可 | 未確認 | 実機で初回許可 |
| 歩数取得成功 | 未確認 | 実機のヘルスケアデータ |
| データなし表示 | 未確認 | 歩数0の状態 |
| 取得失敗表示 | 未確認 | 権限拒否またはHealthKit不可 |
| ライトモード | 未確認 | SwiftUI Preview / 実機 |
| ダークモード | 未確認 | SwiftUI Preview / 実機 |
| 小さい画面 | 未確認 | iPhone SE 相当 |

## 追加Issue候補

- App Icon とバッジ画像のアセット追加・余白調整
- Privacy Manifest の作成
- App Store Connect 用スクリーンショット撮影
- 実機HealthKit検証ログの記録
