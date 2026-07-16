# TimeNest 1.3 日本語 App Store スクリーンショット

TimeNestの現在のDebugビルドと既存の本番UIコンポーネントから作成した、日本語のApp Store Connect用素材です。Version / Buildは `1.3 (6)` のまま変更していません。

## ディレクトリ

- `iPhone/raw`: iPhone Simulatorの元画像10枚（1320 x 2868）
- `iPhone/final`: 宣伝文案と端末枠を合成した10枚（1320 x 2868）
- `iPad/raw`: iPad Simulatorの元画像10枚（2064 x 2752）
- `iPad/final`: 宣伝文案と端末枠を合成した10枚（2064 x 2752）
- `copy/screenshot-copy.md`: 10テーマ分のタイトル、サブタイトル、説明
- `templates/style-guide.md`: レイアウトと素材のルール
- `manifest.json`: 文案、色、クロップ、対象端末、出力寸法の機械可読な正本
- `scripts/capture_screenshots.sh`: Debugビルド、Simulator起動、元画像の再撮影
- `scripts/compose_screenshots.py`: 元画像から宣伝版を再生成
- `scripts/verify_screenshots.py`: 枚数、寸法、透明度、カラープロファイル、文案を検証

## 今回の撮影条件

| 区分 | Simulator | OS | 出力寸法 |
|---|---|---|---|
| iPhone | iPhone 17 Pro Max | iOS 26.5 | 1320 x 2868 |
| iPad | iPad Pro 13-inch (M5) | iPadOS 26.5 | 2064 x 2752 |

撮影用データはDebug専用の匿名サンプルです。2026年7月を基準に、予定、日勤・夜勤・早番、勤務時間、海の日、閲覧専用の共有カレンダーを表示します。実アカウント、実CloudKit、連絡先、ユーザー識別子は使用しません。

## 再撮影

Xcode、Tuistで生成済みのworkspace、専用のiPhone/iPad Simulatorが必要です。

```zsh
PHONE_UDID="<dedicated iPhone simulator>" \
IPAD_UDID="<dedicated iPad simulator>" \
RESET_SIMULATORS=1 \
AppStoreAssets/1.3/ja/scripts/capture_screenshots.sh
```

`RESET_SIMULATORS=1` は指定したSimulatorを消去します。Widgetを重複させず再現するため、個人データを入れていない撮影専用Simulatorでのみ使用してください。消去しない場合は `RESET_SIMULATORS=0` にします。`CAPTURE_WIDGET=0` でWidgetの自動追加と再撮影だけを省略できます。

Widgetは `TimeNestScreenshotUITests` がSpringBoardのWidgetギャラリーを操作し、現在のTimeNest Widget Extensionを実際に追加して撮影します。UIやWidgetを画像生成で作り直してはいません。

## 宣伝版の生成

Python 3とPillowが必要です。macOS標準の日本語フォントを自動検出します。必要な場合のみ、`TIMENEST_SCREENSHOT_FONT` で別のローカルフォントを指定できます。

```zsh
python3 AppStoreAssets/1.3/ja/scripts/compose_screenshots.py
python3 AppStoreAssets/1.3/ja/scripts/verify_screenshots.py
```

外部の端末フレームやフォント素材は使いません。端末枠、背景、影は合成スクリプトが描画し、UI部分は `raw` の実キャプチャを使用します。

## 実装上の境界

- 撮影シーンとサンプル設定は既存の `#if DEBUG` 内だけに追加。
- Releaseの表示経路、業務ロジック、SwiftData schema、CloudKit、共有仕様、StoreKit、広告、Widget本体、version/buildは未変更。
- Widget文案は、現在の小サイズWidgetが月間カレンダーである事実に合わせて「Widgetから、カレンダーをすばやくチェック。」へ調整。
