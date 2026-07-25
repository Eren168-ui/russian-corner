# Russian Corner

macOS 菜单栏俄语词汇与主动口语训练应用。

Russian Corner 使用审核后的 360 个词汇记录和 72 个句子卡，提供角落悬浮练习、全局快捷键、朗读与录音、间隔复习、本地提醒及学习诊断。支持 macOS 14 及以上版本。

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

完整的操作、9 个全局快捷键、权限、数据位置、卸载说明和硬件验收边界见 [Documentation/USAGE.md](Documentation/USAGE.md)。

## 数据与能力边界

- 原始 Obsidian 语料只读；应用只使用独立的、审核后派生词库。
- 学习进度、设置和主动保存的录音留在本机。
- 应用不调用 AI 服务，不上传内容，不自动分析或评价发音。
- 删除 `.app` 不会自动删除学习数据或保存的录音。
