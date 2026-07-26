# MODE A 语料安全补丁最终验收

日期：2026-07-26  
分支：`feature/russian-corner-mvp`  
运行时安全检查点：`bfae4f1`  
语料安全补丁：`7b58648739a1f6f8c44fdc94fc2210ed62194c37`

## 交付结果

- 保留既有 360 个词汇记录和 72 个句子卡，没有破坏性重建。
- 新增独立 `trial-slice.json` 白名单，共 50 张卡：
  - 35 张完整表达卡；
  - 15 张由表达直接支撑的词汇卡；
  - 覆盖问候与自我介绍、电话、问路、身体不适、购物、餐厅 6 个场景。
- 生产练习、进度统计和学习诊断只使用试用白名单。
- 队列优先投放完整表达，再投放词汇补强卡。
- 加入来源、质量、语用、语域、角色、称呼和常见回应字段。
- 严格拆分 `sourceText`、`practiceRu`、`stressedForm` 和 `speechText`。
- 资源缺失、未审状态、危险质量标志、越界来源、未拆变体或不干净朗读文本均会让目录加载失败。
- MODE B 的续接对话、自由回应、角色互换、信息替换、修复表达和语域变体只记录为候选，没有扩大本次架构范围。

## 自动验收

```text
Swift: 225 tests, 0 failures, warnings-as-errors
trial_content=PASS cards=50 sentences=35 lexemes=15 manual_readback=35
resource_probe=PASS lexemes=360 sentences=72 trial=50
build_app_symlink_safety=PASS
resource_probe_validation=PASS
codesign_failure_preserves_old_app=PASS
lockf_concurrent_build_rejected=PASS
dist_swap_external_sentinel_safe_failure=PASS
publish_failure_restores_old_dist=PASS
unrelated_dist_entries_preserved=PASS
sigkill_transaction_recovered=PASS
persistent_empty_lockfile_nonblocking=PASS
app_launch_smoke=PASS
```

构建产物：

`/Users/Openclawworkspace/workspace/russian-corner/.worktrees/russian-corner-mvp/dist/Russian Corner.app`

应用大小约 4.0 MB。`codesign --verify --deep --strict` 通过，应用满足
Designated Requirement。当前为本地 ad-hoc 签名，未做 Apple Developer ID
公证，因此 `spctl --assess` 显示 `rejected` 是预期的分发边界，不是包内签名损坏。

## 资源与原始资料完整性

```text
lexemes.json
be6751854fe6660b4d5a4cbb02c3b9c79672aab03b033ecb8b74268d69ac7b46

sentences.json
c950c3adafd19a39aa4e028c160b44c5e44082fb441c661fe08285f41f750ba3

trial-slice.json
a35628d75705ad8288af5867f8fd27510f05fd0434e4ca590c6a1854e6a36d12
```

只读原始目录复验：

```text
source_corpus=PASS files=46
sha256=89ca565d1fa8b3840e89e7262b867d61fe486ea95962f1746c109bf2a4478b0c
vault=Documents
```

原始目录联合哈希与实施前基线一致。

## 人工与硬件边界

- 35 张表达卡已做编辑级逐条语义回读，但不声称经过母语者审校；状态为 `reviewed`，不是 `verified`。
- 自动进程启动通过。菜单栏、全局快捷键冲突、多显示器吸附、真实通知送达、俄语系统声音和麦克风活动估算仍需在目标 Mac 上人工确认。
- 应用不录音、不保存音频，也不自动判断发音是否地道。
