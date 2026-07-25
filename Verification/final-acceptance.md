# Russian Corner 最终验收记录

本文先固定 Task 6 的验收方法。最终集成完成后，由主 Agent 在同一提交状态上运行全部命令，并把日期、提交 SHA、原始输出摘要和人工硬件结果填入下方。

## 验收对象

- Commit SHA：`待最终填写`
- App：`dist/Russian Corner.app`
- macOS / Swift 版本：`待最终填写`
- 验收时间：`待最终填写`

## 自动验收

### 1. 严格警告测试

```bash
swift test -Xswiftc -warnings-as-errors
```

最终结果：`待最终填写`

### 2. 两种 shell、幂等打包与内置资源探针

```bash
bash -n Scripts/build-app.sh
zsh -n Scripts/build-app.sh
bash Scripts/build-app.sh
zsh Scripts/build-app.sh
```

每次打包都必须输出：

```text
resource_probe=PASS ... lexemes=360 sentences=72 bundleIdentifier=com.openclaw.russiancorner reminderBareBinaryFallback=false
```

最终结果：`待最终填写`

### 3. Plist 与签名

```bash
plutil -lint "dist/Russian Corner.app/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "dist/Russian Corner.app"
codesign -d --entitlements :- "dist/Russian Corner.app"
```

最终结果：`待最终填写`

### 4. 启动烟雾测试

先退出其他 Russian Corner 实例，然后运行：

```bash
open "dist/Russian Corner.app"
sleep 3
pgrep -fl '/Russian Corner.app/Contents/MacOS/RussianCornerApp'
```

确认进程没有立即退出，并检查系统崩溃报告中没有本次启动产生的 `RussianCornerApp` 崩溃。

最终结果：`待最终填写`

### 5. 资源与仓库边界

```bash
find "dist/Russian Corner.app/Contents/Resources/RussianCorner_RussianCornerCore.bundle" \
  -maxdepth 1 -type f -print | sort
git status --short
git diff --check
```

资源应只有可用的 `lexemes.json` 与 `sentences.json`；提交前仓库应无意外生成物或空白错误。原始 Obsidian 语料哈希复核方法与基线见 `Verification/source-corpus-baseline.txt`。

最终结果：`待最终填写`

## 人工硬件验收

以下项目不能由当前自动化替代：

- 麦克风首次授权、拒绝后的可继续练习、录制、播放、保存和实际音质；
- 通知首次授权、拒绝路径及 11:30 / 17:30 的真实送达；
- 本机 `ru-RU` 语音选择和朗读效果；
- 9 个全局快捷键与目标 Mac 已安装软件之间的冲突；
- 多显示器移动、四角吸附、Retina 与不同缩放比例下的显示。

人工结果：`待最终填写`
