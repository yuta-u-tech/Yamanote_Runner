# App Store 提出前チェックリスト

## 実装・設定

| 項目 | 状態 | 確認方法 |
| --- | --- | --- |
| HealthKit Capability が有効 | 実装済み | `YamanoteRunner.xcodeproj/project.pbxproj` の SystemCapabilities |
| HealthKit entitlements が存在 | 実装済み | `YamanoteRunner/YamanoteRunner.entitlements` |
| 歩数読み取りの許可フロー | 実装済み | 初回起動時・未許可時の画面 |
| HealthKit距離と歩数に基づく歩幅表示 | 実装済み | 身長設定と Home 表示 |
| 初回設定フロー | 実装済み | 開始駅選択から Home 遷移 |
| 内回り・外回りの進行方向 | 実装済み | `YamanoteRunnerTests` の方向別ルートテスト |
| 一周達成・バッジ解放 | 実装済み | 34.5km 到達テスト |
| Home 右上の設定導線 | 実装済み | Home 右上の歯車アイコン |

## Privacy / 文言

| 項目 | 状態 | 確認方法 |
| --- | --- | --- |
| HealthKit 使用説明文 | 実装済み | `INFOPLIST_KEY_NSHealthShareUsageDescription` |
| Privacy Manifest | 実装済み | `YamanoteRunner/PrivacyInfo.xcprivacy` |
| プライバシーポリシー / サポートページ | 実装済み | GitHub Pages上の公開ページ |
| App Store のプライバシー回答 | 未対応 | App Store Connect |
| HealthKit データ用途の説明 | 実装済み | 権限画面・README |

## 素材

| 項目 | 状態 | 確認方法 |
| --- | --- | --- |
| App Icon | 実装済み | `YamanoteRunner/Assets.xcassets/AppIcon.appiconset` |
| アイコン外周余白 | 要確認 | 実機・ホーム画面表示 |
| スクリーンショット | 未対応 | 実機またはシミュレータで撮影 |
| バッジ画像 | 実装済み | `badge_*` imageset |

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

- App Store Connect 用スクリーンショット撮影
- 実機HealthKit検証ログの記録
- App Icon の実機表示と外周余白の最終確認
