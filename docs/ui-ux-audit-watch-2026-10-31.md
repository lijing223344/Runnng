# PaceCoach Watch App UI/UX 审计报告

- **日期**：2026-10-31
- **分支**：feature/apple-watch @ fff167b
- **范围**：PaceCoach Watch App（watchOS target：Home / TrainingLaunch / PaceRun / Interval 四屏 + WDS 设计系统 + 连接/存储/声音/触觉）
- **方法**：全量源码走查（1127 行视图 + WDS/Models）× watchOS 模拟器视觉走查
- **前置**：iOS 端 A/B/C 已实施（fff167b）；本报告为其同分支续篇
- **状态**：静态分析完成；视觉走查见 §3（watchOS 运行时安装后补充）

---

## 1. 总体评价

Watch 端是一个**克制且正确**的伴生实现：

- `WDS` 设计系统与 iOS `DS` 同源（同色值/同圆角/同深黑主题），字号按表盘比例缩放（countdownHero 56 / timerLarge 32），方向正确。
- 训练视图信息层级清晰：相位标签 → 大计时 → 次数/组数 + ProgressView → 暂停/停止，符合「抬腕 1 秒可读」的 glanceable 原则。
- HealthKit WorkoutSession/LiveWorkoutBuilder 正确接入；scenePhase 回前台恢复 tick；0.1s tick + maxStateTransitionsPerTick 溢出保护是健壮的。
- 完成态/空态/同步失败态都有明确视觉表达。

**核心问题**：视觉层面主要是**与 iOS 端的语义色彩不一致**与**倒计时/完成页的上下文缺失**；无阻塞级缺陷。

---

## 2. 静态审计发现

### W1（P1）休息相位语义色与 iOS 不一致
- Watch：休息 = `WDS.Colors.success`（绿）——与「完成 ✓」同一绿色，语义混用；iOS 端休息为中性灰白（节奏跑）/ 令牌 `DS.Colors.rest`（倒计时冷色）。
- 建议：`WDS.Colors` 增加 `rest`（与 iOS 新增令牌同值 `(0.20, 0.78, 0.95)`），`phaseColor` 的 `.resting/.setRest` 改用 `rest`；完成页保留 `success` 绿。涉及 `WatchIntervalView.swift:143-149`、`WatchPaceRunView.swift` 对应处。

### W2（P1）暂停按钮固定用 interval 橙
- `WatchIntervalView.swift:116` 暂停 `.tint(WDS.Colors.interval)`、`WatchPaceRunView` 用 `currentAccent`——间歇橙在间歇上下文正确，但 iOS 端暂停态已统一为 `warning` 琥珀（Phase B1）。建议 Watch 同步：暂停/继续 → `WDS.Colors.warning`，保持「暂停=琥珀」跨端一致。

### W3（P2）倒计时页无计划上下文
- `WatchIntervalView.countdownView` / `WatchPaceRunView` 对应视图：只有孤零零数字（iOS 端 C1 已补计划名+组数+域色数字）。Watch 空间小，建议最小实现：计划名（caption）+ 数字用域色 `currentAccent`。

### W4（P2）启动页摘要未展示总时长
- `WatchTrainingLaunchView.decodedInfo`：「2 组 | 800米」。跑步前最有用的是**总时长**（组数×次数×单次时长已在 configData 里）。建议追加 `| 4'00"`。

### W5（P2）完成页无训练统计
- `completedView`：只有「训练完成」+ 大绿勾。建议追加实际用时/完成次数（`elapsedTotal` 已在状态里），让用户摘表前有闭环感。

### W6（P2）本地化键核对
- `watch_no_plans/watch_sync/watch_start/watch_running/watch_resting/watch_rep/watch_set/watch_stop_confirm/watch_training_complete/groups_count/reps_short` 均需确认在 Watch target 的两份 `.strings` 中存在（模拟器走查时以中/英各验一遍）。

### 观察项（不改）
- Watch 端无「下一段」预告——表盘空间有限，现有相位+计时+进度已够用；若用户反馈需要，可加一行 `下次 · 第 N 次`（caption 尺寸）。
- `SavedPlan.trainingType` 只有 pace/interval 两类，400米模型生成的计划在 iPhone 端本就是 PaceRun 类型，同步到 Watch 归类正确，无缺口。
- 空态引导「iphone.and.arrow.forward」图标语义准确（需 iPhone 推送）。

---

## 3. 视觉走查（watchOS 模拟器）

> 环境：watchOS 27.2 运行时 + Apple Watch Series 12 (46mm) 模拟器，中文环境。因无 iPhone 配对，采用「从 iPhone 模拟器容器提取 `saved_plans` → 写入 Watch 容器 `watch_saved_plans`」方式注入两条真实计划（800m 节奏跑 / 200m×6 间歇训练）完成全流程走查。截图：`output/ui-audit/screens/W01–W08`。

| 屏 | 截图 | 结论 |
|---|---|---|
| 首页·计划列表 | W01 | 卡片行点色+类型标注清晰，行高/触达达标；**导航标题「PaceCoach」被系统 tint 染成域蓝**（见 W7） |
| 节奏跑启动页 | W02 | 摘要「1 组 \| 800m」确认缺总时长（W4）；开始按钮大且居中 ✓ |
| 倒计时 | W03 | 裸数字白「3」确认 W3；背后透出的启动页残影为 fullScreenCover 系统行为，可接受 |
| 节奏跑训练中 | W04 | 相位标签蓝/大计时白/进度条蓝，结构 ✓；无配对时状态栏断连图标正常 |
| 停止确认 | W05 | 标准 watchOS alert，红色破坏性按钮 ✓ |
| 间歇启动页 | W06 | 橙色域一致 ✓ |
| 间歇训练·跑步 | W07 | 橙色相位+进度填充 ✓ |
| 间歇训练·休息 | W08 | **实锤 W1**：休息态「休息中」与进度条均为 success 绿，与完成态语义冲突 |

**新增发现**：

- **W7（P2）**：Watch 导航标题继承系统 tint（首页蓝/间歇橙）。与 iOS 端白色大标题策略不一致；建议首页标题固定白色，计划详情标题可保留域色（有辨识价值）。涉及 `WatchHomeView.navigationTitle` 处 tint 定制。
- **W8（P2）**：倒计时覆盖层底部隐约透出下层视图（fullScreenCover 默认压暗）。当前观感尚可，列为观察项不改动。

---

## 4. 实施状态（2026-10-31 当日完成，用户批准 W1-W7）

| # | 结果 | 证据 |
|---|---|---|
| W1 休息色 → rest 青色 | ✅ 已实施（间歇+配速两视图，新增 `WDS.Colors.rest`） | W12：休息态青色标签+进度条 |
| W2 暂停 → warning 琥珀 | ✅ 已实施（两视图控制区） | W12 暂停按钮琥珀 |
| W3 倒计时计划名+域色数字 | ✅ 已实施 | W11：「200m×6 间歇训练」+ 橙色大 3 |
| W4 启动页总时长 | ✅ 已实施（配速 Σ totalTime×组数；间歇 Σ run+rest+组间休息） | W10：「1 组 \| 800m \| 4:00」 |
| W5 完成页实际用时 | ✅ 核实**两侧本已实现**（静态审计读漏，`formatTime(elapsedTotal)` 早已存在）— 无需改动 | 源码 completedView |
| W6 本地化键 | ✅ 中英 15 键逐一核对全绿 — 无需改动 | 双 .strings |
| W7 首页标题白色 | ⚪ **评估后接受现状**：watchOS 大标题取自 target 全局 AccentColor（Assets），视图级 tint 无法覆盖；强改需动全局 tint（波及系统控件）或降级为 inline 标题，代价大于收益。平台惯例下 tinted 标题成立 | W09 |

> 实施注记：全部为视图层改动；构建通过（watchOS 27.2 / Series 12 46mm 模拟器逐项目验）。W8 维持观察项不改。
