# アプリ内データ永続化設計

## 方針

v0.1 では軽量な状態のみを扱うため、永続化は `UserDefaults` に集約します。履歴や詳細統計など、件数が増えるデータを扱う段階で SwiftData への移行を検討します。

## 保存対象

| データ | 保存キー | 用途 | 状態 |
| --- | --- | --- | --- |
| 初回設定完了 | `hasCompletedInitialSetup` | 初回設定画面の表示制御 | 実装済み |
| 開始駅 | `startingStation` | 山手線ルートの起点 | 実装済み |
| 累計チャレンジ距離 | `cumulativeDistanceKilometers` | 山手線進捗・周回数計算 | 実装済み |
| 最終同期日時 | `lastSyncDate` | 同日差分同期の判定 | 実装済み |
| 前回同期時の今日距離 | `lastSyncedTodayDistanceKilometers` | 二重加算防止 | 実装済み |
| 獲得済みバッジ | `unlockedBadgeIDs` | バッジ一覧表示 | 実装済み |
| 身長 | `heightCentimeters` | 歩幅推定のフォールバック | 実装済み |

## 保存しない一時状態

| データ | 理由 |
| --- | --- |
| 今回同期で増えた距離 | 同期直後の表示用イベントで、再起動後に復元する必要がない |
| 通過駅イベント | 同期直後の演出用で、履歴機能が入るまでは永続化しない |
| HealthKit 取得中・取得失敗状態 | 実行時の通信/権限状態に依存するため |

## 将来の移行候補

- 日別歩数・距離履歴
- 駅通過履歴
- 周回達成履歴
- 複数路線の解放状態
- ユーザー設定の詳細化

これらを扱う場合は、`UserDefaults` ではなく SwiftData などの構造化ストレージへ分離します。

## Vol.2 追加方針

Vol.2の散歩マップ機能では、既存のv0.1キーを変更しない。新しい保存項目が必要な場合は `vol2.` 接頭辞を付け、ルート進捗・履歴・バッジの既存データと分離する。

初期候補:

| データ | 保存キー案 | 用途 |
| --- | --- | --- |
| マップ機能の解放状態 | `vol2.mapFeatureUnlocked` | StoreKit連携前の機能ゲート |
| 管理者向け購読オーバーライド | `vol2.adminSubscriptionOverride` | 管理者確認時にStoreKit購入状態とは別にマップ機能を解放 |
| 最後に表示したマップ状態 | `vol2.lastMapViewport` | マップ表示復元 |
| マップ用チュートリアル完了 | `vol2.hasSeenMapIntro` | 初回案内の表示制御 |

StoreKitの商品ID、購入状態、レシート検証状態は、実装時に専用の購読/権限サービスへ分離する。

## 管理者向け購読オーバーライド

実機検証時は、通常のPaywallにある「購入を復元する」からマップ機能を解放できる。Xcode Scheme の Environment Variables が実機へ渡る場合は以下を照合する。

- `YAMANOTE_ADMIN_EMAIL`: `yuta_Hinu_auth@email.com`
- `YAMANOTE_ADMIN_PASSCODE`: `yuta_Hinu_pass`

環境変数が一致する場合、または開発ビルドで環境変数が渡っていない場合、`vol2.adminSubscriptionOverride` が `true` で保存され、以後はStoreKitの購入状態に関係なく購読済み扱いになる。この設定は本番デプロイ前に削除する。
