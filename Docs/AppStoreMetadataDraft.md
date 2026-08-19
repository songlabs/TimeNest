# TimeNest App Store Metadata Final Draft

> Final copy candidate for App Store Connect. These fields have not been submitted. Confirm field limits, the legal rights-holder name, production advertising configuration, and every claim against the exact submitted build before release.

## Shared App Information

- App Name: TimeNest
- Version: **TODO — use the exact submitted marketing version**
- Primary Language: Japanese (`ja`)
- Supported Languages: `ja` / `zh-Hans` / `zh-Hant` / `en` / `ko`
- Primary Category recommendation: Productivity
- Secondary Category recommendation: Utilities
- Support URL: https://songlabs.github.io/timenest/support.html
- Privacy Policy URL: https://songlabs.github.io/timenest/privacy.html
- Copyright: `2026 SongLabs`
  - **TODO:** Confirm the exact legal rights-holder name before submission.

## Submission Guardrails

- Current scope: month, week, and day views; create, edit, and delete timed or all-day schedules; shift management; work records and statistics; public-holiday subscriptions; optional CloudKit calendar sharing with permission-based recipient event editing; repeatable manual shared-to-personal copying where each run creates an independent local overwrite without ongoing synchronization; Widget support; five UI languages; and local-first storage.
- Do not add claims about account sign-in, developer-operated general cloud sync, unrestricted collaborative editing, private-field sharing, automated recommendations, per-category sharing switches, or other unimplemented features. Events, shifts, and work records assigned to an owned shared calendar synchronize automatically. Recipients can edit events only when the owner allows it and their iCloud permission is read-write; shifts and work records remain view-only for recipients.
- Do not describe TimeNest as ad-free for everyone. TimeNest displays Google Mobile Ads for users who have not purchased Remove Ads and includes a one-time Remove Ads In-App Purchase through Apple StoreKit.
- **TODO:** Reconfirm banner behavior, Remove Ads purchase/restore behavior, and Widget inclusion against the exact submitted build.
- **TODO:** Draft and review Traditional Chinese (`zh-Hant`) App Store metadata before enabling that App Store Connect product-page locale. This TODO concerns App Store product-page metadata only; the app already includes a Traditional Chinese UI.
- **TODO:** Manually publish and verify the CloudKit-sharing updates on the Privacy Policy and Support URLs; their public HTML sources are not in this repository.

## Japanese (`ja`) - Primary

### App Name

TimeNest

### Subtitle

予定・シフト・勤務をひとつに

### Promotional Text

月・週・日のカレンダーで、予定、シフト、勤務記録、祝日をまとめて確認。毎日の時間管理をシンプルにします。

### Description

TimeNest は、予定、シフト、勤務記録をひとつにまとめて管理できる、ローカル優先のカレンダーアプリです。

月表示、週表示、日表示を切り替えながら予定を確認し、通常の予定と終日の予定を追加・編集・削除できます。シフトの登録、出退勤や休憩時間などの勤務記録、期間を指定した勤務統計にも対応しています。

公開 HTTPS ICS を利用した日本、中国、台湾、韓国、米国の祝日購読に対応。日本語、簡体字中国語、繁体字中国語、英語、韓国語から表示言語を選択できます。ユーザーが作成した予定、シフト、勤務記録は基本的に端末内に保存され、ウィジェットでも端末内のカレンダー情報を確認できます。

主な機能:
- 月・週・日のカレンダー表示
- 通常・終日予定の追加、編集、削除
- シフトの登録と管理
- 出退勤、休憩時間などの勤務記録
- 期間を指定した勤務統計
- 日本、中国、台湾、韓国、米国の祝日購読
- カレンダー情報を確認できるウィジェット
- 日本語、簡体字中国語、繁体字中国語、英語、韓国語の表示
- ユーザー作成データのローカル優先保存
- iCloudを利用したカレンダー共有（予定は権限に応じて編集可能、シフトと勤務記録は共有相手側では閲覧のみ）
- 共有カレンダーからマイカレンダーへの手動コピー（後から再度実行でき、実行ごとに対象を上書きする独立したローカルコピーとなり、継続的な同期関係は作成されません）

### Keywords

カレンダー,予定,シフト,勤務,勤怠,祝日,スケジュール,月表示,週表示,統計

## Simplified Chinese (`zh-Hans`)

### App Name

TimeNest

### Subtitle

日程、班次与工作记录

### Promotional Text

通过月、周、日视图统一查看日程、班次、工作记录和节假日，让每天的时间安排更清晰。

### Description

TimeNest 是一款本地优先的日历 App，可集中管理日程、班次与工作记录。

你可以在月、周、日视图之间切换，新增、编辑和删除普通日程或全天日程；还可以录入班次，记录上下班与休息时间，并按所选日期范围查看工作统计。

TimeNest 支持通过公开 HTTPS ICS 来源订阅日本、中国大陆、台湾、韩国和美国的节假日，并提供日语、简体中文、繁体中文、英语和韩语界面。用户创建的日程、班次和工作记录默认保存在设备本地，也可通过小组件查看设备上的日历信息。

主要功能：
- 月、周、日日历视图
- 新增、编辑和删除普通日程与全天日程
- 班次录入与管理
- 上下班、休息时间等工作记录
- 指定日期范围的工作统计
- 日本、中国大陆、台湾、韩国和美国节假日订阅
- 日历小组件
- 日语、简体中文、繁体中文、英语和韩语界面
- 用户创建数据优先保存在本地
- 通过 iCloud 共享日历（日程可按权限编辑，班次和工作记录在接收方仅供查看）
- 将共享日历手动复制到我的日历（可在以后再次执行；每次都会以独立的本地副本覆盖所选范围，且不建立持续同步关系）

### Keywords

日历,日程,班次,工时,考勤,节假日,计划,月视图,周视图,统计

## English (`en`)

### App Name

TimeNest

### Subtitle

Calendar, Shifts & Work

### Promotional Text

Keep schedules, shifts, work records, and public holidays together across month, week, and day views.

### Description

TimeNest is a local-first calendar app that brings schedules, shifts, and work records together.

Switch between month, week, and day views. Create, edit, and delete timed or all-day events, manage shifts, record clock-in, clock-out, and break details, and review work statistics for a selected date range.

Subscribe to supported public HTTPS ICS holiday sources for Japan, mainland China, Taiwan, Korea, and the United States. Use TimeNest in Japanese, Simplified Chinese, Traditional Chinese, English, or Korean. User-created schedules, shifts, and work records are stored on the device by default, and the Widget can display calendar information shared locally by the app.

Key features:
- Month, week, and day calendar views
- Create, edit, and delete timed or all-day events
- Shift entry and management
- Clock-in, clock-out, break, and other work records
- Work statistics for a selected date range
- Public-holiday subscriptions for Japan, mainland China, Taiwan, Korea, and the United States
- Calendar Widget
- Japanese, Simplified Chinese, Traditional Chinese, English, and Korean UI
- Local-first storage for user-created data
- iCloud calendar sharing with permission-based recipient event editing; shifts and work records remain view-only for recipients
- Repeatable manual copy from a shared calendar to My Calendar; each run independently overwrites the selected target scope and establishes no ongoing synchronization

### Keywords

calendar,schedule,shift,work,holiday,planner,timesheet,month,week,statistics

## Korean (`ko`)

### App Name

TimeNest

### Subtitle

일정, 교대 근무와 근무 기록

### Promotional Text

월/주/일 보기에서 일정, 교대 근무, 근무 기록과 공휴일을 한곳에서 확인하세요.

### Description

TimeNest는 일정, 교대 근무와 근무 기록을 한곳에서 관리할 수 있는 로컬 우선 캘린더 앱입니다.

월/주/일 보기를 전환하면서 일반 일정과 종일 일정을 추가, 편집, 삭제할 수 있습니다. 교대 근무를 입력하고 출퇴근 및 휴게 시간을 기록하며, 선택한 기간의 근무 통계를 확인할 수 있습니다.

공개 HTTPS ICS를 이용해 일본, 중국 본토, 대만, 한국, 미국의 공휴일을 구독할 수 있습니다. 일본어, 중국어 간체, 중국어 번체, 영어, 한국어 UI를 지원합니다. 사용자가 만든 일정, 교대 근무와 근무 기록은 기본적으로 기기에 저장되며, 위젯에서 앱이 로컬로 공유한 캘린더 정보를 확인할 수 있습니다.

주요 기능:
- 월/주/일 캘린더 보기
- 일반 일정과 종일 일정 추가, 편집, 삭제
- 교대 근무 입력 및 관리
- 출퇴근, 휴게 시간 등의 근무 기록
- 선택한 기간의 근무 통계
- 일본, 중국 본토, 대만, 한국, 미국 공휴일 구독
- 캘린더 위젯
- 일본어, 중국어 간체, 중국어 번체, 영어, 한국어 UI
- 사용자 생성 데이터의 로컬 우선 저장
- iCloud 캘린더 공유(일정은 권한에 따라 편집 가능, 근무조와 근무 기록은 받은 사용자에게 보기 전용)
- 공유 캘린더에서 내 캘린더로 수동 복사(나중에 다시 실행할 수 있으며, 실행할 때마다 대상 범위를 덮어쓰는 독립적인 로컬 사본을 만들고 지속적인 동기화 관계는 설정하지 않음)

### Keywords

캘린더,일정,교대,근무,출퇴근,공휴일,플래너,월간,주간,통계

## Release Notes Candidates

### Japanese (`ja`)

このバージョンでは、月・週・日のカレンダー、通常・終日予定の管理、シフトと勤務記録、勤務統計、祝日購読、権限に応じた予定編集に対応するカレンダー共有、共有内容のマイカレンダーへの手動コピー、ウィジェット、多言語表示に対応しています。コピーは後から再度実行でき、実行ごとに独立したローカル上書きとなり、継続的な同期関係は作成されません。

### Simplified Chinese (`zh-Hans`)

此版本支持月、周、日日历视图，普通日程与全天日程管理，班次与工作记录，工作统计，节假日订阅，按权限编辑日程的日历共享，将共享内容手动复制到我的日历，小组件和多语言界面。复制可在以后再次执行；每次都是独立的本地覆盖，且不建立持续同步关系。

### English (`en`)

This version includes month, week, and day calendar views, timed and all-day event management, shifts, work records and statistics, holiday subscriptions, calendar sharing with permission-based event editing, manual copying from a shared calendar to My Calendar, Widgets, and a multilingual UI. The copy can be run again later; each run is an independent local overwrite and establishes no ongoing synchronization.

### Korean (`ko`)

이번 버전에서는 월/주/일 캘린더, 일반 및 종일 일정 관리, 교대 근무와 근무 기록, 근무 통계, 공휴일 구독, 권한에 따른 일정 편집이 가능한 캘린더 공유, 공유 내용을 내 캘린더로 수동 복사하는 기능, 위젯, 다국어 UI를 지원합니다. 복사는 나중에 다시 실행할 수 있으며, 실행할 때마다 독립적인 로컬 덮어쓰기로 처리되고 지속적인 동기화 관계는 설정되지 않습니다.
