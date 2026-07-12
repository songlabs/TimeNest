# TimeNest Release Review: v1.0.0 to HEAD

作成日: 2026-07-06

## 2026-07-12 追補

- 現在の repository HEAD は `8bea0d9`。下記の 2026-07-06 時点の commit 数、HEAD、diff 件数、検証結果は履歴スナップショットであり、現在値として扱わない。
- その後、Apple iCloud / CloudKit を使う共有カレンダーを追加。作成者は予定・シフト・勤務記録を個別に共有でき、受信側は閲覧のみ。メモ、通知、音声内容、時給、給与、交通費、テンプレート、広告・購入状態、端末情報、App 設定、Widget の私的データ、祝日購読内部情報は共有対象外。
- `ja` / `zh-Hans` / `zh-Hant` / `en` / `ko` の `Localizable.strings` は現在各 392 keys。`InfoPlist.strings` は各 5 keys。
- TimeNest 独自アカウント、開発者運用 backend、汎用 cloud sync は引き続き存在しないが、「cloud sharing は未実装」という旧表現は現在の CloudKit 共有機能には適用しない。
- `v1.0.0` の app sandbox `Library/Application Support/TimeNest.store` と、現在の App Group `Library/Application Support/TimeNest.store` は別 URL であり、自動 fallback はないため upgrade data loss risk は成立していた。現在は `LegacyStoreMigrator` の一回限りの model-level migration で code-side risk を修正済み。
- migration は移行先が空の場合だけ全 2 entities を保存し、既存の移行先データを上書き・merge せず、旧 store を削除しない。local temporary-store tests は通過したが、App Store `v1.0.0` からの実機 upgrade は未確認。
- public `privacy.html` / `support.html` の source は本 repository にない。CloudKit 対応草案は更新したが、公開 URL は未同期で人工 publish が必要。

## 1. 対象範囲

- 対象範囲: `v1.0.0..HEAD`
- ローカル状態: `git fetch --tags` 後、`v1.0.0` tag はローカルに存在し、`git diff v1.0.0..HEAD` は使用可能。
- 対象コミット数: 9 commits
- 現在の HEAD: `808ff8a`

## 2. v1.0.0 以降の主な変更

### 機能追加

- Remove Ads の一回限りの Apple In-App Purchase を追加。
  - StoreKit 2 の購入、復元、transaction updates 監視、起動時の entitlement refresh を追加。
  - Settings に「広告を削除」「購入を復元」を追加。
  - 購入済み状態では広告バナー枠自体を作成しない実装。
- 予定メモの音声入力を追加。
  - Event editor のメモ欄から開始/停止。
  - マイク権限と音声認識権限を追加。
  - 実装上は対応デバイス/言語で on-device speech recognition を要求。
- カレンダー表示カスタマイズを追加。
  - 通常予定と勤務記録の背景色設定を追加。
  - シフト色はシフト設定側に残し、カレンダー表示カスタマイズ対象からは分離。

### UI / UX 調整

- Event editor を整理し、新規作成時に「予定」「勤務記録」を選べる構成へ更新。
- 日付詳細から勤務記録を追加/編集する導線を整理。
- 月/週/日表示のイベントチップ、勤務記録表示、下部広告エリアの表示条件を調整。
- 24時間の時刻ピッカーを改善。
- Settings に第三者ライセンス、広告購入/復元、カレンダー表示カスタマイズを追加。

### 多言語調整

- `ja` / `zh-Hans` / `zh-Hant` / `en` / `ko` の `Localizable.strings` は各 351 keys。
- `InfoPlist.strings` は各 5 keys。
- ATT、マイク、音声認識の目的文字列が全対応言語に存在。
- Help の 6カテゴリは現在の UI と一致。
  - 予定の追加・編集
  - 月・週・日表示
  - 祝日・休日
  - シフトと勤務記録
  - 広告
  - データとプライバシー

### 広告 / 購入関連

- Google Mobile Ads / UMP の既存経路は維持。
  - UMP consent update
  - `canRequestAds`
  - ATT
  - Mobile Ads start
  - banner load
- Debug と simulator は Google 公式 test ID を使用。
- Release device/archive は production ID を build settings から使用し、validation script と `AdConfiguration` で disabled / empty / placeholder / malformed / test ID を拒否。
- StoreKit configuration file は Debug launch 用に scheme へ関連付けられている。これはローカル検証補助であり、App Store Connect の IAP 設定完了を意味しない。

### データ / Widget 関連

- SwiftData entity file の変更はこの範囲では見当たらない。
- `VersionedSchema` / `SchemaMigrationPlan` の追加はない。
- SwiftData の schema 構成は `SwiftDataCalendarEventEntity` と `SwiftDataReminderEntity` のまま。
- ただし production store の URL が App Group container 配下に変更された。
  - App は App Group の SwiftData store を使い、Widget は同じ App Group 内の別ファイル `widget-snapshot.json` を読む。Widget は SwiftData store を直接開かない。
  - 旧 store location から新 store location への guarded model-level migration を追加済み。
  - local temporary-store tests で data copy / no overwrite / no repeat / rollback を確認済み。App Store install package の実機 upgrade data preservation は人工確認が必要。
- Widget snapshot refresh はイベント変更時と起動時に走る構成。

### Bug 修正

- StoreKit product load / restore / entitlement scan の診断強化。
- App Group container の Application Support directory を作成して SwiftData store 作成失敗を避ける処理を追加。
- 日語と簡体字中国語の文案修正。
- カレンダー UI の表示崩れ/視認性調整。

### ドキュメント更新

- README を現在実装に合わせて更新。
  - 音声メモ入力
  - Remove Ads
  - UMP/ATT と広告
  - App Group local-first data
  - privacy / permissions
- App 内 Help を現在 UI と実装に合わせて更新。
- App Store release checklist の localization count と permission description を更新。

## 3. App Store 審査観点

- アカウント不要、ログイン不要、TimeNest 独自 cloud sync なし、developer backend なしという説明はコード/文書と一致。
- マイク/音声認識 permission はメモ音声入力のユーザー操作からのみ必要になる説明へ更新済み。
- Widget は App Group を利用するため、Developer Portal / provisioning profile 側の App Group 有効化は人工確認が必要。
- Privacy policy / support URL は docs と Settings に存在するが、公開ページの最新内容が提出 build と一致するかは人工確認が必要。
- App Store 審査通過は保証不可。特に広告、ATT、App Privacy、IAP product status、実機/TestFlight 動作は提出直前の人工確認対象。

## 4. 広告 / UMP / ATT / StoreKit 観点

- Release build settings は production AdMob ID を参照する状態として確認済み。ただし本書では完全な ID は記載しない。
- Release generic iOS build で validation script は失敗していない。
- Debug/simulator test ID は想定どおり残っている。
- UMP privacy options action は Help の privacy category で、UMP が required の場合のみ表示。
- ATT purpose string は 5言語に存在。
- StoreKit local configuration は存在するが、App Store Connect の IAP product 作成/承認/価格/販売状態は人工確認が必要。
- Restore は `AppStore.sync()` と current entitlements に依存。TestFlight/Sandbox/本番環境での復元は人工確認が必要。

## 5. データ / SwiftData / Widget 観点

- SwiftData schema file の変更はなし。
- schema migration plan 追加なし。
- store location は App Group container 配下へ変更されている。
- 既存 store から App Group store への一回限りの model-level migration を追加。移行先に event/reminder が存在する場合は import せず、旧 store は保持する。
- migration regression tests は temporary directory 上で通過。実際の App Store `v1.0.0` からの upgrade install は未確認のため、実機 release gate として残る。
- Widget bundle / App Group / entitlement は repository 上で整合しているが、Apple Developer 側の identifier / profile は人工確認が必要。

## 6. 多言語 / Help / README 更新内容

- README:
  - 音声メモ入力を Features / Data And Privacy / checklist に追加。
  - Release Advertising Configuration から完全な AdMob ID の直接記載を避け、build settings 参照へ変更。
  - SwiftData + App Group local-first data を明記。
- Help:
  - 予定追加説明にメモ音声入力を追加。
  - シフトと勤務記録の説明を現在の「勤務記録を新規作成」/ entry kind picker に合わせて更新。
  - 広告説明を UMP 許可、Remove Ads、購入復元に合わせて更新。
  - データとプライバシー説明を local data、App Group Widget sharing、アカウント不要、cloud sync なしに更新。
- 多言語:
  - 既存 key の値のみ更新。
  - key set は 5言語で一致。
  - 日語 Help で「休息時間」の誤用は見つからず、「休憩時間」を維持。

## 7. 最終確認結果

- Repository/build 観点: build は通過。
- App Store submission 観点: 条件付きで提出準備へ進める状態。
- ただし、以下の人工確認が完了するまでは「審査通過確実」や「production service 側も完了」とは断言しない。
- Release build で StoreKit debug summary の deprecated API warning が 1件出る。現在は debug summary 由来で build blocker ではない。

## 8. 人工確認が必要な項目

- App Store Connect:
  - App record、version/build、metadata、screenshots、age rating、review notes。
  - `zh-Hant` product page locale を有効にする場合の App Store metadata。
- AdMob:
  - Production App ID / Banner Unit ID の承認状態。
  - UMP message configuration。
  - 地域別 privacy options と consent behavior。
- App Privacy:
  - Google Mobile Ads / UMP の最終 SDK privacy manifest と archive privacy report。
  - Device ID tracking、tracking domains、App Privacy questionnaire。
  - Public privacy policy の最終文面。
- IAP / StoreKit:
  - Remove Ads product の App Store Connect status。
  - Sandbox/TestFlight/本番相当での purchase / restore。
  - Reinstall 後の restore behavior。
- TestFlight / 実機:
  - Fresh install UMP -> ATT -> ad loading。
  - ATT allow/deny/restricted。
  - 音声メモ permission allow/deny。
  - Purchased/unpurchased ad layout。
  - Widget refresh and deep link。
  - App Store `v1.0.0` から current candidate への実機 upgrade と migrated data / Widget refresh。

## 9. 検証結果

- `git fetch --tags`
  - 成功。`v1.0.0` tag を取得済み。
- `git rev-parse v1.0.0`
  - 成功。`24ac97da657c0b72f0bddf38c0faa58ab6fadfbc`。
- `git diff --name-status v1.0.0..HEAD`
  - 成功。38 files changed。
- `git diff --stat v1.0.0..HEAD`
  - 成功。2616 insertions / 620 deletions。
- `git diff --name-only v1.0.0..HEAD`
  - 成功。
- `xcodebuild -list -project TimeNest.xcodeproj`
  - 成功。Schemes: `TimeNest`, `TimeNestWidgetExtension`。
- `xcodebuild -project TimeNest.xcodeproj -scheme TimeNest -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build`
  - 成功。`iPhone 16` simulator はこの環境に存在しないため、利用可能な `iPhone 17` を使用。
- `xcodebuild -project TimeNest.xcodeproj -scheme TimeNest -configuration Release -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO build -quiet`
  - 成功。Release AdMob validation script は失敗していない。
  - Warning: StoreKit transaction debug summary で deprecated API warning 1件。
- `plutil -lint` on all `Localizable.strings` / `InfoPlist.strings`
  - 成功。
- Localization key parity check using `plutil -convert json` + `jq`
  - 成功。key set mismatch なし。
- Empty localized value check
  - 成功。空値なし。
- `git diff --check`
  - 成功。

## 10. 非意図 diff

- 作業開始時点で 18 tracked files に未 commit 変更が存在。本作業はそれらを reset / checkout せず保持した。
- 現在の worktree は 22 entries（19 modified / 3 untracked）。このうち本作業の変更を含むのは 13 files（migration code/test/project registration、README、7 release docs、support draft）。
- 残る 9 files（2 generated strings、`AdConfiguration.swift`、`CloudKitCalendarSharingClient.swift`、5 locale strings）は作業開始前からの別変更で、本作業では内容を変更していない。
- `TimeNestApp.swift` に作業開始前から存在した ad-consent startup diff は保持し、本作業では ModelContainer 作成部分だけを migration 対応へ変更した。
- SwiftData schema、広告ロジック、StoreKit Product ID、CloudKit schema、Widget/App Group identifier、署名設定は本作業では変更していない。SwiftData store migration とその tests は本追補で追加した。

## 11. 2026-07-12 追補の検証結果

- `tuist generate --no-open`
  - 成功。追加した migration source / test の project 登録だけを確認し、generated strings の trailing whitespace は機械的に除去。
- SwiftData default `ModelConfiguration("TimeNest", ...)` URL probe
  - `Library/Application Support/TimeNest.store` を確認。current App Group store は App Group container の `Library/Application Support/TimeNest.store` であり、同名だが container が異なる。
- `xcodebuild -workspace TimeNest.xcworkspace -scheme TimeNest -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TimeNestTests/LegacyStoreMigrationTests test`
  - 成功。6 tests / 0 failures。
- local upgrade simulation
  - 上記 migration tests の temporary directory で、予定・シフト・勤務記録・reminder の import、二回目の no-op、destination data protection、save 前 failure rollback、legacy store preservation を確認。
- `xcodebuild -workspace TimeNest.xcworkspace -scheme TimeNest -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - 成功。
- `xcodebuild -workspace TimeNest.xcworkspace -scheme TimeNest -configuration Release -destination 'generic/platform=iOS Simulator' build`
  - 成功。最終 source 変更後にも再実行済み。
- `xcodebuild -workspace TimeNest.xcworkspace -scheme TimeNest -destination 'platform=iOS Simulator,name=iPhone 17' test`
  - 成功。187 tests / 0 failures。
- public URL check
  - `privacy.html` / `support.html` は HTTP 200。ただし CloudKit disclosure / sharing support / Traditional Chinese language list は未反映で、公開 source の人工更新が必要。
- `git diff --check`
  - 成功。
- Archive / signing / Organizer validation / upload
  - 本作業の禁止事項に従い未実行。
