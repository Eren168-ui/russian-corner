# Russian Corner 最终验收记录

本记录保存 2026-07-26 在 `feature/russian-corner-mvp` 分支上的 Task 6 实测结果和最终集成重跑方法。本次修复提交的 SHA 在提交后用 `git rev-parse HEAD` 获取；主 Agent 合并其他交付物后需在最终提交状态完整重跑本文命令。

## 验收环境

- App：`dist/Russian Corner.app`
- macOS：26.3.1 (25D771280a)
- Swift：Apple Swift 6.3.3，target `arm64-apple-macosx26.0`
- 实测时间：2026-07-26 04:38–04:48 +0800
- App 大小：2720 KiB（`du -sk`）

## 当前自动验收结果

### 1. 严格警告测试

```bash
swift test -Xswiftc -warnings-as-errors
```

结果：通过。执行 136 个 XCTest，0 failures，0 unexpected；Swift Testing 的空测试集也正常结束。

### 2. Core 资源加载回归

```bash
swift test --filter ContentCatalogTests
```

结果：通过。29 个测试验证：

- 测试从 `#filePath` 构造显式源码资源目录；
- 显式资源目录加载 360 个词和 72 个句子；
- 资源缺失明确抛出 `missingResource("lexemes")`，不会外读其他目录；
- production bundle 只选择 `Bundle.main.resourceURL`；
- bare binary 可使用环境变量或当前目录下的源码资源。

### 3. 打包路径安全

```bash
bash Tests/Packaging/build-app-safety.sh
```

结果：`build_app_symlink_safety=PASS`。测试分别把沙箱仓库的 `dist` 和 `dist/Russian Corner.app` 指向外部目录；脚本均在 build 和删除前明确拒绝，外部 sentinel 保持不变。

### 4. bash / zsh、幂等打包与资源探针

```bash
bash -n Scripts/build-app.sh
zsh -n Scripts/build-app.sh
bash Scripts/build-app.sh
zsh Scripts/build-app.sh
```

当前 bash 实测输出：

```text
copied_executable_sha256=60c3925f44034e5a42c2337f91588fb35292232f168d7f1d681a18bdebc9ff8c
resource_probe=PASS lexemes=360 sentences=72 directory=.../Contents/Resources
missing_resource_probe=PASS
permissions=PASS resources=0755 executable=0755 json=0644
```

主 Agent 在最终提交上再次运行 bash 与 zsh 两轮；两次都必须成功并产生相同类别的证据。

### 5. Executable 身份与无 fallback

脚本在复制后、签名前对 SwiftPM release executable 和 app 内 executable 计算 raw SHA-256，并在不相等时立即失败。当前复制 SHA-256 为：

```text
60c3925f44034e5a42c2337f91588fb35292232f168d7f1d681a18bdebc9ff8c
```

最终 ad-hoc `codesign` 会按 macOS 机制重写 Mach-O 内嵌签名，因此签名后的 app executable raw SHA 会变化；当前签名后 SHA-256 为：

```text
d0139304539b694ab26bfab8e48baf2b2b2676014d94875f21c843e2bcbc6234
```

无编译路径和 SwiftPM 资源 fallback 检查：

```bash
repo_root=$(pwd -P)
! strings .build/arm64-apple-macosx/release/RussianCornerApp |
  grep -F "$repo_root"
! strings .build/arm64-apple-macosx/release/RussianCornerApp |
  grep -E '\.build/.+RussianCorner_RussianCornerCore\.bundle|RussianCorner_RussianCornerCore\.bundle'
```

结果：两项匹配数均为 0。

### 6. Plist、签名、权限与资源结构

```bash
plutil -lint "dist/Russian Corner.app/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "dist/Russian Corner.app"
stat -f '%Lp %N' \
  "dist/Russian Corner.app/Contents/Resources" \
  "dist/Russian Corner.app/Contents/MacOS/RussianCornerApp" \
  "dist/Russian Corner.app/Contents/Resources/"*.json
find "dist/Russian Corner.app/Contents/Resources" -maxdepth 1 -type f -print | sort
```

结果：plist OK；app valid on disk 且 satisfies its Designated Requirement；Resources 为 0755，executable 为 0755，两个 JSON 均为 0644；资源目录只含 `lexemes.json` 和 `sentences.json`。

### 7. 启动烟雾测试

```bash
open "dist/Russian Corner.app"
sleep 5
pgrep -fl '/Russian Corner.app/Contents/MacOS/RussianCornerApp$'
find "$HOME/Library/Logs/DiagnosticReports" \
  -maxdepth 1 -type f -name 'RussianCornerApp*' -mmin -10 -print
```

当前结果：等待 5 秒后 PID 9913 仍运行，本次启动 10 分钟窗口内没有 `RussianCornerApp` 崩溃报告。主 Agent 在最终提交生成的 app 上重跑并记录新的 PID。

### 8. 仓库边界

```bash
git diff --check
git status --short
```

验收要求：验收记录无未决占位内容，diff 无空白错误；最终提交后 worktree clean。原始 Obsidian 语料哈希复核方法与只读基线保存在 `Verification/source-corpus-baseline.txt`。

## 人工硬件验收边界

以下项目由主 Agent 或目标 Mac 使用者在真实硬件上确认，自动化结果不替代人工结论：

- 麦克风首次授权、拒绝后的可继续练习、录制、播放、保存和实际音质；
- 通知首次授权、拒绝路径及 11:30 / 17:30 的真实送达；
- 本机 `ru-RU` 语音选择和朗读效果；
- 9 个全局快捷键与目标 Mac 已安装软件之间的冲突；
- 多显示器移动、四角吸附、Retina 与不同缩放比例下的显示。
