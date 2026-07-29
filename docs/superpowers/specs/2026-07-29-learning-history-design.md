# Russian Corner 学习记录设计

## 目标

在不干扰悬浮练习卡主流程的前提下，为真实 macOS 应用增加一个可从练习卡直接打开的独立「学习记录」窗口。窗口使用本地持久化数据呈现今日完成、连续学习、今日正确率、掌握内容、话题覆盖和近七天学习报告。

## 输入与证据

- 核心复习事件与掌握度：`ProgressRepository`
- 试用会话、交互、反馈与开口活动：`TrialDataStoring`
- 内容与话题映射：`ContentCatalog`
- 当日真实队列目标：`PracticeViewModel.totalCount`
- 已有进度入口与窗口：`RussianCornerProgressView`、`Window(id: "progress")`

现有数据仍保存在：

- `~/Library/Application Support/com.openclaw.russiancorner/RussianCorner.store`
- `~/Library/Application Support/com.openclaw.russiancorner/RussianCornerTrial.store`

本功能不新建云端、账号、遥测或外部发布。

## 范围

1. 在练习卡页眉增加带图标与文字的「记录」按钮。
2. 点击按钮打开独立学习记录窗口，并把应用置前。
3. 今日完成显示 `已完成 / 今日目标` 与进度条。
4. 今天尚未练习时，连续学习延续到昨天并显示「今日待续」。
5. 今日正确率同时显示正确次数与作答次数。
6. 掌握数量拆分为单词和句子，不再统一标成“句”。
7. 话题覆盖显示数量及真实话题名称。
8. 近七天固定生成七个自然日，包含无学习记录的日期。
9. 逐日显示完成数、目标、正确率、作答数和学习时长；趋势区用原生 SwiftUI 图形实现，无外部依赖。
10. 保留菜单栏入口，并统一命名为「学习记录」。

## 排除项

- 不修改 `/Users/Openclawworkspace/workspace/russian-corner-landing/`。
- 不迁移或重写现有存储。
- 不虚构缺失的历史目标；历史目标优先使用当天首次会话的起始队列，缺失时显示当前日目标或明确为 0。
- 不在本轮改变每日新词调节规则。现有代码已经根据积压、低正确率与连续强表现调整新词量，本功能只负责把历史数据可视化。
- 不联网、不部署、不发布。

## 数据模型

新增 `LearningHistorySnapshot`，包含：

- `todayCompleted`
- `todayTarget`
- `streakDays`
- `needsPracticeToday`
- `todayCorrectCount`
- `todayAttemptCount`
- `masteredLexemeCount`
- `masteredSentenceCount`
- `coveredTopics`
- `totalTopicCount`
- `recentDays`

`DailyLearningRecord` 固定对应一个自然日，包含：

- `day`
- `completedCount`
- `targetCount`
- `correctCount`
- `attemptCount`
- `studyDurationSeconds`
- `topicIDs`

聚合规则：

- 完成数按当天评分成功的唯一 `PracticeItemIdentity` 计数。
- 正确率按所有评分事件计算，`again` 为错误，`hard/easy` 为正确。
- 连续学习先从今天开始；今天无记录时从昨天开始，因此不会把已有连续记录错误清零。
- 掌握度 `>= 3` 视为掌握，单词与句子分别统计。
- 话题由句子事件的 `topicID` 映射到 `TopicDefinition`。
- 每日目标优先取当天最早会话的 `startQueueCount`；今天再与当前队列目标取较可信值。
- 学习时长合计当天会话的 `durationMs`。

## 界面

窗口建议尺寸为 820 × 720，可滚动：

- 顶部：标题、日期、刷新状态。
- 第一层：四张摘要卡，分别是今日完成、连续学习、正确率、已掌握。
- 第二层：近七天完成趋势，每天一根完成比例柱，下方有逐日明细。
- 第三层：话题覆盖标签，真实显示已覆盖话题。
- 数据为空时显示友好的真实空状态，不放示意数字。

视觉继承当前应用，同时学习 Fable 的优点：统一暖色纸面、深色文字、砖红强调、稳定网格与明确数字层级；不复制 Fable 源码或改动其文件。

## 错误处理

- 核心进度读取失败：保留上一次快照并显示明确错误。
- 试用历史读取失败：核心摘要仍可使用，七日会话时长显示为 0，并提示“部分历史暂不可用”。
- 打开窗口不触发任何写入。

## 完成与验证

- 单元测试覆盖七日补空、今日目标、连续学习延续、正确率、掌握拆分和话题映射。
- 入口回调有静态契约测试，按钮有明确无障碍标签。
- `swift test` 全量通过。
- `Scripts/build-app.sh` 成功构建本地应用。
- 使用测试数据或真实本地数据打开窗口，保存截图并检查按钮、窗口、数据层级、趋势和空状态无遮挡。

