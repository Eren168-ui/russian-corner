# Russian Corner 最终验收记录

本记录绑定代码提交 `185e0151c9be94aac848def51f963c3ec5a36afb`
（`fix: publish app bundles atomically`）。验收在该提交内容上执行，时间为
2026-07-26 05:07–05:09 CST。

## 验收环境

- 分支：`feature/russian-corner-mvp`
- App：`dist/Russian Corner.app`
- macOS：26.3.1 (25D771280a)
- Swift：Apple Swift 6.3.3，target `arm64-apple-macosx26.0`
- App 大小：2720 KiB（`du -sk`）

## 自动验收结果

### 1. 严格警告测试

```bash
swift test -Xswiftc -warnings-as-errors
```

结果：通过。执行 136 个 XCTest，0 failures，0 unexpected；Swift Testing
的空测试集也正常结束。

### 2. Core 资源加载回归

严格测试中的 29 个 `ContentCatalogTests` 全部通过，覆盖：

- 从 `#filePath` 构造显式测试资源目录；
- 显式目录加载 360 个词和 72 个句子；
- 资源缺失明确失败，不会外读其他目录；
- production bundle 只选择 `Bundle.main.resourceURL`；
- bare binary 可使用环境变量或当前目录下的开发资源。

### 3. 原子发布与路径安全

```bash
bash Tests/Packaging/build-app-atomicity.sh
bash Tests/Packaging/build-app-safety.sh
```

结果：

```text
codesign_failure_preserves_old_app=PASS
concurrent_build_rejected=PASS
dist_swap_external_sentinel_safe=PASS
publish_failure_restores_old_dist=PASS
build_app_symlink_safety=PASS
```

覆盖的失败边界包括：

- 注入的 `CODESIGN_BIN` 签名失败不会替换旧 App；旧 executable SHA、
  sentinel 和有效签名均保持不变；
- 仓库根目录的原子 `mkdir` 锁拒绝第二个并发构建；
- 构建期间将 `dist` 换成外部目录 symlink，外部 sentinel 不变，发布结果
  仍为仓库内真实目录；
- 旧 `dist` 移入可信根目录备份后注入发布失败，trap 会恢复旧 `dist`；
- 每个失败用例结束后 `.build-app-stage.*`、`.build-app-backup.*` 和
  `.build-app.lock` 数量均为 0。

### 4. bash / zsh 与真实打包

```bash
bash -n Scripts/build-app.sh
zsh -n Scripts/build-app.sh
zsh Scripts/build-app.sh
bash Scripts/build-app.sh
```

四项均通过。代码提交后又执行一次 `bash Scripts/build-app.sh`，输出：

```text
copied_executable_sha256=60c3925f44034e5a42c2337f91588fb35292232f168d7f1d681a18bdebc9ff8c
resource_probe=PASS lexemes=360 sentences=72 directory=.../Contents/Resources
missing_resource_probe=PASS
permissions=PASS resources=0755 executable=0755 json=0644
resource_sha256=PASS lexemes=8ba11a40227ce02b09a698d0b475487513d400d3f3255c972e65fc67cc18098e sentences=c950c3adafd19a39aa4e028c160b44c5e44082fb441c661fe08285f41f750ba3
```

脚本先在仓库根目录的独立 staging 中构造、探针检查和签名完整
`new-dist`，验证成功后才通过 `/bin/mv -h` 发布整个 `dist`。最终检查结束
后才删除旧备份。

### 5. Executable 身份与无 fallback

脚本在签名前比较 SwiftPM release executable 和 staged executable 的 raw
SHA-256；本次两者均为：

```text
60c3925f44034e5a42c2337f91588fb35292232f168d7f1d681a18bdebc9ff8c
```

ad-hoc `codesign` 会重写 Mach-O 内嵌签名，因此最终 executable SHA-256 为：

```text
d0139304539b694ab26bfab8e48baf2b2b2676014d94875f21c843e2bcbc6234
```

对最终 executable 执行 `strings` 检查，仓库绝对路径和
`RussianCorner_RussianCornerCore.bundle` / `.build/...bundle` fallback
字符串匹配数均为 0。

### 6. JSON、Plist、签名、权限与结构

源文件、staging 和最终 App 的 JSON SHA 在脚本中逐阶段比较。最终复核：

```text
lexemes.json   8ba11a40227ce02b09a698d0b475487513d400d3f3255c972e65fc67cc18098e
sentences.json c950c3adafd19a39aa4e028c160b44c5e44082fb441c661fe08285f41f750ba3
```

源文件与最终 App 对应文件的 SHA 完全一致。其他结果：

```text
Info.plist: OK
codesign: valid on disk; satisfies its Designated Requirement
Identifier=com.openclaw.russiancorner
Signature=adhoc
Contents=0755 Resources=0755 executable=0755 JSON=0644
Mach-O 64-bit executable arm64
packaging_scratch_count=0
```

`Contents/Resources` 只含 `lexemes.json` 和 `sentences.json`。

### 7. 启动烟雾测试

```bash
open -n "dist/Russian Corner.app"
sleep 5
pgrep -f '/Russian Corner.app/Contents/MacOS/RussianCornerApp'
```

2026-07-26 05:08:55 CST 的结果：PID `24842` 在启动 5 秒后仍运行。
启动前后 10 分钟窗口中的 `RussianCornerApp*.crash` /
`RussianCornerApp*.ips` 文件数均为 0。

### 8. 仓库边界

`git diff --check` 通过。验收文档没有未决占位内容。
原始 Obsidian 语料哈希复核方法与只读基线保存在
`Verification/source-corpus-baseline.txt`。

## 人工硬件验收边界

以下项目未由本次自动化验收覆盖，本文不宣称已经通过：

- 麦克风首次授权、拒绝后的继续练习、录制、播放、保存和实际音质；
- 通知首次授权、拒绝路径及 11:30 / 17:30 的真实送达；
- 本机 `ru-RU` 语音选择和朗读效果；
- 9 个全局快捷键与目标 Mac 已安装软件之间的冲突；
- 多显示器移动、四角吸附、Retina 与不同缩放比例下的显示。
