# 月扫描 OCR 予定召回：修改与验收记录

调查基线：`52631053f4aef4e0b306c2d467457fdc817096b7`，2026-09-05。
初始工作树干净。本次修改保持在工作树，未执行 commit、push、merge、rebase、reset、clean。

本次产品规则：合理的 Cell 内容先形成可编辑候选；时间解析失败只影响字段与复核状态。
正式 CalendarEvent、SwiftData、CloudKit 和日扫描的解析规则保持原状。

## 实际路径与丢失条件

当前月扫描入口是 `CalendarPhotoImportViewModel.process` 的 `.month` 分支：

`UIImage → 主 Grid 检测与透视校正 → 用户年月/周起始日对应的 Cell → PP-OCR + App 语言 Vision → observation merger → CalendarPhotoGridFirstParser → Candidate Builder → review → saveSelected/makeEvent`。

| 阶段 | 基线行为与调查结论 | 本次处理 |
| --- | --- | --- |
| Grid 检测 | Vision rectangle 的置信度、尺寸、宽高比与主 Grid 选择控制后续 Cell；真实照片没有运行日志，无法判定当前检测出的矩形是否正确 | 保留现有 Grid 算法；已有主 Grid/迷你月历、透视、5/6 行、周起始日测试继续保留 |
| 日期映射 | 用户指定年月、周起始日、7 列及 Cell 行列决定日期；有效 Cell 外不创建普通候选 | 保留；页面时间模板也只使用有效 Cell 内 observations |
| PP-OCR detection | `detectionThreshold=0.20`、`detectionBoxThreshold=0.35`，以及轮廓、最小边长、裁剪等条件可使浅色文字没有 detection | 未盲目降低阈值；零检测不能靠 Candidate Builder 恢复，需真机原图确认 |
| PP-OCR recognition | `textScore=0.30` 以下且未恢复合法时间的结果，以及空识别文字，不进入 `textResults` | 保留已被 detector 接受的区域；低置信度/空识别进入复核候选路径 |
| PP-OCR router | 技术失败按 Cell 使用 Vision fallback；成功结果转换为全图归一化 observation | 保留原 route；增加原始/替代文字与复核标记传递 |
| Cell 放大重试 | 当前调用点传入 `scaledCGImage` 和整图 region，override 与 crop 都是放大后尺寸；不能仅凭尺寸相等 guard 判定重试失效 | 保留现有 1x/2x/3x 重试及归一化坐标实现，运行效果待真机确认 |
| Vision | 无 top candidate 的 recognized-text observation 被 `compactMap` 删除 | 月 Cell 识别保留其 bounds 和空文本，标记复核；日扫描保持原默认行为 |
| PP-OCR/Vision 合并 | PP-OCR 普通标题在无 Vision 标题时仍被丢弃；Vision 无字母的符号/时间/残缺数字被丢弃 | 同一物理行优先采用 Vision 标题；保留没有对应替代内容的 PP-OCR、Vision 时间和符号；原文独立传递 |
| 印刷过滤 | 旧日期过滤主要依赖 OCR 数字等于 Cell 日期及位于上部；恢复无时间候选后，原本失效的节假日输入需要真正参与过滤 | 使用日期小框位置/尺寸，顶部印刷带 + 同日缓存节假日精确匹配，及贴边细长边框形状；过滤原因与原文进入 diagnostics |
| 行/予定分组 | 相邻相似时间可能当成重复证据；无时间尾行被拒绝，时间损坏的第一条也可能混入后面的标题 | 不同上下行保留独立组；只有物理重叠的时间 evidence 才合并；损坏时间结束自己的组；有空间依据时合并标题与时间 |
| Candidate Builder | `guard ... let rawTime ... else { continue }` 使是否存在予定取决于时间解析成功；`pendingTitleLines` 最终按 `noParsedTime` 拒绝 | 非印刷内容组均生成 Candidate；可空时间字段保留 nil；缺失/低置信度/异常组标记 `needsReview` |
| review/save | 原本 `(nil,nil)` 自动表示全天；`canSave` 与 `makeEvent` 共用合法性检查 | Candidate 层增加 `requiresTimeConfirmation`；未解析时间显示待确认，补齐时间或主动选择全天后才允许保存 |
| 旧 parser | `CalendarPhotoParser.makeCandidates` 仍有开始时间门槛，但当前 `.month` 正式入口不调用它；`applySelectedYearMonth` 没有当前 UI 调用点 | 未改写旧 parser；不将它的历史测试视为当前 PP-OCR 月路径的验证 |

短标题、普通数字、圆圈、序号和低置信度均不作为通用删除依据。
低信息数字/符号候选沿用 `quality=lowInformation` 的默认不勾选行为，仍留在结果列表供用户编辑与选择。
完整范围优先、合法时间范围、紧凑数字歧义保护、现有时间恢复/评分规则继续保留。

## 不完整候选与分组

- 完整时间：填入已解析值；标题不可靠、恢复时间或低置信度仍提示复核。
- 仅开始时间：结束时间为 nil；扫描过程不生成默认结束时间。
- 无时间：`startTimeMinutes/endTimeMinutes=nil`，`requiresTimeConfirmation=true`，`needsReview=true`。
- 确认页可编辑日期、标题、时间并查看 `originalText`。仅点击“已确认”不能把无时间状态变成全天。
- 用户主动选择全天后，才通过现有全天 Event 保存路径；补齐合法时间也可保存。
- 每组保留原始 OCR 文字及替代识别文字；标题清理只改变 title，不删除 raw evidence。
- 上下独立时间行，即使时间相同或仅差一个数字，也保留多条候选。同一位置的 OCR 替代识别避免重复候选。
- 时间格式损坏的行与其相邻标题可组成不完整候选；不会吞进下一条有合法时间的予定。
- 两条独立纯标题行在关系不明确时分别保留。时间下方极近、且离下一条时间更远的标题可附着到前一条。

这仍是基于位置与文本的启发式分组。无法从两个引擎均未产生 observation 的像素中生成有依据的予定；一个检测框若把多条内容压成无法区分的单段文字，也需要实际诊断进一步处理。

## 附件照片对应的 fixture

会话照片已目视检查。本地附件目录仅有需求文本，没有可交给本地推理程序的照片文件，也没有本次照片导出的真实 OCR diagnostics。

`testSeptemberPhotoLayoutFixturePreservesTwentySevenAppointmentGroups` 是**人工构造的 observation fixture**：按照片可见的日期/予定布局组织，采用人工坐标和故意损坏的文本。它不是 PP-OCR/Vision 实测输出，不代表 OCR 召回率。

| 日期 | 人工布局预计组数 |
| --- | --- |
| 9/2、9/3、9/6、9/7、9/9、9/10、9/14、9/17、9/24、9/28 | 各 1 |
| 9/4、9/5、9/11、9/12、9/18、9/25、9/26 | 各 2 |
| 9/19 | 3 |
| 其余日期 | 0 |

合计 18 个日期、27 组。此表是人工验收清单；真实纸面分组以用户核对为准。
fixture 特意将 9/4 第二条替换成 `52020.21`、9/7 替换成短标题 `実α`，并将手写内容置信度设为 0.24。
同时加入 30 个小日期框、3 个已知节假日和 Grid 外 header/迷你月历文字。
断言检查各日期组数、9/4 两组、9/19 三组、rawText、needsReview、日期印刷过滤和未分配内容。

## 测试与 diagnostics

在现有 `CalendarPhotoImportTests.swift` 内新增 14 个测试方法，并更新原有拒绝无时间内容、无 Vision 标题 fallback、时间重复/碎片及失败 recovery 的预期。
重复时间测试现在使用重叠框表示同一文本的识别替代；另有独立测试要求不同位置的相同时间产生两个候选。
其余覆盖低置信度/空检测框、Vision 独有时间/符号、原文保存、无时间保存门槛、单开始时间、纯标题、多予定、印刷体过滤原因。

新增 diagnostics 内容：

- `filterReason`、被过滤原文和 bounds。
- `groupedLines`、`appointmentGroup`、`detectedCandidateGroups`。
- `unparsedCandidateGroups`、可空 parsedStart/parsedEnd、`retainedWithoutParsedTime`。
- 原有候选 `needsReview`、confidence、time parse quality、候选时间评分和各 PP-OCR recovery 记录继续可见。

`rejectedNoParsedTimeLines` 字段为兼容旧诊断格式保留；新月候选路径不会因解析失败拒绝组，此值为 0。
diagnostics 为应用内已有诊断展示/复制流程使用，未新增联网传输。

## Windows 验证

- `.\Scripts\check-swift-windows.ps1`：160 个 Swift 文件语法检查通过。
- 修改的 Swift 文件 `swiftc -frontend -parse`：通过。
- `git diff --check`：通过。
- 跨文件 `swiftc -typecheck`：未完成，Windows Swift SDK 的 `LibcOverlayShims.h:27` 报 `error: 'errno.h' file not found`，随后 `could not build C module 'SwiftOverlayShims'`。
- 未执行 XCTest。上述语法结果不代表 Xcode Build、SwiftUI 类型检查、ONNX/Vision 运行或真实照片验收通过。

## 待 GitHub Actions / TestFlight 真机验证

1. 在承载本次工作树修改的准确提交上运行现有 iOS CI，分别确认 `CalendarPhotoImportTests`、完整 XCTest 和 Release Simulator Build；记录 run URL、headSha 和实际测试结果。当前基线 SHA 的历史 CI 无法验证本次未提交代码。
2. 使用同一张照片，选 2026/9、日曜日始まり，检查主 Grid 四角/透视结果、30 个 Cell 与日期映射；header/迷你月历不能进入普通 Cell 予定。
3. 按人工表逐日核对，重点 9/4、9/5、9/11、9/12、9/18、9/19、9/25、9/26。不要只对比候选总数；多出噪音不能抵消真实予定漏失。
4. 检查 9/21–23 的印刷节假日。名称依赖已有本地缓存；没有对应缓存或 OCR 错字时，精确匹配可能无法过滤，需记录真实 bounds/文字后判断。
5. 对仍少候选的日期，先看 PP-OCR 原始 detection/识别比较，再看过滤记录、groupedLines、appointmentGroup、候选时间；区分没有检测到、被过滤、被合并和单纯没有解析时间。
6. 在确认页选中一条无时间候选，验证原文可见，补标题/时间后保存；再验证主动选择全天可保存、只标记已确认不能隐式全天保存；验证目标日历、日期和实际 Event 数量。
7. 检查空识别框/铅笔噪音带来的额外候选，及同位置跨引擎重复框是否过度生成。

2x/3x whole-Cell retry 已核对到当前实际调用点：传入放大后的 `scaledCGImage`、整图 region 和相同尺寸的 `scaledCellImage`。现有尺寸 guard 本身不能证明 `invalidCrop`，本次未修改重试路径。仍需在 Apple 平台确认真实重试、归一化框对应原 Cell 的同一行，以及已有合法予定不被另一条的重试结果覆盖。本次候选保留逻辑不依赖重试成功。
