# MODE A 语料安全审查

日期：2026-07-26  
状态：`reviewed`，不声称经过母语者 `verified`

## 只读边界

唯一允许的原始目录：

`/Users/Openclawworkspace/Library/CloudStorage/OneDrive-个人/Documents/20-语言学习与专业/大学知识库（俄语学习+专业）/01-按学期/大一下——莫斯科/口语Диалоги`

原始目录未被修改。复验结果：

```text
source_corpus=PASS files=46 sha256=89ca565d1fa8b3840e89e7262b867d61fe486ea95962f1746c109bf2a4478b0c vault=Documents
```

明确不作为真实性依据：

- 3 个 `conflict` 文件；
- `口语练习计划 AI生成版` 下的 7 个文件；
- 空对话；
- `俄语对话练习汇总` 中补写的回答；
- 未能确认语法、拼写、意义或自然度的表达。

## 候选与隔离结果

对 32 个主题文件的编号表达区进行只读扫描，得到 624 条候选行。

| 项目 | 数量 |
|---|---:|
| 编号候选行 | 624 |
| 含中文混排 | 624 |
| 含括号变体 | 206 |
| 含 Markdown 标记 | 344 |
| 含方括号行内解释 | 5 |
| 带 `Диалоги` 区的主题文件 | 31 |
| 空 `Диалоги` 区 | 20 |
| 本轮选中的原始来源行 | 35 |
| 暂不进入试用的候选行 | 589 |

这些风险计数会重叠，不能相加。589 条未进入试用的候选仍留在原笔记中，不删除、不改写；后续只有完成逐条审查后才能进入新的白名单版本。

## 7 天试用白名单

`trial-slice.json` 共 50 张：

- 35 张完整表达卡；
- 15 张由这些表达直接支撑的 A2→B1 词汇卡；
- 6 个生活场景：问候与自我介绍、电话、问路、身体不适、购物、餐厅；
- 35 张表达卡全部逐条语义回读，并登记在 `manualReviewSampleIDs`；
- 所有内容仅标记 `reviewed`，没有一条标记 `verified`。

简单问候可以存在于完整交际表达中，但不会以独立新词卡占用名额。

## 文本分层

每张试用表达卡分别保存：

- `sourceText`：原笔记原行，保留中文和 Markdown 以便追溯；
- `practiceRu`：拆分后的确定俄语表达；
- `stressedForm`：界面显示用重音文本；
- `speechText`：交给 TTS 的纯俄语；
- 来源、质量标志、交际意图、语域、角色、称呼方式和常见回应。

来源中出现 `ты/вы`、性别或多个括号变体时，只能选定一个明确版本并标记为 `derived`；原行不被覆盖。带 `typo`、`grammarSuspect`、`unnatural`、`ambiguousTranslation`、`incomplete`、`emptyDialogue`、`possiblyDated` 或 `needsNativeReview` 的内容不能进入试用白名单。

## 自动闸门

```text
trial_content=PASS cards=50 sentences=35 lexemes=15 manual_readback=35
```

闸门检查：

- 总卡数为 50–80；
- 只使用允许的原始根目录；
- 内容为 `reviewed` 或 `verified`；
- `practiceRu`、`stressedForm`、`speechText` 非空；
- 练习及朗读文本不含中文、Markdown、方括号或括号变体；
- 来源原文能在对应只读笔记中逐字找到；
- 对话卡具备意图、语域、角色、称呼和常见回应；
- 词汇卡具备搭配、既有场景和本轮支撑表达；
- 至少 30 张已登记逐条回读。

这次回读是编辑级审查，不是母语者审校。需要母语者判断的内容保持在白名单外或标记 `needsNativeReview`。
