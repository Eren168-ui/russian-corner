#!/usr/bin/env python3
"""Build the reviewed, scene-based English corpus.

The sentences are newly authored from everyday conversational patterns. They
are not episode transcripts. Friends is a style reference for turn-taking,
fillers, reactions, and informal rhythm only.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Sources" / "RussianCornerCore" / "Resources"


def row(
    prompt: str,
    cue: str,
    target: str,
    reply: str,
    focus: str,
    focus_zh: str,
    act: str,
) -> dict[str, str]:
    return {
        "promptZh": prompt,
        "cueText": cue,
        "targetText": target,
        "reply": reply,
        "focus": focus,
        "focusZh": focus_zh,
        "dialogueAct": act,
    }


TOPICS = [
    (
        "reconnecting",
        "朋友与近况",
        "Catching up with friends",
        "自然聊近况、接住对方的话，并约下一次见面。",
        [
            row("你最近在忙什么？", "Ask a friend about life lately.", "What have you been up to?", "Nothing too exciting—just work and sleep.", "What have you been up to?", "你最近在忙什么", "asking"),
            row("我最近一直忙着上课。", "Explain why you have been hard to reach.", "I've been swamped with classes lately.", "That sounds intense. Are you getting any breaks?", "swamped with classes", "忙得不可开交", "explaining"),
            row("这周找个时间叙叙旧？", "Suggest meeting a friend soon.", "Want to catch up sometime this week?", "Sure—how about Thursday evening?", "catch up sometime", "找时间叙叙旧", "inviting"),
            row("我刚看到你的消息。", "Reply after noticing a late message.", "I just saw your message.", "No worries. I figured you were busy.", "I just saw your message", "我刚看到你的消息", "responding"),
            row("我正要给你发消息。", "Tell a friend you were about to text them.", "I was just about to text you.", "Perfect timing. What's up?", "was just about to", "正要做某事", "informing"),
            row("好久不见，见到你真好。", "Greet a friend you have not seen in a while.", "It's been forever. Good to see you.", "You too! We really need to do this more often.", "It's been forever", "好久不见", "greeting"),
            row("我最近事情有点多。", "Say that life has been unusually busy.", "I've had a lot going on lately.", "I get it. Want to talk about it?", "a lot going on", "事情很多", "explaining"),
            row("你最近过得怎么样？", "Ask how someone has been doing.", "How have things been?", "Pretty good, actually. I can't complain.", "How have things been?", "最近过得怎么样", "asking"),
            row("这周找个晚上喝杯咖啡？", "Make a low-pressure plan with a friend.", "How about coffee one night this week?", "I'm free Wednesday if that works.", "one night this week", "这周某个晚上", "inviting"),
            row("我还在重新适应节奏。", "Explain that you are getting back into a routine.", "I'm still getting back into the swing of things.", "Take your time. There's no rush.", "get back into the swing of things", "重新适应节奏", "explaining"),
        ],
    ),
    (
        "scheduling",
        "约时间与临时改期",
        "Making plans and changing them",
        "确认时间、说明临时变化，并自然地提出替代方案。",
        [
            row("你晚点有空吗？", "Check whether a friend is free later.", "Are you free later?", "Maybe after seven. What's up?", "Are you free later?", "晚点有空吗", "asking"),
            row("什么时间对你合适？", "Ask someone to choose a time.", "What time works for you?", "Any time after lunch is fine.", "What time works for you?", "什么时间合适", "asking"),
            row("我可能会晚一点。", "Warn someone that you are delayed.", "I'm running a little late.", "No problem. Take your time.", "running a little late", "有点迟到", "informing"),
            row("我们往后推一会儿可以吗？", "Ask to move a plan to a later time.", "Can we push it back a bit?", "Sure. How does eight sound?", "push it back", "往后推迟", "requesting"),
            row("到时候再看吧。", "Keep a plan flexible.", "Let's play it by ear.", "Works for me. We'll check in tomorrow.", "play it by ear", "到时候看情况", "suggesting"),
            row("这个时间我可以。", "Accept a suggested time.", "That works for me.", "Great, I'll put it in my calendar.", "That works for me", "这个时间对我可以", "confirming"),
            row("我确定后告诉你。", "Say you need to check before confirming.", "I'll let you know once I check.", "Sure, no pressure.", "I'll let you know", "我确定后告诉你", "informing"),
            row("我临时有点事。", "Explain why you need to change plans.", "Something came up.", "Everything okay?", "Something came up", "临时有事", "explaining"),
            row("我六点以后都有空。", "State your availability.", "I'm free after six.", "Perfect. Let's meet around seven.", "free after six", "六点以后有空", "informing"),
            row("我们在中间碰面怎么样？", "Suggest a convenient meeting point.", "Do you want to meet halfway?", "That would make things easier.", "meet halfway", "在中间碰面", "suggesting"),
        ],
    ),
    (
        "clarifying",
        "没听清与重新说明",
        "Clarifying and repairing a conversation",
        "听漏信息时追问、确认关键词，并用更简单的话重新组织。",
        [
            row("不好意思，我刚才没听清。", "Ask someone to repeat themselves.", "Sorry, I missed that.", "I said the meeting starts at nine.", "I missed that", "我没听清", "repairing"),
            row("你能再说一遍吗？", "Ask for a repetition in a casual way.", "Could you say that again?", "Sure, no problem.", "say that again", "再说一遍", "requesting"),
            row("你这是什么意思？", "Ask what someone means without sounding formal.", "What do you mean by that?", "I just mean we should wait a little.", "What do you mean by that?", "你这是什么意思", "clarifying"),
            row("所以你的意思是八点见？", "Check your understanding of a time.", "So you mean we're meeting at eight?", "Exactly.", "So you mean", "所以你的意思是", "confirming"),
            row("我没太跟上。", "Say that an explanation is hard to follow.", "I'm not following you.", "Let me explain it another way.", "I'm not following you", "我没跟上", "repairing"),
            row("我换个说法。", "Restart an explanation more simply.", "Let me put it another way.", "Okay, that might be easier.", "put it another way", "换一种说法", "repairing"),
            row("你说的是周二还是周四？", "Clarify two similar options.", "Did you say Tuesday or Thursday?", "Thursday, sorry.", "Tuesday or Thursday", "周二还是周四", "clarifying"),
            row("最后那部分我没听清。", "Ask about the final part of a sentence.", "I didn't catch the last part.", "I said you can send it tomorrow.", "catch the last part", "听清最后一部分", "repairing"),
            row("给我一秒想想。", "Buy a moment before answering.", "Give me a second to think.", "Of course.", "Give me a second", "给我一点时间", "stalling"),
            row("你懂我的意思吧？", "Check whether your point is clear.", "You know what I mean?", "Yeah, I think so.", "You know what I mean?", "你懂我的意思吧", "confirming"),
        ],
    ),
    (
        "reactions",
        "惊讶、赞同与接话",
        "Reacting naturally",
        "用短而自然的反应接住朋友的故事、消息和观点。",
        [
            row("不可能！", "React with surprise to unexpected news.", "No way!", "I know. I couldn't believe it either.", "No way!", "不可能／不会吧", "reacting"),
            row("我懂，对吧？", "Agree enthusiastically with a friend.", "I know, right?", "Exactly! You get it.", "I know, right?", "我知道，对吧", "agreeing"),
            row("这样就说得通了。", "Show that an explanation makes sense.", "That makes sense.", "Good, I'm glad it helps.", "makes sense", "说得通", "confirming"),
            row("你开玩笑吧！", "React to surprising information.", "You're kidding!", "I wish I were.", "You're kidding", "你开玩笑吧", "reacting"),
            row("为你高兴！", "Congratulate a friend warmly.", "Good for you!", "Thanks. I'm pretty excited.", "Good for you", "为你高兴", "encouraging"),
            row("我终于松了口气。", "Say that a stressful situation is over.", "I'm so relieved.", "Me too. That was a lot.", "so relieved", "如释重负", "reacting"),
            row("听起来挺难的。", "Respond with sympathy to a problem.", "That sounds rough.", "Yeah, it's been a long week.", "sounds rough", "听起来很难", "empathizing"),
            row("我真不敢相信。", "React to something unbelievable.", "I can't believe it.", "I know. It happened so fast.", "can't believe it", "不敢相信", "reacting"),
            row("说实话，我并不意外。", "Give a mildly blunt reaction.", "Honestly, I'm not surprised.", "You saw it coming?", "I'm not surprised", "说实话，我并不意外", "reacting"),
            row("这其实挺酷的。", "Show positive interest in an idea.", "That's actually pretty cool.", "Right? I want to try it too.", "actually pretty cool", "其实挺酷的", "encouraging"),
        ],
    ),
    (
        "work-study",
        "工作与学习进展",
        "Work and study in real life",
        "聊进度、拖延、休息和下班下课后的状态，不用书面化表达。",
        [
            row("我工作多到忙不过来。", "Explain that work has piled up.", "I'm buried in work.", "Same here. It's been nonstop.", "buried in work", "工作堆成山", "explaining"),
            row("我得把这个弄完。", "State a task you need to finish.", "I need to get this done.", "Want some help?", "get this done", "把这件事做完", "informing"),
            row("我还没来得及看。", "Explain why you have not reviewed something.", "I haven't had a chance to look at it.", "No worries. Take a look when you can.", "haven't had a chance", "还没来得及", "explaining"),
            row("我们一起过一遍？", "Suggest reviewing something together.", "Can we go over this together?", "Sure, let's do it after lunch.", "go over this", "一起过一遍", "requesting"),
            row("我快做完了。", "Give a quick progress update.", "I'm almost done.", "Great—send it over when you are.", "almost done", "快做完了", "informing"),
            row("我完全忘了时间。", "Explain why you worked late.", "I completely lost track of time.", "That happens when you're focused.", "lost track of time", "忘了时间", "explaining"),
            row("我需要歇一下。", "Say you need a short break.", "I need a quick break.", "Go for it. I'll watch your stuff.", "a quick break", "短暂休息", "requesting"),
            row("你的项目进展怎么样？", "Ask a classmate about their project.", "How's your project coming along?", "It's getting there, slowly.", "coming along", "进展如何", "asking"),
            row("我还在摸索。", "Say that you are still figuring out a task.", "I'm still figuring it out.", "Let me know if you get stuck.", "figuring it out", "摸索清楚", "explaining"),
            row("今天就到这儿吧。", "Suggest stopping work for the day.", "Let's call it a day.", "Good idea. I'm exhausted.", "call it a day", "今天到此为止", "suggesting"),
        ],
    ),
    (
        "requests",
        "请求与互相帮忙",
        "Asking for small favors",
        "把求助、借东西、留位置说得自然，不像翻译腔。",
        [
            row("你能帮我一个忙吗？", "Ask a friend for a small favor.", "Could you do me a favor?", "Sure. What do you need?", "do me a favor", "帮我一个忙", "requesting"),
            row("你能搭把手吗？", "Ask someone to help briefly.", "Can you give me a hand?", "Yeah, what are you working on?", "give me a hand", "搭把手", "requesting"),
            row("麻烦你把那个发过来？", "Ask for a file or message politely.", "Would you mind sending that over?", "Not at all. I'll send it now.", "send that over", "发过来", "requesting"),
            row("我能借一下充电器吗？", "Ask to borrow a charger.", "Can I borrow your charger?", "Sure, here you go.", "borrow your charger", "借你的充电器", "requesting"),
            row("能帮我留个位置吗？", "Ask someone to save a seat.", "Could you save me a seat?", "Of course. I'll be right here.", "save me a seat", "帮我留座位", "requesting"),
            row("我加入你们可以吗？", "Ask to join a group casually.", "Do you mind if I join you?", "Not at all. Come sit with us.", "join you", "加入你们", "requesting"),
            row("这次算我欠你的。", "Thank someone for a favor.", "I owe you one.", "Anytime.", "owe you one", "欠你一次人情", "thanking"),
            row("你真是救星。", "Thank someone who solved a problem.", "You're a lifesaver.", "Happy to help.", "You're a lifesaver", "你真是救星", "thanking"),
            row("不急，你有空再弄。", "Tell someone there is no rush.", "No rush—whenever you get a chance.", "Thanks, I'll get to it tonight.", "whenever you get a chance", "你有空再弄", "reassuring"),
            row("需要什么就跟我说。", "Offer help in return.", "Let me know if you need anything.", "I will. Thanks.", "Let me know", "有需要告诉我", "offering"),
        ],
    ),
    (
        "invitations",
        "邀请与社交安排",
        "Inviting people and making social plans",
        "练习发出邀请、接受、婉拒和临时改变主意。",
        [
            row("要不要喝杯咖啡？", "Invite a friend for a casual coffee.", "Want to grab a coffee?", "Sure. There's a new place nearby.", "grab a coffee", "喝杯咖啡", "inviting"),
            row("你今晚有安排吗？", "Ask about someone's evening.", "Are you doing anything tonight?", "Not really. Why?", "doing anything tonight", "今晚有安排", "asking"),
            row("你想出去玩吗？", "Suggest going out.", "Do you feel like going out?", "Maybe. What did you have in mind?", "feel like going out", "想出去", "inviting"),
            row("你应该跟我们一起来。", "Invite someone to join a group.", "You should come with us.", "Okay, what time are you leaving?", "come with us", "跟我们来", "inviting"),
            row("我参加。", "Accept a plan enthusiastically.", "I'm in.", "Nice. I'll send you the details.", "I'm in", "我参加", "accepting"),
            row("我今晚不太想出门。", "Decline an invitation honestly but gently.", "I'm not really up for it tonight.", "No worries. Get some rest.", "not really up for it", "不太想做", "declining"),
            row("下次吧。", "Turn down a plan without closing the door.", "Maybe next time.", "Sure, we'll find another day.", "Maybe next time", "下次吧", "declining"),
            row("听起来不错。", "Accept a casual suggestion.", "Sounds good to me.", "Great, I'll book it.", "Sounds good to me", "听起来不错", "accepting"),
            row("你想吃什么？", "Ask what someone feels like doing or eating.", "What are you in the mood for?", "Something quick and easy.", "in the mood for", "想要什么", "asking"),
            row("我们随便一点就好。", "Suggest keeping a plan low-key.", "Let's keep it casual.", "Perfect. No need to dress up.", "keep it casual", "随意一点", "suggesting"),
        ],
    ),
    (
        "shopping",
        "购物与退换",
        "Shopping without textbook phrases",
        "从试穿、比价到付款和退货，覆盖真实购物对话。",
        [
            row("我先随便看看，谢谢。", "Tell a shop assistant you do not need help yet.", "I'm just looking, thanks.", "Of course. Let me know if you need anything.", "just looking", "随便看看", "responding"),
            row("这个有别的尺码吗？", "Ask for another size.", "Do you have this in a different size?", "Let me check in the back.", "different size", "别的尺码", "asking"),
            row("我能试一下吗？", "Ask to try on a piece of clothing.", "Can I try this on?", "Sure, the fitting rooms are over there.", "try this on", "试穿", "requesting"),
            row("有没有便宜一点的？", "Ask for a cheaper option.", "Do you have anything a little cheaper?", "This one is on sale.", "a little cheaper", "便宜一点", "asking"),
            row("这个穿起来更舒服。", "Compare two items while shopping.", "This one feels more comfortable.", "It also comes in black.", "feels more comfortable", "穿起来更舒服", "comparing"),
            row("我就买这个了。", "Decide to buy an item.", "I'll take it.", "Great. I'll ring you up.", "I'll take it", "我买这个", "deciding"),
            row("我能刷卡吗？", "Ask about payment.", "Can I pay by card?", "Sure, just tap here.", "pay by card", "刷卡付款", "asking"),
            row("我好像被扣了两次钱。", "Report a possible duplicate charge.", "I think I was charged twice.", "Let me check that for you.", "charged twice", "被扣了两次钱", "complaining"),
            row("我想退这个。", "Ask to return an item.", "I'd like to return this.", "Do you still have the receipt?", "return this", "退这个", "requesting"),
            row("小票你还留着吗？", "Ask whether the receipt is available.", "Do you still have the receipt?", "Yes, it's in my email.", "still have the receipt", "还留着小票", "asking"),
        ],
    ),
    (
        "dining",
        "吃饭与咖啡",
        "Eating out and getting coffee",
        "覆盖点单、推荐、打包、分账和临时需求。",
        [
            row("两位，有桌吗？", "Ask for a table at a restaurant.", "Could we get a table for two?", "Sure, right this way.", "a table for two", "两人桌", "requesting"),
            row("你推荐什么？", "Ask a server or friend for a recommendation.", "What do you recommend?", "The pasta is really good today.", "What do you recommend?", "你推荐什么", "asking"),
            row("我和他一样。", "Order the same thing as someone else.", "I'll have the same.", "And would you like anything to drink?", "have the same", "点一样的", "ordering"),
            row("能帮我打包吗？", "Ask to take food away.", "Can I get this to go?", "Sure. I'll pack it up for you.", "get this to go", "打包带走", "requesting"),
            row("麻烦买单。", "Ask for the bill.", "Could we get the check, please?", "I'll bring it right over.", "get the check", "买单", "requesting"),
            row("我快饿死了。", "Say you are very hungry in a casual way.", "I'm starving.", "Let's find something quick.", "I'm starving", "饿坏了", "expressing"),
            row("这个真的很好吃。", "Compliment food naturally.", "This is really good.", "Right? I want to try everything here.", "really good", "真的很好吃", "reacting"),
            row("我对坚果过敏。", "Mention a food allergy before ordering.", "I'm allergic to nuts.", "Thanks for letting me know. I'll check with the kitchen.", "allergic to nuts", "对坚果过敏", "informing"),
            row("我们平摊吧。", "Suggest splitting the bill.", "Can we split the bill?", "Sure, let's do it evenly.", "split the bill", "平摊账单", "requesting"),
            row("要不要一起分个甜点？", "Suggest sharing dessert.", "Do you want to share a dessert?", "Absolutely. The cheesecake looks good.", "share a dessert", "一起分甜点", "suggesting"),
        ],
    ),
    (
        "transport",
        "出行与交通",
        "Getting around town",
        "坐公交、赶车、打车和约地点时使用的短句。",
        [
            row("这里有人坐吗？", "Ask whether a seat is free.", "Is this seat taken?", "No, go ahead.", "seat taken", "座位有人吗", "asking"),
            row("这趟车去市中心吗？", "Check a bus route.", "Does this bus go downtown?", "Yes, but you need to get off at Main Street.", "go downtown", "去市中心", "asking"),
            row("我觉得我们坐过站了。", "Notice that you missed your stop.", "I think we missed our stop.", "Let's get off at the next one.", "missed our stop", "坐过站", "realizing"),
            row("从这里过去要多久？", "Ask about travel time.", "How long does it take from here?", "About twenty minutes on foot.", "how long does it take", "要多久", "asking"),
            row("火车晚点了。", "Explain a delay.", "The train is running late.", "Again? That's so annoying.", "running late", "晚点", "informing"),
            row("我们打车吧。", "Suggest taking a taxi.", "Let's grab a cab.", "Good idea. It's starting to rain.", "grab a cab", "打车", "suggesting"),
            row("在这里让我下就行。", "Tell a driver where to drop you off.", "You can drop me off here.", "Sure, no problem.", "drop me off", "让我下车", "requesting"),
            row("我得给交通卡充值。", "Say that you need to top up a transit card.", "I need to top up my card.", "There's a machine by the entrance.", "top up my card", "给卡充值", "informing"),
            row("我该坐哪条线？", "Ask which subway line to take.", "Which line do I need?", "Take the blue line and change at Central.", "Which line do I need?", "需要哪条线", "asking"),
            row("车站见。", "Set a meeting point while travelling.", "I'll meet you at the station.", "Okay, I'll wait by the main entrance.", "at the station", "在车站", "confirming"),
        ],
    ),
    (
        "directions",
        "问路与找地点",
        "Finding a place",
        "问路、描述位置、发定位时使用的自然表达。",
        [
            row("请问，去这里怎么走？", "Ask a stranger for directions.", "Excuse me, how do I get to the museum?", "Go straight for two blocks and turn right.", "how do I get to", "怎么去", "asking"),
            row("走路能到吗？", "Ask whether a place is walkable.", "Is it within walking distance?", "Yeah, it's about ten minutes away.", "within walking distance", "走路能到", "asking"),
            row("一直走然后左转。", "Give simple directions.", "Just go straight and turn left.", "Got it. Thanks.", "go straight and turn left", "直走然后左转", "directing"),
            row("就在拐角那边。", "Describe a nearby location.", "It's right around the corner.", "Oh, I see it now.", "right around the corner", "就在拐角处", "describing"),
            row("你肯定不会错过。", "Reassure someone about a landmark.", "You can't miss it.", "Perfect. Thanks for your help.", "can't miss it", "不会错过", "reassuring"),
            row("我觉得我们走错了。", "Suggest that the group is lost.", "I think we're going the wrong way.", "Let's check the map.", "going the wrong way", "走错方向", "realizing"),
            row("能在地图上指给我看吗？", "Ask someone to point out a place.", "Could you point it out on the map?", "Sure, it's right here.", "point it out", "指出来", "requesting"),
            row("我们问问别人吧。", "Suggest asking another person for directions.", "Let's ask someone.", "Good call.", "ask someone", "问问别人", "suggesting"),
            row("就在银行对面。", "Give a landmark-based direction.", "It's across from the bank.", "That helps a lot.", "across from the bank", "在银行对面", "describing"),
            row("我把定位发你。", "Offer to share your location.", "I'll send you my location.", "Great, I can see where you are.", "send my location", "发定位", "offering"),
        ],
    ),
    (
        "calls",
        "电话与消息",
        "Calls, texts, and quick messages",
        "练习接电话、听不清、回拨、发地址和暂时没空。",
        [
            row("你能听清我吗？", "Check the audio on a call.", "Can you hear me okay?", "Yeah, you're coming through now.", "hear me okay", "听清我吗", "checking"),
            row("信号太差了。", "Complain about a weak connection.", "The connection is terrible.", "Want to try again?", "connection is terrible", "信号很差", "complaining"),
            row("我回头打给你。", "End a call and promise to call back.", "I'll call you back.", "Okay, talk soon.", "call you back", "回头打给你", "promising"),
            row("不好意思，我刚没接到。", "Explain a missed call.", "Sorry, I missed your call.", "No worries. I just had a quick question.", "missed your call", "没接到你的电话", "apologizing"),
            row("把地址发我一下。", "Ask someone to text an address.", "Can you text me the address?", "Sure, sending it now.", "text me the address", "把地址发我", "requesting"),
            row("我手机快没电了。", "Warn someone about low battery.", "I'm about to lose my battery.", "No problem. We can keep it quick.", "about to lose my battery", "手机快没电", "informing"),
            row("你那边断断续续的。", "Tell someone their audio keeps cutting out.", "You're breaking up.", "I'll move somewhere quieter.", "breaking up", "声音断断续续", "repairing"),
            row("我们改视频吧。", "Suggest switching from a voice call.", "Let's switch to a video call.", "Sure, I'll send a new link.", "switch to a video call", "改成视频通话", "suggesting"),
            row("我现在不方便说话。", "Say you cannot talk at the moment.", "I can't talk right now.", "Okay, just text me later.", "can't talk right now", "现在不方便说话", "informing"),
            row("我发给你。", "Promise to send a file or photo.", "I'll send it over.", "Thanks, I need it for the form.", "send it over", "发给你", "promising"),
        ],
    ),
    (
        "health",
        "身体与状态",
        "Talking about how you feel",
        "表达不舒服、休息、预约和关心别人，保持自然和清楚。",
        [
            row("我感觉有点不对劲。", "Say that you do not feel normal.", "I'm feeling a bit off.", "You should take it easy today.", "feeling a bit off", "感觉不太对", "expressing"),
            row("我昨晚没睡好。", "Explain why you are tired.", "I didn't sleep well.", "You look exhausted.", "didn't sleep well", "没睡好", "explaining"),
            row("我嗓子疼得厉害。", "Describe a sore throat casually.", "My throat is killing me.", "Have you tried some tea?", "throat is killing me", "嗓子疼得厉害", "expressing"),
            row("我今天得好好休息。", "Say you need a quiet day.", "I need to take it easy today.", "Stay home if you can.", "take it easy", "放松休息", "informing"),
            row("你最近休息够吗？", "Check on someone's rest.", "Have you been getting enough rest?", "Not really, to be honest.", "getting enough rest", "休息够不够", "asking"),
            row("我好像要生病了。", "Say that you may be coming down with something.", "I think I'm coming down with something.", "Maybe you should go home early.", "coming down with something", "可能要生病", "expressing"),
            row("我现在好多了。", "Tell someone your condition has improved.", "I'm feeling much better now.", "That's good to hear.", "feeling much better", "感觉好多了", "informing"),
            row("你最好去看看。", "Suggest that someone get a symptom checked.", "You should get that checked out.", "You're probably right.", "get that checked out", "去检查一下", "advising"),
            row("我得预约一下。", "Say you need to make a medical appointment.", "I need to book an appointment.", "I can help you find a clinic.", "book an appointment", "预约", "informing"),
            row("别硬撑。", "Tell a friend not to push themselves.", "Don't push yourself.", "I'll try to slow down.", "push yourself", "勉强自己", "advising"),
        ],
    ),
    (
        "problems",
        "问题与投诉",
        "Handling everyday problems",
        "表达订单、软件和服务出了问题，同时保持清楚和有礼貌。",
        [
            row("好像有点不对。", "Point out a problem without being aggressive.", "Something's not right.", "What seems to be the problem?", "Something's not right", "好像不对", "complaining"),
            row("这不是我点的。", "Tell a server that the order is wrong.", "This isn't what I ordered.", "I'm sorry. I'll fix it right away.", "what I ordered", "我点的东西", "complaining"),
            row("这个软件一直闪退。", "Report a recurring app problem.", "The app keeps crashing.", "Try updating it first.", "keeps crashing", "一直闪退", "complaining"),
            row("我等了老半天。", "Complain about a long wait.", "I've been waiting for ages.", "I'm sorry about the delay.", "waiting for ages", "等了很久", "complaining"),
            row("你能帮我看看吗？", "Ask staff to inspect a problem.", "Could you take a look at this?", "Sure, let me see what happened.", "take a look at this", "看看这个问题", "requesting"),
            row("别人之前不是这么告诉我的。", "Point out conflicting information.", "That's not what I was told.", "Let me check the details again.", "what I was told", "之前被告知的内容", "complaining"),
            row("我明白，但问题还在。", "Stay firm while remaining polite.", "I understand, but this is still a problem.", "You're right. Let me find another option.", "still a problem", "问题仍然存在", "complaining"),
            row("你们能想办法吗？", "Ask for a solution.", "Is there anything you can do?", "I can offer you a replacement.", "anything you can do", "能做点什么吗", "requesting"),
            row("谢谢你处理好了。", "Thank someone after a problem is fixed.", "Thanks for sorting that out.", "You're welcome. Sorry again.", "sort that out", "把问题处理好", "thanking"),
            row("这次我就算了。", "Let a minor problem go this time.", "I'll let it go this time.", "I appreciate that.", "let it go", "算了／不再追究", "deciding"),
        ],
    ),
    (
        "apologies",
        "道歉与失误",
        "Apologising without sounding stiff",
        "日常犯错、迟到、打断和接受道歉的自然说法。",
        [
            row("我的错。", "Own a small mistake immediately.", "My bad.", "It's okay. No big deal.", "My bad", "我的错", "apologizing"),
            row("不好意思，我完全忘了。", "Apologise for forgetting something.", "Sorry, I completely forgot.", "It happens. Just do it when you can.", "completely forgot", "完全忘了", "apologizing"),
            row("抱歉打断一下。", "Apologise before interrupting.", "I didn't mean to interrupt.", "Go ahead, what were you saying?", "mean to interrupt", "想要打断", "apologizing"),
            row("不好意思让你等了。", "Apologise for making someone wait.", "Sorry to keep you waiting.", "No worries. I just got here too.", "keep you waiting", "让你等", "apologizing"),
            row("这事怪我。", "Take responsibility for a mistake.", "That's on me.", "Thanks for saying that.", "That's on me", "这事怪我", "apologizing"),
            row("没事。", "Accept a casual apology.", "No worries.", "Thanks for understanding.", "No worries", "没事／别担心", "reassuring"),
            row("不会再这样了。", "Promise not to repeat a mistake.", "It won't happen again.", "I appreciate that.", "won't happen again", "不会再发生", "promising"),
            row("我应该早点告诉你的。", "Admit that you should have warned someone.", "I should've told you sooner.", "It's okay. At least I know now.", "told you sooner", "早点告诉你", "apologizing"),
            row("谢谢你理解。", "Thank someone for being patient.", "Thanks for understanding.", "Of course.", "Thanks for understanding", "谢谢你理解", "thanking"),
            row("别放在心上。", "Tell someone not to worry about a mistake.", "Don't worry about it.", "Are you sure?", "worry about it", "把它放在心上", "reassuring"),
        ],
    ),
    (
        "storytelling",
        "自然讲述经历",
        "Telling a story in everyday English",
        "用连接词、停顿和反应把一件小事讲完整。",
        [
            row("猜猜我今天遇到什么了。", "Start a surprising story.", "Guess what happened today.", "What? Tell me everything.", "Guess what happened", "猜猜发生了什么", "starting"),
            row("长话短说……", "Skip unnecessary details in a story.", "So, long story short...", "Okay, what happened?", "long story short", "长话短说", "organizing"),
            row("我回家的路上……", "Set the scene for a story.", "I was on my way home when...", "Oh no. What happened?", "on my way home", "在回家的路上", "starting"),
            row("一开始我以为……", "Describe your first impression of a situation.", "At first, I thought...", "And then you realized you were wrong?", "At first, I thought", "一开始我以为", "narrating"),
            row("后来事情变得很奇怪。", "Move a story toward an unexpected turn.", "Then things got weird.", "Now I really want to know.", "things got weird", "事情变奇怪了", "narrating"),
            row("有意思的是……", "Add a surprising detail.", "The funny thing is...", "What was funny about it?", "The funny thing is", "有意思的是", "narrating"),
            row("结果我比计划晚待了很久。", "Explain how a plan changed.", "I ended up staying way longer than planned.", "That sounds like a good sign.", "ended up staying", "结果待了下来", "narrating"),
            row("我完全不知道发生了什么。", "Describe being confused in a story.", "I had no idea what was going on.", "Were you able to ask someone?", "no idea what was going on", "完全不知道怎么回事", "narrating"),
            row("我就是这样认识她的。", "Finish a story about meeting someone.", "And that's how I met her.", "That's actually a great story.", "that's how I met her", "我就是这样认识她的", "concluding"),
            row("你得在现场才知道。", "Say that an experience is hard to explain.", "You had to be there.", "I wish I had been.", "You had to be there", "你得在现场才知道", "reacting"),
        ],
    ),
    (
        "relationships",
        "朋友与关系",
        "Talking about friends and relationships",
        "描述相处、分歧、边界和想念，避免像教科书一样抽象。",
        [
            row("我们认识很多年了。", "Describe a long friendship.", "We've known each other for years.", "You two seem really close.", "known each other for years", "认识很多年", "describing"),
            row("我们不总是意见一致，但……", "Describe a relationship honestly.", "We don't always agree, but we get along.", "That's what matters.", "don't always agree", "不总是同意", "describing"),
            row("她很容易相处。", "Describe someone who is easy to talk to.", "She's easy to talk to.", "I can see why you like her.", "easy to talk to", "容易相处／好聊天", "describing"),
            row("我需要一点空间。", "Set a gentle personal boundary.", "I need some space.", "Okay. I'll give you time.", "need some space", "需要一点空间", "requesting"),
            row("我们还在摸索。", "Describe a relationship that is not settled yet.", "We're still figuring things out.", "That can take time.", "figuring things out", "还在摸索", "describing"),
            row("我不想把事情弄得尴尬。", "Avoid making a situation awkward.", "I don't want to make it awkward.", "We can just keep it simple.", "make it awkward", "弄得尴尬", "reassuring"),
            row("他是好心。", "Explain that someone's intention is good.", "He means well.", "Yeah, he just has a funny way of showing it.", "means well", "出于好意", "describing"),
            row("我们应该谈谈这件事。", "Suggest an honest conversation.", "We should talk about it.", "I agree. When are you free?", "talk about it", "谈谈这件事", "suggesting"),
            row("我想念和他们一起玩。", "Say you miss spending time with friends.", "I miss hanging out with them.", "You should give them a call.", "hanging out with them", "和他们一起玩", "expressing"),
            row("别想太多了。", "Tell a friend not to overanalyse a relationship.", "Let's not overthink it.", "You're probably right.", "overthink it", "想太多", "reassuring"),
        ],
    ),
    (
        "screen-dialogue",
        "影视与音乐",
        "Talking about shows and music",
        "用轻松的方式聊最近在看的剧、听的歌和意外的剧情。",
        [
            row("你看新一季了吗？", "Ask about a recently released season.", "Have you seen the new season?", "Not yet. Is it any good?", "seen the new season", "看了新一季", "asking"),
            row("我最近迷上这部剧了。", "Say that a show has pulled you in.", "I'm hooked on this show.", "Same. I watched three episodes last night.", "hooked on this show", "迷上这部剧", "reacting"),
            row("这一集太好看了。", "React to an entertaining episode.", "This episode is so good.", "Right? The ending was wild.", "episode is so good", "这一集太好看", "reacting"),
            row("这首歌我停不下来。", "Say you keep listening to a song.", "I can't stop listening to this song.", "Send it to me. I want to hear it.", "can't stop listening", "停不下来地听", "reacting"),
            row("那个人是谁？", "Ask about an actor or singer.", "Who is that actor?", "He's in a few other shows too.", "Who is that actor?", "那个演员是谁", "asking"),
            row("我完全没想到会这样。", "React to an unexpected plot twist.", "I didn't see that coming.", "Me neither. They fooled us both.", "didn't see that coming", "没想到会这样", "reacting"),
            row("结尾有点奇怪。", "Give a mixed review of a show.", "The ending was kind of weird.", "I know. It felt rushed.", "kind of weird", "有点奇怪", "commenting"),
            row("这不是我的菜。", "Say that a genre is not for you.", "It's not really my thing.", "Fair enough. What do you like?", "not really my thing", "不是我的菜", "commenting"),
            row("再看一集吧。", "Suggest continuing a show.", "Let's watch one more.", "Okay, but then I'm going to bed.", "one more", "再来一个", "suggesting"),
            row("你最近在看什么？", "Start a casual conversation about media.", "What have you been watching lately?", "Mostly comedies and documentaries.", "been watching lately", "最近在看什么", "asking"),
        ],
    ),
    (
        "reading",
        "阅读与观点",
        "Sharing opinions about things you read",
        "聊书、文章和观点时，练习赞同、保留意见和继续追问。",
        [
            row("你最近看过什么好东西吗？", "Ask for a reading recommendation.", "Have you read anything good lately?", "Actually, I found a great short book.", "anything good lately", "最近有什么好东西", "asking"),
            row("我一拿起来就放不下了。", "Say that a book was hard to stop reading.", "I couldn't put it down.", "That's a strong recommendation.", "couldn't put it down", "放不下／停不下来", "reacting"),
            row("我明白你的意思。", "Show that you understand an opinion.", "I see what you mean.", "It's not an easy idea, though.", "see what you mean", "明白你的意思", "agreeing"),
            row("这个角度挺有意思。", "Respond to an unusual viewpoint.", "That's an interesting take.", "I hadn't thought about it that way.", "interesting take", "有意思的观点", "reacting"),
            row("我不确定我信这个。", "Politely question a claim.", "I'm not sure I buy that.", "What part do you disagree with?", "not sure I buy that", "不太相信这个说法", "disagreeing"),
            row("重点是……", "Summarise the central point.", "The main point is...", "Right, and the example makes it clear.", "The main point is", "重点是", "summarizing"),
            row("这让我想起……", "Connect an idea to another experience.", "It reminded me of...", "Really? What did it remind you of?", "reminded me of", "让我想起", "connecting"),
            row("我得想想。", "Ask for time before giving an opinion.", "I need to think about that.", "Sure. Take your time.", "think about that", "想想这件事", "stalling"),
            row("那我们就各有看法吧。", "End a friendly disagreement.", "Let's agree to disagree.", "Fair enough.", "agree to disagree", "求同存异", "disagreeing"),
            row("你怎么看？", "Ask for someone's reaction to a book or idea.", "What did you make of it?", "I liked it more than I expected.", "make of it", "怎么看／如何理解", "asking"),
        ],
    ),
    (
        "everyday-logistics",
        "日常事务与家里",
        "Small everyday logistics",
        "处理买东西、找钥匙、家务和出门前的各种小事。",
        [
            row("我得出去办几件事。", "Explain why you are heading out.", "I need to run a few errands.", "Want me to come with you?", "run a few errands", "办几件事", "informing"),
            row("家里没咖啡了。", "Notice that a household item is gone.", "I'm out of coffee.", "I'll pick some up on the way home.", "out of coffee", "咖啡用完了", "informing"),
            row("你能顺路买点牛奶吗？", "Ask someone to pick something up.", "Can you pick up some milk?", "Sure, anything else?", "pick up some milk", "顺路买牛奶", "requesting"),
            row("水槽又漏了。", "Report a recurring household problem.", "The sink is leaking again.", "I'll call the landlord tomorrow.", "leaking again", "又漏了", "complaining"),
            row("我来处理。", "Take responsibility for a small task.", "I'll take care of it.", "Thanks. That would help a lot.", "take care of it", "处理它", "offering"),
            row("我把钥匙放哪了？", "Think aloud while looking for keys.", "Where did I put my keys?", "Check the table by the door.", "Where did I put", "我把……放哪了", "searching"),
            row("客人来之前收拾一下吧。", "Suggest tidying before guests arrive.", "Let's clean this up before guests arrive.", "Good idea. I'll do the kitchen.", "clean this up", "收拾干净", "suggesting"),
            row("我忘记给手机充电了。", "Explain why your phone is nearly dead.", "I forgot to charge my phone.", "You can use my charger.", "forgot to charge", "忘记充电", "explaining"),
            row("要我带点什么吗？", "Offer to bring something.", "Do you want me to bring anything?", "Maybe some snacks if you don't mind.", "bring anything", "带点什么", "offering"),
            row("这样应该就行了。", "Confirm that a small task is complete.", "That should do it.", "Looks good to me.", "should do it", "应该就行了", "confirming"),
        ],
    ),
    (
        "campus-teacher-greetings",
        "校园遇见老师",
        "Greeting teachers around campus",
        "在校园、教室门口和课后自然问候外籍老师，开启简短交流。",
        [
            row("嗨，老师，今天过得怎么样？", "Greet a teacher you meet on campus.", "Hi, Professor. How's your day going?", "Pretty good, thanks. How about you?", "How's your day going?", "今天过得怎么样", "greeting"),
            row("早上好！我们今天还是在204教室吗？", "Confirm the classroom with your teacher.", "Good morning! Are we still in Room 204 today?", "Yes, I'll see you there.", "Are we still in Room 204?", "我们还是在204教室吗", "confirming"),
            row("我在走廊看到您，就想过来打个招呼。", "Start a brief, friendly exchange outside class.", "I saw you in the hallway and wanted to say hi.", "That's nice of you. How's the semester going?", "I wanted to say hi", "我想来打个招呼", "greeting"),
            row("昨天的工作坊进行得怎么样？", "Make light conversation about a recent class event.", "How did the workshop go yesterday?", "It went well. A lot of students joined in.", "How did it go?", "进行得怎么样", "smallTalk"),
            row("您有空聊一分钟吗，还是正要去上课？", "Check whether your teacher can talk right now.", "Are you free for a minute, or are you on your way to class?", "I have a minute. What's up?", "Are you free for a minute?", "您有空聊一分钟吗", "requesting"),
            row("希望我没有在您不方便的时候来打扰。", "Soften a quick request to a busy teacher.", "I hope I'm not catching you at a bad time.", "Not at all. Go ahead.", "catching you at a bad time", "在不方便的时候打扰你", "apology"),
            row("谢谢您昨天课后留下来。", "Thank your teacher for giving you extra time.", "Thanks for staying after class yesterday.", "Of course. I'm glad we could sort it out.", "staying after class", "课后留下来", "gratitude"),
            row("我本来想问您一件事，但课后再问也可以。", "Tell your teacher you can wait instead of interrupting.", "I wanted to ask you something, but it can wait until after class.", "Sure. Just catch me afterward.", "it can wait until after class", "可以等到课后", "requesting"),
            row("课堂上见。", "End a brief campus exchange naturally.", "See you in class.", "See you.", "See you in class", "课堂上见", "farewell"),
            row("老师，祝您周末愉快。", "Say goodbye to a teacher before the weekend.", "Have a good weekend, Professor.", "You too. See you on Monday.", "Have a good weekend", "祝周末愉快", "farewell"),
        ],
    ),
    (
        "asking-teacher-help",
        "请教老师与约时间",
        "Asking a teacher for help",
        "课后请教外籍老师、说明卡点、约时间并确认后续做法。",
        [
            row("我可以请教您作业的问题吗？", "Open a polite conversation about coursework.", "Could I ask you about the assignment?", "Sure. What are you working on?", "Could I ask you about ...?", "我可以请教您……吗", "requesting"),
            row("您课后有几分钟时间吗？", "Ask a teacher for a short meeting.", "Would you have a few minutes after class?", "Yes, I can meet you outside the classroom.", "Would you have a few minutes?", "您有几分钟时间吗", "requesting"),
            row("我卡在第二部分了。", "Explain exactly where you need help.", "I'm stuck on the second part.", "Let's look at that part together.", "I'm stuck on ...", "我卡在……了", "reportingProblem"),
            row("您能给我指一下方向吗？", "Ask for guidance without asking the teacher to do the work.", "Could you point me in the right direction?", "Start by comparing these two examples.", "point me in the right direction", "给我指一下方向", "requesting"),
            row("我试着这样做了，但不知道漏了什么。", "Show your attempt before asking for feedback.", "I tried it this way, but I'm not sure what I'm missing.", "Your approach is fine; check this step again.", "I'm not sure what I'm missing", "我不确定自己漏了什么", "requestingFeedback"),
            row("您能推荐一些我可以阅读的材料吗？", "Ask for a useful extra resource.", "Could you recommend something I can read?", "I'll send you an article after class.", "recommend something I can read", "推荐一些我可以阅读的材料", "requesting"),
            row("我之后通过邮件再问一个问题，可以吗？", "Ask how to continue the conversation later.", "Would it be okay if I sent you a follow-up question by email?", "Of course. Put the course name in the subject line.", "a follow-up question", "后续问题", "requesting"),
            row("我想确认一下自己对这个术语的用法是否正确。", "Check your use of a key academic word.", "I want to make sure I'm using the term correctly.", "Yes, that's the right way to use it here.", "make sure I'm using ... correctly", "确认自己是否正确使用……", "clarifying"),
            row("谢谢，这下我明白了。", "Close a helpful explanation naturally.", "Thanks, that clears things up.", "You're welcome. Let me know if anything else comes up.", "that clears things up", "这下把问题讲清楚了", "gratitude"),
            row("我再试一次，有结果后告诉您。", "State your next step after receiving guidance.", "I'll try it again and let you know how it goes.", "Sounds good. Take your time.", "let you know how it goes", "告诉你进展如何", "confirming"),
        ],
    ),
    (
        "classroom-questions",
        "课堂提问与澄清",
        "Asking questions in class",
        "上课时礼貌打断、追问、确认术语并请老师举例说明。",
        [
            row("不好意思，您能再讲一下刚才最后一点吗？", "Ask the teacher to repeat a key point.", "Sorry, could you go over that last point?", "Sure. Let me put it another way.", "go over that last point", "再讲一下刚才那一点", "clarifying"),
            row("您能给我们举个例子吗？", "Ask for a concrete example during a lecture.", "Could you give us an example?", "Sure. Think about this case.", "give us an example", "给我们举个例子", "requesting"),
            row("这个术语在这里是什么意思？", "Ask about the meaning of a word in the lecture.", "What does this term mean in this context?", "Here, it means the opposite of the usual assumption.", "in this context", "在这个语境下", "clarifying"),
            row("您的意思是这两个术语有关联吗？", "Check your interpretation before moving on.", "Do you mean that the two terms are related?", "They're related, but they're not interchangeable.", "Do you mean that ...?", "您的意思是……吗", "confirming"),
            row("您能说慢一点吗？", "Ask for a slower explanation without apologising too much.", "Could you say that a little more slowly?", "Of course. I'll slow down.", "a little more slowly", "稍微慢一点", "clarifying"),
            row("我不太理解这两个观点之间的联系。", "Explain precisely what is unclear.", "I'm not sure I understand the connection between these two ideas.", "The second idea is an example of the first one.", "the connection between ... and ...", "……和……之间的联系", "clarifying"),
            row("我可以问一个小问题吗？", "Politely take a turn during class.", "Can I ask a quick question?", "Of course. Go ahead.", "Can I ask a quick question?", "我可以问个小问题吗", "requesting"),
            row("我们应该从这篇阅读材料的哪里开始？", "Ask how to approach a reading task.", "Where should we start with this reading?", "Start with the introduction and the first example.", "Where should we start?", "我们应该从哪里开始", "requesting"),
            row("这是我们需要放进展示里的部分吗？", "Confirm what belongs in a class presentation.", "Is this the part we need to include in the presentation?", "Yes, but keep it brief.", "the part we need to include", "我们需要包含的部分", "confirming"),
            row("您能重复一下问题吗？", "Ask the teacher to repeat a question before answering.", "Could you repeat the question, please?", "Sure. What is the author's main point?", "repeat the question", "重复问题", "clarifying"),
        ],
    ),
    (
        "classroom-answers",
        "课堂回答与讨论",
        "Answering and joining class discussion",
        "回答老师提问、争取思考时间、补充同学观点并表达不确定。",
        [
            row("我觉得重点是语境很重要。", "Give a concise answer to a teacher's question.", "I think the main point is that context matters.", "Good. Can you explain why?", "the main point is that ...", "重点是……", "answering"),
            row("我的理解是，这两个观点是有关联的。", "State your interpretation clearly but not too strongly.", "My understanding is that the two ideas are connected.", "Exactly. That's the connection I mean.", "My understanding is that ...", "我的理解是……", "answering"),
            row("我觉得这个例子支持作者的论点。", "Answer with a reasoned opinion.", "I would say the example supports the author's argument.", "What in the example supports it?", "I would say ...", "我会认为……", "answering"),
            row("我不完全确定，但我觉得它和第二部分有关。", "Answer honestly when you are only partly sure.", "I'm not completely sure, but I think it relates to the second section.", "That's a reasonable starting point.", "I'm not completely sure, but ...", "我不完全确定，但……", "answering"),
            row("我可以想一下再回答吗？", "Buy a little time before answering aloud.", "Could I take a second to think about that?", "Of course. Take your time.", "take a second to think", "花一点时间想一想", "stalling"),
            row("我的看法有一点不同。", "Disagree with an idea without sounding confrontational.", "I see it a little differently.", "Okay. What is your take on it?", "I see it a little differently", "我的看法有一点不同", "disagreeing"),
            row("接着她刚才说的，我觉得这个例子体现了随时间的变化。", "Add a point to a classmate's answer.", "Building on what she said, I think the example shows a change over time.", "That's a useful addition.", "Building on what she said", "接着她刚才说的观点", "addingInformation"),
            row("我同意，尤其是因为证据很清楚。", "Agree with a classmate and give a reason.", "I agree with that, especially because the evidence is clear.", "Right. The evidence is hard to ignore.", "I agree with that, especially because ...", "我同意，尤其是因为……", "agreeing"),
            row("我不知道准确的词，但我可以解释这个意思。", "Keep speaking when one word does not come to mind.", "I don't know the exact word, but I can explain the idea.", "That's fine. Explain it in your own words.", "I don't know the exact word, but ...", "我不知道准确的词，但……", "selfRepair"),
            row("所以换句话说，语境会改变我们的理解。", "Summarise your answer in simpler words.", "So, in other words, the context changes how we understand it.", "Exactly. That's a good summary.", "in other words", "换句话说", "summarizing"),
        ],
    ),
]


def build() -> None:
    topics: list[dict] = []
    lessons: list[dict] = []
    sentences: list[dict] = []
    lexemes: list[dict] = []

    for number, (slug, title_zh, title_target, description, rows) in enumerate(TOPICS, 1):
        topic_id = f"en.topic.{number:02d}.{slug}"
        sentence_ids: list[str] = []
        for index, item in enumerate(rows, 1):
            sentence_id = f"{topic_id}.{index:02d}"
            expression_id = f"en.expression.{slug}.{index:02d}"
            focus_id = f"en.focus.{slug}.{index:02d}"
            source_path = f"curated/english/{slug}"
            sentence_ids.append(sentence_id)
            is_school_topic = slug in {
                "campus-teacher-greetings",
                "asking-teacher-help",
                "classroom-questions",
                "classroom-answers",
            }
            sentences.append(
                {
                    "id": sentence_id,
                    "language": "english",
                    "promptZh": item["promptZh"],
                    "cueText": item["cueText"],
                    "targetText": item["targetText"],
                    "displayText": item["targetText"],
                    "speechText": item["targetText"],
                    "theme": title_target,
                    "lexemeIDs": [expression_id, focus_id],
                    "dialogueAct": item["dialogueAct"],
                    "register": (
                        "polite"
                        if slug in {
                            "campus-teacher-greetings",
                            "asking-teacher-help",
                        }
                        else "neutral"
                        if is_school_topic
                        else "informal"
                    ),
                    "speakerRole": (
                        "student and international teacher"
                        if is_school_topic
                        else "friends or everyday conversation partners"
                    ),
                    "addressForm": "notApplicable",
                    "expectedReplies": [item["reply"]],
                    "variants": [],
                    "reviewStatus": "reviewed",
                    "provenanceType": "derived",
                    "sourcePath": source_path,
                    "sourceText": item["targetText"],
                    "qualityFlags": [],
                    "topicID": topic_id,
                }
            )
            lexemes.extend(
                [
                    {
                        "id": expression_id,
                        "language": "english",
                        "lemma": item["targetText"],
                        "displayForm": item["targetText"],
                        "speechText": item["targetText"],
                        "partOfSpeech": "spoken expression",
                        "glossZh": item["promptZh"],
                        "inflections": [],
                        "collocations": [item["targetText"]],
                        "phrasalVerbs": [],
                        "wordFamily": [],
                        "morphologyNotes": ["整句作为口语块提取，先按场景说，再核对文本。"],
                        "memoryNotes": [],
                        "exampleSentenceIDs": [sentence_id],
                        "reviewStatus": "reviewed",
                        "provenanceType": "derived",
                        "sourcePath": source_path,
                        "sourceText": item["targetText"],
                        "qualityFlags": [],
                    },
                    {
                        "id": focus_id,
                        "language": "english",
                        "lemma": item["focus"],
                        "displayForm": item["focus"],
                        "speechText": item["focus"],
                        "partOfSpeech": "high-frequency chunk",
                        "glossZh": item["focusZh"],
                        "inflections": [],
                        "collocations": [item["focus"]],
                        "phrasalVerbs": [],
                        "wordFamily": [],
                        "morphologyNotes": ["把这个句块作为整体提取，不要先逐词翻译。"],
                        "memoryNotes": [],
                        "exampleSentenceIDs": [sentence_id],
                        "reviewStatus": "reviewed",
                        "provenanceType": "derived",
                        "sourcePath": source_path,
                        "sourceText": item["targetText"],
                        "qualityFlags": [],
                    },
                ]
            )
        topics.append(
            {
                "descriptionZh": description,
                "id": topic_id,
                "language": "english",
                "sentenceIDs": sentence_ids,
                "titleTarget": title_target,
                "titleZh": title_zh,
            }
        )
        lessons.append(
            {
                "contextZh": description,
                "dialogueOrder": sentence_ids,
                "id": f"en.lesson.{slug}",
                "language": "english",
                "sentenceIDs": sentence_ids,
                "titleZh": title_zh,
                "topicID": topic_id,
            }
        )

    for name, payload in (
        ("english-topics.json", topics),
        ("english-lessons.json", lessons),
        ("english-sentences.json", sentences),
        ("english-lexemes.json", lexemes),
    ):
        (RESOURCES / name).write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )


if __name__ == "__main__":
    build()
