import Foundation
import RussianCornerCore

private struct TopicSeed {
    let slug: String
    let title: String
    let titleZh: String
    let descriptionZh: String
    let subject: String
    let subjectZh: String
    let action: String
    let actionZh: String
    let statement: String
    let statementZh: String
    let option: String
    let optionZh: String
    let condition: String
    let conditionZh: String
    let counterpoint: String
    let counterpointZh: String
    let request: String
    let requestZh: String
    let summary: String
    let summaryZh: String
}

private struct CardSeed {
    let target: String
    let promptZh: String
    let cue: String
    let focus: String
    let focusGlossZh: String
    let reply: String
    let variantPromptZh: String
    let variant: String
    let dialogueAct: String
}

private let topics: [TopicSeed] = [
    TopicSeed(
        slug: "reconnecting",
        title: "Reconnecting and catching up",
        titleZh: "重逢与近况",
        descriptionZh: "自然聊近况、解释忙碌状态并约下一次见面。",
        subject: "what you've been up to",
        subjectZh: "你最近在忙什么",
        action: "text you",
        actionZh: "给你发消息",
        statement: "I've been tied up with work lately",
        statementZh: "我最近一直忙于工作",
        option: "catching up over coffee",
        optionZh: "找时间喝咖啡叙旧",
        condition: "we keep it low-key",
        conditionZh: "我们简单轻松一点",
        counterpoint: "I don't think we should rush it",
        counterpointZh: "我觉得我们不必急着安排",
        request: "pick this up tomorrow",
        requestZh: "明天接着聊",
        summary: "we're meeting after work",
        summaryZh: "我们下班后见面"
    ),
    TopicSeed(
        slug: "scheduling",
        title: "Plans and scheduling",
        titleZh: "计划与改期",
        descriptionZh: "确认时间、提出替代方案并处理临时变化。",
        subject: "the schedule",
        subjectZh: "时间安排",
        action: "check my calendar",
        actionZh: "查一下日历",
        statement: "Friday works better for me",
        statementZh: "周五对我更合适",
        option: "moving it to Friday",
        optionZh: "把它改到周五",
        condition: "we finish before six",
        conditionZh: "我们六点前结束",
        counterpoint: "the timing still feels tight",
        counterpointZh: "时间还是有点紧",
        request: "push the meeting back by an hour",
        requestZh: "把会议推迟一小时",
        summary: "the meeting starts at three",
        summaryZh: "会议三点开始"
    ),
    TopicSeed(
        slug: "clarifying",
        title: "Clarifying and repairing",
        titleZh: "澄清与补救",
        descriptionZh: "没听懂时追问、换一种说法并复述确认。",
        subject: "the last point",
        subjectZh: "最后一点",
        action: "ask you to clarify that",
        actionZh: "请你澄清一下",
        statement: "I understood the goal differently",
        statementZh: "我对目标的理解不一样",
        option: "using a concrete example",
        optionZh: "用一个具体例子",
        condition: "we define the terms first",
        conditionZh: "我们先把术语定义清楚",
        counterpoint: "that isn't how I interpreted it",
        counterpointZh: "我的理解并不是这样",
        request: "say that in a different way",
        requestZh: "换一种方式说明",
        summary: "you want me to revise the first part",
        summaryZh: "你希望我修改第一部分"
    ),
    TopicSeed(
        slug: "opinions",
        title: "Opinions and reactions",
        titleZh: "观点与反应",
        descriptionZh: "表达真实看法、委婉不同意并补充理由。",
        subject: "the ending",
        subjectZh: "结局",
        action: "tell you what I thought",
        actionZh: "告诉你我的看法",
        statement: "the ending felt a little forced",
        statementZh: "结局显得有点牵强",
        option: "giving it another chance",
        optionZh: "再给它一次机会",
        condition: "we don't take it too seriously",
        conditionZh: "我们别太较真",
        counterpoint: "the characters deserved more time",
        counterpointZh: "这些角色值得更多篇幅",
        request: "explain what you liked about it",
        requestZh: "说说你喜欢它的原因",
        summary: "you liked the idea more than the execution",
        summaryZh: "相比呈现方式，你更喜欢它的创意"
    ),
    TopicSeed(
        slug: "work-study",
        title: "Work and study updates",
        titleZh: "工作与学习进展",
        descriptionZh: "汇报进度、说明卡点并争取支持。",
        subject: "the project update",
        subjectZh: "项目进展",
        action: "send you the latest draft",
        actionZh: "把最新草稿发给你",
        statement: "I'm still working through the difficult part",
        statementZh: "我还在处理最难的部分",
        option: "finishing the outline first",
        optionZh: "先完成大纲",
        condition: "we agree on the main direction",
        conditionZh: "我们先确定主要方向",
        counterpoint: "we may be underestimating the workload",
        counterpointZh: "我们可能低估了工作量",
        request: "take a look at my draft",
        requestZh: "看一下我的草稿",
        summary: "I'll send the revised version tonight",
        summaryZh: "我今晚发修改版"
    ),
    TopicSeed(
        slug: "favors",
        title: "Requests and favors",
        titleZh: "请求与帮忙",
        descriptionZh: "提出请求、说明边界并礼貌协商。",
        subject: "the favor I mentioned",
        subjectZh: "我提到的那件事",
        action: "ask if you could help",
        actionZh: "问你能不能帮忙",
        statement: "I only need a few minutes of your time",
        statementZh: "我只需要占用你几分钟",
        option: "handling the urgent part myself",
        optionZh: "我自己先处理紧急部分",
        condition: "it doesn't put you out",
        conditionZh: "这不会给你添太多麻烦",
        counterpoint: "I can manage if you're too busy",
        counterpointZh: "如果你太忙，我也可以自己处理",
        request: "give me a hand with this form",
        requestZh: "帮我填一下这张表",
        summary: "you'll check it when you have time",
        summaryZh: "你有时间时会看一下"
    ),
    TopicSeed(
        slug: "invitations",
        title: "Invitations and social plans",
        titleZh: "邀请与社交安排",
        descriptionZh: "发出邀请、婉拒并提出替代方案。",
        subject: "the get-together",
        subjectZh: "聚会",
        action: "invite you to dinner",
        actionZh: "邀请你吃晚饭",
        statement: "it's going to be a small group",
        statementZh: "到时只有几个人",
        option: "joining you later",
        optionZh: "晚一点再过去",
        condition: "I can leave a little early",
        conditionZh: "我能早点离开",
        counterpoint: "Saturday would be much easier",
        counterpointZh: "周六会方便很多",
        request: "save me a seat",
        requestZh: "帮我留个位置",
        summary: "I'll meet you there around eight",
        summaryZh: "我八点左右在那里见你"
    ),
    TopicSeed(
        slug: "shopping",
        title: "Shopping and returns",
        titleZh: "购物与退换",
        descriptionZh: "询问细节、比较选择并处理退换货。",
        subject: "the return policy",
        subjectZh: "退货政策",
        action: "ask about a different size",
        actionZh: "问一下其他尺码",
        statement: "this one doesn't fit the way I expected",
        statementZh: "这件穿起来和我预期不一样",
        option: "exchanging it instead of returning it",
        optionZh: "换货而不是退货",
        condition: "the receipt isn't required",
        conditionZh: "不强制要求小票",
        counterpoint: "the price difference seems too high",
        counterpointZh: "差价似乎太高了",
        request: "check whether this is available in black",
        requestZh: "查一下有没有黑色",
        summary: "I can exchange it within thirty days",
        summaryZh: "我可以在三十天内换货"
    ),
    TopicSeed(
        slug: "dining",
        title: "Restaurants and cafés",
        titleZh: "餐厅与咖啡馆",
        descriptionZh: "点餐、确认需求并自然处理服务问题。",
        subject: "the specials",
        subjectZh: "今日特色菜",
        action: "ask for the menu",
        actionZh: "要一份菜单",
        statement: "I'd prefer something that isn't too heavy",
        statementZh: "我更想吃清淡一点的",
        option: "sharing a couple of dishes",
        optionZh: "一起分几道菜",
        condition: "they can leave out the cheese",
        conditionZh: "他们可以不放奶酪",
        counterpoint: "we might be ordering too much",
        counterpointZh: "我们可能点得有点多",
        request: "bring us some water first",
        requestZh: "先给我们上点水",
        summary: "we're splitting the bill",
        summaryZh: "我们分开结账"
    ),
    TopicSeed(
        slug: "transport",
        title: "Travel and transport",
        titleZh: "出行与交通",
        descriptionZh: "确认路线、处理延误并调整出行计划。",
        subject: "the train connection",
        subjectZh: "火车换乘",
        action: "check the departure time",
        actionZh: "查出发时间",
        statement: "the earlier train gives us more time",
        statementZh: "坐早一班车时间更宽裕",
        option: "taking the direct route",
        optionZh: "走直达路线",
        condition: "we don't have to change trains",
        conditionZh: "我们不用换乘",
        counterpoint: "the cheaper option takes much longer",
        counterpointZh: "便宜的方案耗时太久",
        request: "change my ticket to tomorrow",
        requestZh: "把我的票改到明天",
        summary: "the platform changes ten minutes before departure",
        summaryZh: "站台会在出发前十分钟变更"
    ),
    TopicSeed(
        slug: "directions",
        title: "Directions and finding places",
        titleZh: "问路与找地点",
        descriptionZh: "确认位置、复述路线并在迷路时修复沟通。",
        subject: "the last turn",
        subjectZh: "最后一个转弯",
        action: "check the map again",
        actionZh: "再看一遍地图",
        statement: "I think we passed the entrance",
        statementZh: "我觉得我们已经错过入口了",
        option: "asking someone nearby",
        optionZh: "问问附近的人",
        condition: "we stay on this street",
        conditionZh: "我们一直沿着这条街走",
        counterpoint: "the map seems to be pointing the other way",
        counterpointZh: "地图好像指向另一个方向",
        request: "show me where we are on the map",
        requestZh: "在地图上指给我看我们的位置",
        summary: "we turn left after the bank",
        summaryZh: "我们过了银行后左转"
    ),
    TopicSeed(
        slug: "calls",
        title: "Phone and video calls",
        titleZh: "电话与视频通话",
        descriptionZh: "处理声音卡顿、打断和重新接通。",
        subject: "what you said before the call dropped",
        subjectZh: "掉线前你说的内容",
        action: "call you back",
        actionZh: "给你回电话",
        statement: "your voice keeps cutting out",
        statementZh: "你的声音一直断断续续",
        option: "switching off the video",
        optionZh: "关掉视频",
        condition: "the connection gets more stable",
        conditionZh: "连接能稳定一些",
        counterpoint: "I may have missed an important detail",
        counterpointZh: "我可能漏听了一个重要细节",
        request: "repeat the last sentence",
        requestZh: "重复最后一句",
        summary: "you'll send the details in a message",
        summaryZh: "你会把细节发消息给我"
    ),
    TopicSeed(
        slug: "health",
        title: "Health and well-being",
        titleZh: "身体与状态",
        descriptionZh: "描述症状、说明程度并讨论休息安排。",
        subject: "how you've been feeling",
        subjectZh: "你最近的身体感受",
        action: "make an appointment",
        actionZh: "预约就诊",
        statement: "the pain comes and goes",
        statementZh: "疼痛时有时无",
        option: "taking the day off",
        optionZh: "请一天假",
        condition: "I can get some proper rest",
        conditionZh: "我能好好休息",
        counterpoint: "I don't think I should ignore it",
        counterpointZh: "我觉得不应该再忽视它",
        request: "tell me what symptoms to watch for",
        requestZh: "告诉我需要留意哪些症状",
        summary: "I should come back if it gets worse",
        summaryZh: "如果情况恶化，我应该再来"
    ),
    TopicSeed(
        slug: "complaints",
        title: "Problems and complaints",
        titleZh: "问题与投诉",
        descriptionZh: "具体说明问题、提出解决办法并保持礼貌。",
        subject: "the issue with my order",
        subjectZh: "我的订单问题",
        action: "report the problem",
        actionZh: "反馈这个问题",
        statement: "the item I received was damaged",
        statementZh: "我收到的商品已经损坏",
        option: "asking for a replacement",
        optionZh: "要求换货",
        condition: "it can be delivered this week",
        conditionZh: "本周能送到",
        counterpoint: "a refund alone doesn't solve the problem",
        counterpointZh: "只退款并不能解决问题",
        request: "check what happened to the shipment",
        requestZh: "查一下这批货出了什么情况",
        summary: "a replacement will arrive on Thursday",
        summaryZh: "替换品会在周四送到"
    ),
    TopicSeed(
        slug: "apologies",
        title: "Apologies and mistakes",
        titleZh: "道歉与失误",
        descriptionZh: "承担责任、解释但不找借口，并给出补救。",
        subject: "what went wrong",
        subjectZh: "哪里出了问题",
        action: "apologize for the mix-up",
        actionZh: "为这次弄错道歉",
        statement: "I should have checked with you first",
        statementZh: "我本来应该先和你确认",
        option: "fixing it right away",
        optionZh: "马上补救",
        condition: "we don't repeat the same mistake",
        conditionZh: "我们不再犯同样的错误",
        counterpoint: "I understand why you're upset",
        counterpointZh: "我理解你为什么不高兴",
        request: "give me a chance to make this right",
        requestZh: "给我一个弥补的机会",
        summary: "I'll double-check everything next time",
        summaryZh: "下次我会把所有内容再核对一遍"
    ),
    TopicSeed(
        slug: "storytelling",
        title: "Telling stories naturally",
        titleZh: "自然讲述经历",
        descriptionZh: "组织过去事件、补充背景并突出转折。",
        subject: "what happened next",
        subjectZh: "接下来发生了什么",
        action: "tell you the whole story",
        actionZh: "把整件事告诉你",
        statement: "I didn't realize anything was wrong at first",
        statementZh: "起初我没意识到哪里不对",
        option: "starting from the beginning",
        optionZh: "从头讲起",
        condition: "I don't leave out the important part",
        conditionZh: "我不漏掉重要部分",
        counterpoint: "the situation was stranger than it sounds",
        counterpointZh: "当时的情况比听起来更奇怪",
        request: "let me finish before you judge",
        requestZh: "先让我讲完再评价",
        summary: "I missed the train because I helped a stranger",
        summaryZh: "我因为帮助陌生人而错过了火车"
    ),
    TopicSeed(
        slug: "relationships",
        title: "Friends and relationships",
        titleZh: "朋友与关系",
        descriptionZh: "谈感受、设定边界并处理误会。",
        subject: "the conversation we had",
        subjectZh: "我们之前的那次谈话",
        action: "check in with you",
        actionZh: "问问你的情况",
        statement: "I felt left out of the decision",
        statementZh: "我觉得自己被排除在决策之外",
        option: "talking about it in person",
        optionZh: "当面谈这件事",
        condition: "we both listen without interrupting",
        conditionZh: "我们都不打断对方",
        counterpoint: "I don't think that was your intention",
        counterpointZh: "我觉得那并不是你的本意",
        request: "be honest with me about how you feel",
        requestZh: "坦诚告诉我你的感受",
        summary: "we need more time before making a decision",
        summaryZh: "我们做决定前需要更多时间"
    ),
    TopicSeed(
        slug: "screen-dialogue",
        title: "Reacting to shows and dialogue",
        titleZh: "影视内容与对白",
        descriptionZh: "无字幕观看后复述、推断并讨论自然表达。",
        subject: "the line I missed",
        subjectZh: "我漏听的那句台词",
        action: "rewind that scene",
        actionZh: "倒回去看那一幕",
        statement: "the joke depends on the way he says it",
        statementZh: "这个笑点取决于他的说法",
        option: "watching the scene once more without subtitles",
        optionZh: "再无字幕看一遍",
        condition: "we focus on the main idea",
        conditionZh: "我们只抓主要意思",
        counterpoint: "the translation misses the tone",
        counterpointZh: "翻译没有体现语气",
        request: "play that part at normal speed",
        requestZh: "用正常速度播放那一段",
        summary: "she was being sarcastic rather than serious",
        summaryZh: "她是在讽刺，并不是认真的"
    ),
    TopicSeed(
        slug: "reading",
        title: "Reading and discussing ideas",
        titleZh: "阅读与讨论观点",
        descriptionZh: "用英语概括、提问并评价阅读内容。",
        subject: "the author's main argument",
        subjectZh: "作者的核心论点",
        action: "summarize the chapter",
        actionZh: "概括这一章",
        statement: "the evidence is stronger than the conclusion",
        statementZh: "证据比结论更有说服力",
        option: "looking up the key term in context",
        optionZh: "结合上下文查核心术语",
        condition: "we separate the facts from the author's opinion",
        conditionZh: "我们区分事实和作者观点",
        counterpoint: "the example doesn't fully support the claim",
        counterpointZh: "这个例子不能完全支持该主张",
        request: "explain how you reached that conclusion",
        requestZh: "解释你如何得出这个结论",
        summary: "the author argues that habits shape identity",
        summaryZh: "作者认为习惯会塑造身份"
    ),
    TopicSeed(
        slug: "everyday-logistics",
        title: "Everyday logistics",
        titleZh: "日常事务协调",
        descriptionZh: "处理预约、交接、取件和生活安排。",
        subject: "the pickup arrangements",
        subjectZh: "取件安排",
        action: "confirm the address",
        actionZh: "确认地址",
        statement: "someone needs to be there to sign for it",
        statementZh: "需要有人在场签收",
        option: "leaving it with the front desk",
        optionZh: "把它放在前台",
        condition: "they call before they arrive",
        conditionZh: "他们到达前先打电话",
        counterpoint: "the delivery window is too broad",
        counterpointZh: "配送时间范围太宽",
        request: "send me the tracking number",
        requestZh: "把快递单号发给我",
        summary: "the package should arrive before noon",
        summaryZh: "包裹应该会在中午前到"
    ),
]

private func cards(for topic: TopicSeed) -> [CardSeed] {
    [
        CardSeed(
            target: "I was just about to \(topic.action).",
            promptZh: "我正要\(topic.actionZh)。",
            cue: "You were going to do it at this exact moment.",
            focus: "be just about to \(topic.action)",
            focusGlossZh: "正要\(topic.actionZh)",
            reply: "Perfect timing—go ahead.",
            variantPromptZh: "其实我刚准备\(topic.actionZh)。",
            variant: "I was actually about to \(topic.action).",
            dialogueAct: "informing"
        ),
        CardSeed(
            target: "I didn't quite catch what you said about \(topic.subject).",
            promptZh: "我没太听清你刚才关于\(topic.subjectZh)说的内容。",
            cue: "You heard the words but missed one important point.",
            focus: "not quite catch what someone said about \(topic.subject)",
            focusGlossZh: "没太听清关于\(topic.subjectZh)说了什么",
            reply: "No problem. What I meant was this.",
            variantPromptZh: "关于\(topic.subjectZh)的部分我没太听清。",
            variant: "I didn't quite catch the part about \(topic.subject).",
            dialogueAct: "clarifying"
        ),
        CardSeed(
            target: "Could you walk me through \(topic.subject) one more time?",
            promptZh: "你能再给我讲一遍\(topic.subjectZh)吗？",
            cue: "Ask for a clear step-by-step explanation.",
            focus: "walk someone through \(topic.subject)",
            focusGlossZh: "给某人逐步讲解\(topic.subjectZh)",
            reply: "Sure. Let's go through it step by step.",
            variantPromptZh: "你介意再解释一遍\(topic.subjectZh)吗？",
            variant: "Would you mind going over \(topic.subject) again?",
            dialogueAct: "requesting"
        ),
        CardSeed(
            target: "What I mean is that \(topic.statement).",
            promptZh: "我的意思是，\(topic.statementZh)。",
            cue: "Repair your wording after the listener misunderstood.",
            focus: "what I mean is that \(topic.statement)",
            focusGlossZh: "我的意思是\(topic.statementZh)",
            reply: "Got it—that makes more sense.",
            variantPromptZh: "换句话说，\(topic.statementZh)。",
            variant: "In other words, \(topic.statement).",
            dialogueAct: "selfRepair"
        ),
        CardSeed(
            target: "I'm leaning toward \(topic.option), but I'm still on the fence.",
            promptZh: "我更倾向于\(topic.optionZh)，但还没完全决定。",
            cue: "Express a current preference without pretending the choice is final.",
            focus: "lean toward \(topic.option)",
            focusGlossZh: "更倾向于\(topic.optionZh)",
            reply: "That sounds reasonable. What is holding you back?",
            variantPromptZh: "目前我比较想\(topic.optionZh)，但还在考虑。",
            variant: "For now, I'm leaning toward \(topic.option), though I haven't decided yet.",
            dialogueAct: "weighingOptions"
        ),
        CardSeed(
            target: "That works for me, as long as \(topic.condition).",
            promptZh: "我可以，只要\(topic.conditionZh)。",
            cue: "Accept the plan while stating one condition.",
            focus: "that works for me, as long as \(topic.condition)",
            focusGlossZh: "我可以，只要\(topic.conditionZh)",
            reply: "That should be fine.",
            variantPromptZh: "只要\(topic.conditionZh)，我就没问题。",
            variant: "I'm fine with that, provided that \(topic.condition).",
            dialogueAct: "conditionalAgreement"
        ),
        CardSeed(
            target: "I see where you're coming from, but \(topic.counterpoint).",
            promptZh: "我理解你的出发点，但\(topic.counterpointZh)。",
            cue: "Disagree without dismissing the other person's reasoning.",
            focus: "see where someone is coming from",
            focusGlossZh: "理解某人的立场或出发点",
            reply: "That's fair. Let's look at both sides.",
            variantPromptZh: "我明白你的意思，不过\(topic.counterpointZh)。",
            variant: "I get your point, but \(topic.counterpoint).",
            dialogueAct: "disagreeing"
        ),
        CardSeed(
            target: "Would it be possible to \(topic.request)?",
            promptZh: "可以\(topic.requestZh)吗？",
            cue: "Make a polite request that leaves room for the other person to say no.",
            focus: "would it be possible to \(topic.request)",
            focusGlossZh: "是否可以\(topic.requestZh)",
            reply: "Let me see what I can do.",
            variantPromptZh: "你觉得我们能不能\(topic.requestZh)？",
            variant: "Do you think we could \(topic.request)?",
            dialogueAct: "requesting"
        ),
        CardSeed(
            target: "If anything changes with \(topic.subject), just give me a heads-up.",
            promptZh: "如果\(topic.subjectZh)有变化，提前告诉我一声。",
            cue: "Ask for a brief warning rather than a long explanation.",
            focus: "give someone a heads-up about \(topic.subject)",
            focusGlossZh: "提前告知某人\(topic.subjectZh)的变化",
            reply: "Of course. I'll let you know right away.",
            variantPromptZh: "\(topic.subjectZh)有新情况就告诉我。",
            variant: "Keep me posted if anything changes with \(topic.subject).",
            dialogueAct: "requestingUpdate"
        ),
        CardSeed(
            target: "Let me make sure I've got this right: \(topic.summary).",
            promptZh: "我确认一下自己理解得对不对：\(topic.summaryZh)。",
            cue: "Repeat the key information before acting on it.",
            focus: "make sure I've got this right",
            focusGlossZh: "确认自己是否理解正确",
            reply: "Exactly. That's the plan.",
            variantPromptZh: "所以你的意思是\(topic.summaryZh)，对吗？",
            variant: "So, if I understand you correctly, \(topic.summary).",
            dialogueAct: "confirming"
        ),
    ]
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(
        Data(
            "Usage: RussianCornerEnglishContentBuilder <resource-directory>\n"
                .utf8
        )
    )
    exit(64)
}

let outputDirectory = URL(
    fileURLWithPath: CommandLine.arguments[1],
    isDirectory: true
)
var studyTopics: [StudyTopic] = []
var lessons: [SceneLesson] = []
var sentences: [StudySentence] = []
var lexemes: [StudyLexeme] = []

for (topicIndex, topic) in topics.enumerated() {
    let topicID = "en.topic.\(String(format: "%02d", topicIndex + 1)).\(topic.slug)"
    var sentenceIDs: [String] = []
    for (cardIndex, card) in cards(for: topic).enumerated() {
        let number = String(format: "%02d", cardIndex + 1)
        let sentenceID = "\(topicID).\(number)"
        let expressionID = "en.expression.\(topic.slug).\(number)"
        let focusID = "en.focus.\(topic.slug).\(number)"
        sentenceIDs.append(sentenceID)
        let sourcePath = "bundled/english/\(topic.slug)"
        sentences.append(
            StudySentence(
                id: sentenceID,
                language: .english,
                promptZh: card.promptZh,
                cueText: card.cue,
                targetText: card.target,
                displayText: card.target,
                speechText: card.target,
                theme: topic.title,
                lexemeIDs: [expressionID, focusID],
                dialogueAct: card.dialogueAct,
                register: .neutral,
                speakerRole: "adult conversation partner",
                expectedReplies: [card.reply],
                variants: [
                    SentenceVariant(
                        promptZh: card.variantPromptZh,
                        targetText: card.variant
                    ),
                ],
                reviewStatus: .reviewed,
                provenanceType: .derived,
                sourcePath: sourcePath,
                sourceText: card.target,
                topicID: topicID
            )
        )
        lexemes.append(
            StudyLexeme(
                id: expressionID,
                language: .english,
                lemma: card.target,
                displayForm: card.target,
                speechText: card.target,
                partOfSpeech: "spoken expression",
                glossZh: card.promptZh,
                collocations: [card.target],
                morphologyNotes: [
                    "完整口语表达：先根据场景主动说，再核对文本。",
                ],
                exampleSentenceIDs: [sentenceID],
                reviewStatus: .reviewed,
                provenanceType: .derived,
                sourcePath: sourcePath,
                sourceText: card.target
            )
        )
        lexemes.append(
            StudyLexeme(
                id: focusID,
                language: .english,
                lemma: card.focus,
                displayForm: card.focus,
                speechText: card.focus,
                partOfSpeech: "high-frequency chunk",
                glossZh: card.focusGlossZh,
                collocations: [card.focus],
                morphologyNotes: [
                    "把这个句块作为整体提取，不要先逐词翻译。",
                ],
                exampleSentenceIDs: [sentenceID],
                reviewStatus: .reviewed,
                provenanceType: .derived,
                sourcePath: sourcePath,
                sourceText: card.target
            )
        )
    }
    studyTopics.append(
        StudyTopic(
            id: topicID,
            language: .english,
            titleTarget: topic.title,
            titleZh: topic.titleZh,
            descriptionZh: topic.descriptionZh,
            sentenceIDs: sentenceIDs
        )
    )
    lessons.append(
        SceneLesson(
            id: "en.lesson.\(topic.slug)",
            language: .english,
            topicID: topicID,
            titleZh: topic.titleZh,
            contextZh: topic.descriptionZh,
            sentenceIDs: sentenceIDs,
            dialogueOrder: sentenceIDs
        )
    )
}

do {
    try FileManager.default.createDirectory(
        at: outputDirectory,
        withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let resources: [(String, any Encodable)] = [
        ("english-lexemes.json", lexemes),
        ("english-sentences.json", sentences),
        ("english-topics.json", studyTopics),
        ("english-lessons.json", lessons),
    ]
    for (name, value) in resources {
        let data = try encoder.encode(value)
        try data.write(
            to: outputDirectory.appendingPathComponent(name),
            options: .atomic
        )
    }
    print(
        "Generated \(sentences.count) English expressions, "
            + "\(lexemes.count) lexemes, \(studyTopics.count) topics"
    )
} catch {
    FileHandle.standardError.write(
        Data("Generation failed: \(error.localizedDescription)\n".utf8)
    )
    exit(1)
}
