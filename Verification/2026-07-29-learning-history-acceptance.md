# 学习记录功能验收

日期：2026-07-29  
范围：仅本地构建与验收，不安装、不发布、不修改落地页项目。

## 自动化验证

- 基线：`swift test`
  - 264 tests
  - 0 failures
  - 1 skipped（真实联网字典测试按设计为 opt-in）
- 实施后：`swift test`
  - 271 tests
  - 0 failures
  - 1 skipped（同一 opt-in 测试）
- 合并到当前 `main` 后：`swift test`
  - 272 tests
  - 0 failures
  - 1 skipped（同一 opt-in 测试）
- Release 构建：`Scripts/build-app.sh`
  - exit code 0
  - `resource_probe=PASS`
  - `missing_resource_probe=PASS`
  - `permissions=PASS`
  - 应用签名 `valid on disk`
  - 应用签名 `satisfies its Designated Requirement`

## 构建产物

`/Users/Openclawworkspace/workspace/russian-corner/dist/Russian Corner.app`

## 实际界面验收

通过本机无障碍树和截图操作 Release 应用：

- [x] 悬浮练习卡页眉出现带文字的「记录」按钮。
- [x] 按钮无障碍名称为「打开学习记录」。
- [x] 点击后打开独立窗口 `Russian Corner 学习记录`。
- [x] 今日完成显示真实分子与目标：`4 / 17`。
- [x] 连续学习显示真实值：`1 天`，且今天已有记录时显示「今天已留下记录」。
- [x] 今日正确率显示 `100%`，并显示 `4 次正确 · 4 次作答`。
- [x] 已掌握拆分为 `单词 0 · 句子 0`，不再误用统一“句”后缀。
- [x] 近七天固定显示 7 个自然日，缺失日期显示 0。
- [x] 七日明细显示完成/目标、正确率、正确/作答数和学习时长。
- [x] 话题覆盖显示真实话题 `城市问路`、`我的大学`，总覆盖 `2 / 32`。
- [x] 页面上下区域滚动可达，无文字或图表裁切。
- [x] 退出应用并重新启动后，今日数据、七日历史和话题覆盖保持一致。
- [x] 页面明确标注数据仅保存在本机。

## 截图

- 顶部摘要与七日趋势：`Verification/2026-07-29-learning-history.png`
- 七日明细与话题覆盖：`Verification/2026-07-29-learning-history-lower.png`

## 结论

PASS。用户要求的六类复盘数据已由真实本地记录驱动，并可从练习卡直接打开独立页面查看。
