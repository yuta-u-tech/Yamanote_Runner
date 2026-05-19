# 開発手順

## 前提

- Xcode 16.2 以降
- iOS 17.0 以降
- macOS 上で `xcodebuild` と `xcrun simctl` が使えること

このプロジェクトは、日常的な実装と検証を VS Code / Codex / CLI 中心で進めます。Xcode は Signing & Capabilities、HealthKit Capability、SwiftUI Preview、実機確認、App Store 提出などに限定して使います。

## 基本情報

- アプリ名: 山手線ランナー
- Scheme: `YamanoteRunner`
- Project: `YamanoteRunner.xcodeproj`
- Bundle ID: `com.youbo0129ueno.YamanoteRunner`
- 最低対応 iOS: 17.0
- Derived Data: `.build`

## ビルド

```bash
make build
```

直接 `xcodebuild` を使う場合:

```bash
xcodebuild \
  -project YamanoteRunner.xcodeproj \
  -scheme YamanoteRunner \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath .build \
  build
```

## テスト

```bash
make test
```

## シミュレータで起動

```bash
make run
```

内部では次の順で実行します。

```bash
xcrun simctl boot "iPhone 16 Pro" || true
xcrun simctl install booted .build/Build/Products/Debug-iphonesimulator/YamanoteRunner.app
xcrun simctl launch booted com.youbo0129ueno.YamanoteRunner
```

別のシミュレータを使う場合:

```bash
make run SIMULATOR="iPhone 15"
```

## VS Code タスク

`.vscode/tasks.json` に次のタスクを用意しています。

- `iOS Build Debug`
- `iOS Test Debug`
- `Boot Simulator`
- `Install App`
- `Launch App`
- `Build and Run`

## Xcode で行う作業

- Signing & Capabilities 設定
- HealthKit Capability 設定
- SwiftUI Preview を使った UI 確認
- 実機ビルド
- App Store 提出
- Instruments によるパフォーマンス確認

## Codex / CLI で進める作業

- SwiftUI 画面実装
- ViewModel 実装
- Model 実装
- HealthKit 連携コード実装
- 山手線データ定義
- 距離計算ロジック
- バッジ判定ロジック
- XCTest 追加
- README と docs の更新
- Issue 単位の修正
