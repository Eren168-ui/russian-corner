# Russian Corner 最终验收记录

本记录绑定实现提交 `dd5e3e9`（`fix: refresh practice across temporal
boundaries`）。验收覆盖该提交及其之前的全部实现，时间为
2026-07-26 06:56–06:57 CST。

## 验收环境

- 分支：`feature/russian-corner-mvp`
- App：`dist/Russian Corner.app`
- macOS：26.3.1 (25D771280a)
- Swift：Apple Swift 6.3.3，target `arm64-apple-macosx26.0`
- App 大小：3100 KiB（`du -sk`）

## 自动验收结果

### 1. 严格警告测试

```bash
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

结果：通过。执行 187 个 XCTest，0 failures，0 unexpected；Swift Testing
的空测试集也正常结束。

### 2. Core 资源加载回归

严格测试中的 36 个 `ContentCatalogTests` 全部通过，覆盖：

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
lockf_concurrent_build_rejected=PASS
dist_swap_external_sentinel_safe_failure=PASS
publish_failure_restores_old_dist=PASS
unrelated_dist_entries_preserved=PASS
sigkill_transaction_recovered=PASS
persistent_empty_lockfile_nonblocking=PASS
build_app_symlink_safety=PASS
```

覆盖的失败边界包括：

- 注入的 `CODESIGN_BIN` 签名失败不会替换旧 App；旧 executable SHA、
  sentinel 和有效签名均保持不变；
- 当前事务 shell 解析 Git 管理目录中的安全 lockfile，通过
  `exec 9>"$LOCK_FILE"` 打开 FD9，并用系统
  `/usr/bin/lockf -s -t 0 9` 取得排他锁；不经 wrapper、子 shell 或
  command-mode 重执行，两个并发进程只有一个进入 internal build；
- 空 lockfile 会保留在 Git 管理目录中且不会阻塞后续构建；锁由内核随
  进程退出或 SIGKILL 自动释放，不使用 PID、启动时间或 stale-lock 删除；
- staging 先用 `cp -a` 快照真实 `dist`，保留无关 marker 的字节和无关
  symlink 本身，只替换 `Russian Corner.app`；
- 构建期间将 `dist` 换成外部目录 symlink，脚本安全拒绝发布，外部
  sentinel、symlink 和移出的旧 `dist` 均不变；
- 旧 `dist` 移入可信根目录备份后注入发布失败，trap 会恢复旧 `dist`；
- root 内四行事务状态记录 `prepared`、`old_moved`、`new_published`
  阶段、随机 owner token 以及 backup / new-dist 路径；rollback 和状态
  删除前都读回核对 owner token；
- 用户直接启动的首进程在 `old_moved` 后暂停时，第二进程被 `lockf`
  拒绝且事务文件 SHA 不变；测试对用户拿到的 `$!` PID 发送真实
  SIGKILL 后，没有子进程继续发布，也没有遗留 `build-app.sh` 进程；
  后续 shell 随即取得锁、恢复事务并完成新构建；
- 每个失败用例结束后 `.build-app-stage.*`、`.build-app-backup.*` 和
  `.build-app.lock`、`.build-app-transaction` 数量均为 0。

### 4. bash / zsh 与真实打包

```bash
bash -n Scripts/build-app.sh
zsh -n Scripts/build-app.sh
zsh Scripts/build-app.sh
bash Scripts/build-app.sh
```

四项均通过。代码提交后又执行一次 `bash Scripts/build-app.sh`，输出：

```text
copied_executable_sha256=498f6ce3c0676f299ea23bc985db388e64ea5450153513049a3fa3cdad8a0516
resource_probe=PASS lexemes=360 sentences=72 directory=.../Contents/Resources
missing_resource_probe=PASS
permissions=PASS resources=0755 executable=0755 json=0644
resource_sha256=PASS lexemes=e4ffaa8a91895e497515f139e86598a415992b48ec787ca972a6c33e9df77317 sentences=c950c3adafd19a39aa4e028c160b44c5e44082fb441c661fe08285f41f750ba3
```

脚本先把现有真实 `dist` 安全复制为仓库根目录 staging 中的 `new-dist`，
仅替换其中的 App，再完成探针检查和签名。发布前写入可恢复事务状态；
验证成功后才通过 `/bin/mv -h` 发布整个 `dist`，最终检查结束后清理
backup、staging 和事务状态。脚本只在成功持锁后安装 trap；被拒绝的
竞争进程不会执行 rollback 或修改事务。

### 5. Executable 身份与无 fallback

脚本在签名前比较 SwiftPM release executable 和 staged executable 的 raw
SHA-256；本次两者均为：

```text
498f6ce3c0676f299ea23bc985db388e64ea5450153513049a3fa3cdad8a0516
```

ad-hoc `codesign` 会重写 Mach-O 内嵌签名，因此最终 executable SHA-256 为：

```text
7886760c4b5d7d28b0f05cdd26ff34bc57673d728871909e5fc7c2d83714d29a
```

对最终 executable 执行 `strings` 检查，仓库绝对路径和
`RussianCorner_RussianCornerCore.bundle` / `.build/...bundle` fallback
字符串匹配数均为 0。

### 6. JSON、Plist、签名、权限与结构

源文件、staging 和最终 App 的 JSON SHA 在脚本中逐阶段比较。最终复核：

```text
lexemes.json   e4ffaa8a91895e497515f139e86598a415992b48ec787ca972a6c33e9df77317
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

2026-07-26 06:57 CST 的结果：PID `54058` 在启动 5 秒后仍运行。
启动前后 10 分钟窗口中的 `RussianCornerApp*.crash` /
`RussianCornerApp*.ips` 文件数均为 0。

### 8. 仓库边界

`git diff --check` 通过。验收文档没有未决占位内容。
原始 Obsidian 语料通过 `Scripts/verify-source-corpus.sh` 复核：
46 个文件，SHA-256
`89ca565d1fa8b3840e89e7262b867d61fe486ea95962f1746c109bf2a4478b0c`，
与只读基线一致。

### 9. 学习闭环与生产加固

新增回归测试及实机检查确认：

- 日常队列同时投放词卡和句卡；上午默认俄语到中文认词，下午默认中文
  到俄语主动提取，并可手动切换方向；
- 常驻应用每分钟检查时间边界，跨中午刷新默认训练方向，跨午夜重建
  当天队列、完成状态、配额和周复习策略；
- 每日新词按历史表现和积压使用 6 / 10 / 12，自周复习日不加入新内容；
- 周复习日按自适应目标投放多条已学词，不再退化为仅复习一个词；
- `Again` 本轮稍后重现，成功项不循环，重启后恢复剩余队列；
- 诊断结果会收紧新词上限或默认开口模式，保存诊断后立即刷新策略；
- 同主题句卡形成 2–3 轮微型对话；
- 195 个名词均有性，93 个动词均有体及体对或说明，动词和介词均有
  支配/常见用法；
- 内容加载与 ResourceProbe 遇到坏链接或缺失元数据会 fail closed；
- 听力诊断只有俄语语音真实播放完成后才允许提交证据；
- SwiftData 实机文件位于
  `~/Library/Application Support/com.openclaw.russiancorner/RussianCorner.store`，
  进程未打开通用 `default.store`；
- 首次启动请求通知权限，后续启动校准 11:30 / 17:30 两个固定提醒。

独立最终复审在提交 `dd5e3e9` 上复核上述两个时间边界问题，定向测试
38/38、全量严格测试 187/187 均通过，结论为 `Ready to merge: Yes`。

## 人工硬件验收边界

以下项目未由本次自动化验收覆盖，本文不宣称已经通过：

- 麦克风首次授权、拒绝后的继续练习、录制、播放、保存和实际音质；
- 通知首次授权、拒绝路径及 11:30 / 17:30 的真实送达；
- 本机 `ru-RU` 语音选择和朗读效果；
- 9 个全局快捷键与目标 Mac 已安装软件之间的冲突；
- 多显示器移动、四角吸附、Retina 与不同缩放比例下的显示。
