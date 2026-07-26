# Russian Corner

macOS 菜单栏俄语词汇与主动口语训练应用。

Russian Corner 使用审核后的 360 个词汇记录和 72 个句子卡，默认按“A2 已完成、正在冲 B1”筛选新词。应用提供 360×240 的桌面角落卡、按需展开的搭配与场景详情、8 个全局快捷键、俄语朗读、间隔复习、本地提醒、每日反馈、学习诊断和用户可读的 7 天 Markdown 报告。支持 macOS 14 及以上版本。

## 构建

```bash
./Scripts/build-app.sh
open "dist/Russian Corner.app"
```

打包脚本会执行 SwiftPM release 构建，在 `dist/` 中生成 ad-hoc 签名的 `.app`，并验证应用资源、`Info.plist` 与签名。脚本不联网、不安装到 `/Applications`。

开发验证：

```bash
swift test -Xswiftc -warnings-as-errors
```

完整的操作、8 个全局快捷键、隐藏方式、权限、数据位置、报告导出、卸载说明和硬件验收边界见 [Documentation/USAGE.md](Documentation/USAGE.md)。

## 数据与能力边界

- 原始 Obsidian 语料只读；应用只使用独立的、审核后派生词库。
- 核心学习进度与 7 天试用统计分别保存在本机的 `RussianCorner.store` 和 `RussianCornerTrial.store`。
- 两段口述活动只读取实时音量以估算开口时长和长停顿，不录音、不保存音频、不提供回放。
- 7 天报告是给学习者直接阅读的中文 Markdown；导出时由用户在系统保存面板中选择位置。
- 应用不调用 AI 服务，不上传内容，不自动分析或评价发音。
- 删除 `.app` 不会自动删除本地学习数据。
