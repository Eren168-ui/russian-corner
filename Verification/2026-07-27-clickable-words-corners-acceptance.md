# Russian Corner 增量验收报告

日期：2026-07-27

## 生产契约

- 目标：补齐“句中每个俄语词可点击”和“四角可移动”两项遗漏，并以本地审核解析为主、Yandex Dictionary 为可选增强。
- 输入与证据：现有 Swift 项目、只读口语语料目录、35 张试用句子、用户提供并已存入 macOS 钥匙串的 API 密钥。
- 范围：在当前项目和 MODE A 安全检查点上增量实现；不重建项目，不改原始 Obsidian 笔记，不扩大试用白名单。
- 排除：不接 AI 对话或发音评分；不上传整句、原始路径、评分或学习记录；不把基础词变成独立新词卡。
- 交付物：可点击句子、本地词解析、在线词典补充、四角菜单和拖动吸附、自动验收、使用文档、可运行 `.app`。
- 完成标准：35 句全部词位有审核解析；成品中能点击词并看到解析；四角切换和持久化有效；原始语料哈希不变；测试、资源、签名、启动和真实查询通过。

## 本次缺口修复

| 要求 | 实现 | 验证 |
| --- | --- | --- |
| 揭晓后每个俄语词可点击 | `InteractiveRussianText` 为每个西里尔词生成内部链接，标点保留且不可点击 | 35 句逐句构建测试；137/137 词位通过 |
| 点击后按需展开 | 选词自动展开详情；再点同词关闭；点另一词切换 | ViewModel 测试与成品实际点击 |
| 重音、含义、词形、词性 | 97 个本地审核词条 + 137 个上下文词形映射 | 内容目录和 shell 双重 fail-closed 校验 |
| 体对、支配、搭配、语境 | 有值时分层展示；本句用法始终展示 | 成品界面回读与数据校验 |
| 正文始终是主角 | 解析默认隐藏，只在点击后将卡片从紧凑态原位展开 | 成品界面实际检查 |
| 在线词典 | 本地解析先显示；Yandex 补充中译、近义词、例句；Wiktionary 为主动外链 | 真实 `ru-zh` 查询通过；断网/无密钥单元测试通过 |
| 密钥安全 | 只存 macOS Keychain；仓库、JSON、日志、数据库均不写明文 | 仓库特征扫描通过；钥匙串项目存在 |
| 只发送必要数据 | 在线请求只含用户所点词的原形和 `ru-zh` 参数 | 服务请求代码审查；使用指南写明边界 |
| 四角直接切换 | 卡片标题栏提供左上、右上、左下、右下菜单 | 成品菜单实际显示四项 |
| 四角真正移动 | 选择角后立即吸附；程序移动通知不会覆盖用户选择 | 成品从左上切到右下，稳定后仍为右下 |
| 拖动后吸附最近角 | 根据面板中心与当前屏幕中点计算最近角并持久化 | 四象限几何测试通过 |
| 重启后保留位置 | `AppModel.corner` 写入 UserDefaults | 成品重启后仍显示右下角 |
| 收起与隐藏 | 减号收成 58×58；菜单栏/全局快捷键可完全隐藏并恢复 | 成品收起实际检查；隐藏事务测试通过 |

## 原计划功能状态

| 模块 | 状态与证据 |
| --- | --- |
| 菜单栏应用、四角 `NSPanel`、置顶、透明度、字号、多屏 | 已实现；设置、屏幕选择与持久化测试通过 |
| 每日 6–12 新词自适应、周复习日、积压降量 | 已实现；Scheduler、队列和运行时测试通过 |
| 词汇、搭配、句块、场景句联动 | 已实现；360 个审核词、72 个句子，试用只投放 50 卡 |
| A2 以上、B1 以下筛选 | 已实现；基础问候等不作为独立新词卡，仍可在表达中出现并按需点击 |
| 主动回忆、3 秒提取、Again/Hard/Easy 间隔 | 已实现；排程和事务测试通过 |
| 俄语 TTS 与无俄语声音降级 | 已实现；SpeechService 测试通过 |
| 录音功能去鸡肋化 | 日常卡无录音；诊断只读实时音量估算开口和停顿，不保存音频 |
| 麦克风拒绝降级 | 已实现；拒绝后转计时 + 自评，测试通过 |
| 基线诊断与第 1/6 周可比指标 | 诊断题型、历史报告和相同指标已实现；第 6 周结果必须到时由真实使用产生 |
| 两次本地提醒 | 已实现；权限拒绝不影响核心学习 |
| 用户可读 7 天 Markdown 报告 | 已实现；中文报告通过系统保存面板导出，不是内部 JSON |
| 内容来源、状态、语用和角色标签 | 已实现；试用句均有来源、质量状态、交际意图、语域、角色、称呼和回应 |
| 原始语料只读 | 46 个文件，聚合 SHA-256 与基线一致 |
| 7 天真实试用 | 功能和统计已就绪；“完成 6/7 天、平均不超过 30 分钟”是后续真实行为结果，不能由开发过程伪造 |
| 6 周学习效果 | 复习、诊断和报告功能已就绪；主动掌握量、3 秒提取率和 1–2 分钟脱稿表现必须由实际学习产生 |

## 自动验证证据

```text
swift test -Xswiftc -warnings-as-errors
234 tests, 1 opt-in live test skipped, 0 failures

RUN_YANDEX_DICTIONARY_LIVE_TEST=1 swift test \
  --filter YandexDictionaryServiceTests/testConfiguredKeyLiveLookupWhenExplicitlyEnabled
1 test, 0 failures

source_corpus=PASS
files=46
sha256=89ca565d1fa8b3840e89e7262b867d61fe486ea95962f1746c109bf2a4478b0c

trial_content=PASS
cards=50 sentences=35 lexemes=15
manual_readback=35 word_entries=97 word_tokens=137

resource_probe_validation=PASS
build_app_symlink_safety=PASS
build_app_atomicity=PASS
secret_scan=PASS
keychain_item=PASS
codesign --verify=PASS
resource_sha256=PASS
```

## 成品实际操作

对 `dist/Russian Corner.app` 完成了以下操作：

1. 启动菜单栏应用并展开角落卡。
2. 揭晓 `Алло́! Здра́вствуйте! Кто э́то?`。
3. 点击句中词，详情立即显示本地释义、词形、原形、搭配和语境。
4. 同一详情中成功显示 Yandex 中文补充结果。
5. 打开标题栏角落菜单，确认四个角全部存在。
6. 从左上切换到右下，等待吸附稳定。
7. 检查 UserDefaults 为 `bottomRight`。
8. 退出并重新启动，卡片仍显示“当前右下角”。
9. 点击减号后卡片收成 58×58，点击可再次展开。

## 成品

`/Users/Openclawworkspace/workspace/russian-corner/.worktrees/clickable-words-corners/dist/Russian Corner.app`

