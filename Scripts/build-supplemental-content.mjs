#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const knowledgeRoot =
  "/Users/Openclawworkspace/Library/CloudStorage/OneDrive-个人/Documents/20-语言学习与专业/大学知识库（俄语学习+专业）";
const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const resourceRoot = path.join(
  repositoryRoot,
  "Sources/RussianCornerCore/Resources",
);

const sourcePaths = {
  hotel: "01-按学期/大二上/基础俄语/酒店主题.md",
  music: "01-按学期/！大二下/俄语/第三周作业.md",
  sport: "01-按学期/！大二下/俄语/Урок 5. О спорт, ты мир!.md",
  b1: "01-按学期/大一下——莫斯科/基础俄语/B1考试准备/B1 2025 口语 第2题 对话（问题）25个问题 Говорение. Задание 2. Вариант 2. Вопросы.md",
  prompts: "01-按学期/大二上/基础俄语/口语提问题目俄语.md",
};

const sourceCache = new Map();
function readSource(sourceKey) {
  const sourcePath = sourcePaths[sourceKey];
  if (!sourceCache.has(sourcePath)) {
    const bytes = fs.readFileSync(path.join(knowledgeRoot, sourcePath));
    sourceCache.set(sourcePath, {
      bytes,
      hash: crypto.createHash("sha256").update(bytes).digest("hex"),
      text: bytes.toString("utf8"),
    });
  }
  return { sourcePath, ...sourceCache.get(sourcePath) };
}

function sourceLine(sourceKey, needle) {
  const source = readSource(sourceKey);
  const matches = source.text
    .split(/\r?\n/u)
    .filter((line) => line.includes(needle));
  const uniqueMatches = [...new Set(matches.map((line) => line.trimEnd()))];
  if (uniqueMatches.length === 0) {
    throw new Error(
      `missing source text for ${sourceKey}:${needle}`,
    );
  }
  uniqueMatches.sort(
    (left, right) => left.length - right.length || left.localeCompare(right),
  );
  return { ...source, sourceText: uniqueMatches[0] };
}

const rawSentences = [
  // 酒店：8
  ["hotel", "Я недавно останавливался в хорошем отеле.", "我最近住过一家不错的酒店。", ["останавливаться"]],
  ["hotel", "Это был уютный четырёхзвёздочный отель.", "说明这家酒店是四星级的，而且很舒适。", ["четырёхзвёздочный", "уютный"], "Отель был четырёхзвёздочный и очень уютный."],
  ["hotel", "В номере были кондиционер и телевизор.", "说明房间配有空调和电视。", ["кондиционер"], "Номер был чистый, с кондиционером и телевизором."],
  ["hotel", "В номере каждый день делали уборку, а полотенца и халат всегда были чистыми.", "说明酒店每天打扫，毛巾和浴袍也一直很干净。", ["уборка", "полотенце", "халат"], "Каждый день была уборка, полотенца и халат всегда чистые."],
  ["hotel", "В отеле были бассейн и фитнес-центр — это мне очень понравилось.", "说酒店有泳池和健身中心，这一点你很喜欢。", ["бассейн", "фитнес-центр"], "В отеле был бассейн и фитнес-центр — это мне очень понравилось."],
  ["hotel", "Завтрак был включён в стоимость, а еда была вкусной.", "说明房费包含早餐，而且饭菜很好吃。", ["включённый"], "Завтрак был включён, еда вкусная."],
  ["hotel", "Но интернет работал плохо, и ночью было немного шумно.", "委婉抱怨酒店网络不好，晚上还有点吵。", ["шумно"]],
  ["hotel", "Несмотря на это, я остался доволен и хочу приехать туда снова.", "尽管有这些问题，仍表示满意并愿意再来。", ["несмотря", "довольный"]],

  // 音乐与感受：14
  ["music", "У меня есть особенная песня, которая для меня очень важна.", "说自己有一首非常重要的歌。", ["особенный"], "Моя важная песня — это песня «See You Again»."],
  ["music", "Я впервые услышал её несколько лет назад.", "说自己几年前第一次听到这首歌。", ["впервые"]],
  ["music", "Эта песня связана у меня с важным человеком.", "说这首歌会让自己联想到一个重要的人。", ["связанный"]],
  ["music", "Когда я слушаю её, я вспоминаю наше общение и время вместе.", "说听到这首歌时会想起彼此的交流和共度的时光。", ["вспоминать", "общение"]],
  ["music", "Для меня эта песня не просто красивая, но и очень трогательная.", "说明这首歌不只好听，而且很打动人。", ["трогательный"]],
  ["music", "Она напоминает мне о дружбе, расставании и тёплых воспоминаниях.", "说这首歌会让自己想起友情、分别和温暖的回忆。", ["напоминать", "расставание", "воспоминание"]],
  ["music", "Иногда я слушаю её, когда мне грустно или одиноко.", "说自己难过或孤单时偶尔会听这首歌。", ["одиноко"]],
  ["music", "Тогда мне становится спокойнее.", "说听完之后自己会平静一些。", ["спокойнее"]],
  ["music", "Мне нравится её мелодия и слова.", "说自己喜欢这首歌的旋律和歌词。", ["мелодия"]],
  ["music", "Я думаю, что у каждой важной песни есть своя история.", "表达每一首重要的歌都有自己的故事。", ["история"]],
  ["music", "Для меня эта песня всегда будет особенной.", "说这首歌对自己而言会一直很特别。", ["особенный"]],
  ["music", "Эта песня напоминает мне о важных людях в моей жизни.", "说这首歌会让自己想到生命中重要的人。", ["напоминать"], "Эта песня помогает мне думать о важных людях в моей жизни."],
  ["music", "Каждый раз, когда я её слышу, у меня появляются сильные чувства.", "说每次听到这首歌都会产生强烈的感受。", ["чувство"]],
  ["music", "Поэтому она занимает важное место в моей жизни.", "说明这首歌在自己的生活中占有重要位置。", ["занимать"]],

  // 运动：19
  ["sport", "Можно показать, как я веду мяч и бросаю его в корзину.", "描述自己运球并把球投进篮筐。", ["бросать", "корзина"]],
  ["sport", "Можно показать, как я бью по мячу ногой.", "说明可以用踢球的动作来表示足球。", ["бить"]],
  ["sport", "Можно показать движения руками, как при плавании.", "说明可以用手臂动作来模仿游泳。", ["плавание"], "Можно показать движения руками, как будто я плыву."],
  ["sport", "Можно показать, как я держу клюшку и бью по шайбе.", "描述拿着球杆击打冰球的动作。", ["клюшка", "шайба"]],
  ["sport", "Можно показать, как я думаю и двигаю шахматную фигуру.", "描述思考并移动棋子的动作。", ["шахматный", "фигура"]],
  ["sport", "Можно показать, как я еду на лыжах.", "说明可以用动作模仿滑雪。", ["лыжи"]],
  ["sport", "У студентов такие новости: в понедельник у них первое занятие по спорту.", "说学生们周一有第一节体育课。", ["занятие"]],
  ["sport", "Линь выбрал каратэ, потому что считает, что каратэ — это не только физическая, но и психологическая борьба.", "说明空手道不仅是身体上的较量，也有心理层面的较量。", ["психологический", "борьба"]],
  ["sport", "Хуахуа и Катя выбрали бадминтон, потому что они раньше уже играли по выходным, а теперь их будет тренировать профессионал.", "说她们以前周末打羽毛球，现在会由专业人士训练。", ["профессионал"]],
  ["sport", "Андрей долго выбирал между баскетболом и плаванием.", "说安德烈在篮球和游泳之间考虑了很久。", ["плавание"]],
  ["sport", "В результате он выбрал баскетбол, потому что после занятий ему приятно побегать с друзьями, снять напряжение и получить дофамин.", "说明他最后选择篮球，因为课后运动能和朋友一起放松减压。", ["напряжение", "занятие"]],
  ["sport", "Также Хуахуа и Катя начали бегать по утрам.", "补充说明她们开始晨跑。", ["core:lexeme-sports-бегать"]],
  ["sport", "Им надо пробежать 40 километров, а они уже пробежали 3 километра.", "说明她们要跑四十公里，目前已经跑了三公里。", ["пробежать"]],
  ["sport", "Когда я выбирал спортивную секцию в МГУ-ППИ, я сначала думал о баскетболе и плавании.", "讲自己选择体育项目时先考虑了篮球和游泳。", ["секция"]],
  ["sport", "Мне нравится баскетбол, потому что это командный и активный вид спорта.", "说明喜欢篮球，因为它是有活力的团队运动。", ["командный", "активный"]],
  ["sport", "После занятий я часто чувствую усталость и напряжение, а спорт помогает мне расслабиться.", "说课后常感到疲惫和压力，而运动能帮助自己放松。", ["усталость", "напряжение", "расслабиться"]],
  ["sport", "Кроме того, во время игры можно общаться с друзьями и развивать командный дух.", "补充说明运动时能和朋友交流并培养团队精神。", ["развивать", "командный"]],
  ["sport", "В результате я выбрал баскетбол.", "简洁说明自己最后选择了篮球。", ["core:lexeme-shopping-выбирать"]],
  ["sport", "Но в будущем я тоже хотел бы иногда ходить в бассейн, потому что плавание очень полезно для здоровья.", "说以后也想偶尔去游泳，因为游泳有益健康。", ["бассейн", "плавание", "полезный"]],

  // B1 日常表达：19
  ["b1", "Кроме того, мне кажется, что русский язык очень красивый, хотя его грамматика довольно сложная.", "补充自己的看法：俄语很美，尽管语法相当复杂。", ["кроме того", "хотя", "довольно", "грамматика"]],
  ["b1", "Если будет дождь, мы можем пойти в кино или посидеть в кафе и поговорить.", "下雨时提议去看电影，或者坐在咖啡馆聊一聊。", ["посидеть", "поговорить"]],
  ["b1", "Я знаю, что главная достопримечательность Москвы — это Кремль и Красная площадь.", "说出莫斯科最主要的景点是克里姆林宫和红场。", ["достопримечательность"], "Я знаю, что главная достопримечательность Москвы — это Кремль и Красная площадь"],
  ["b1", "Я хочу увидеть их своими глазами.", "表达自己想亲眼看看这些景点。", ["своими глазами"], "я хочу увидеть их своими глазами."],
  ["b1", "Нужно доехать до станции «Центральная», а там магазин рядом.", "告诉对方坐到“中心”站，商店就在附近。", ["доехать", "станция"]],
  ["b1", "Температура около 25 градусов, светит солнце и тепло.", "描述阳光明媚，气温大约二十五度。", ["core:lexeme-health-температура"], "Сейчас хорошая погода. Светит солнце, тепло, около 25 градусов."],
  ["b1", "Обычно магазины в моём городе работают с десяти утра до десяти вечера, без выходных.", "介绍当地商店通常从早十点营业到晚十点，周末不休。", ["без выходных"]],
  ["b1", "Технику я обычно покупаю в больших торговых центрах или заказываю в интернете, потому что там больше выбора.", "说自己通常去大型商场或网上购买电子产品，因为选择更多。", ["торговый центр", "заказывать", "выбор"], "Технику я обычно покупаю в больших торговых центрах или заказываю в интернете, потому что там больше выбор."],
  ["b1", "Иногда по выходным я хожу в супермаркет рядом с университетом за фруктами или напитками.", "说自己周末有时去大学附近的超市买水果或饮料。", ["рядом"]],
  ["b1", "Вся семья собирается вместе. Мы готовим вкусную еду и общаемся.", "说节日里全家人会聚在一起做饭聊天。", ["core:lexeme-travel-собираться"], "Вся семья собирается вместе, мы готовим вкусную еду и общаемся."],
  ["b1", "Нет, сейчас у меня нет домашних животных, потому что я живу в общежитии, и это не разрешено.", "解释自己住在宿舍，所以目前不允许养宠物。", ["общежитие", "разрешено"]],
  ["b1", "Извините, наверное, у меня были занятия в университете.", "为没有接到电话道歉，并推测当时在上课。", ["наверное", "занятие"]],
  ["b1", "Мои занятия часто продолжаются до вечера.", "说明自己的课程经常持续到晚上。", ["продолжаться"]],
  ["b1", "Обычно я хожу на учёбу в удобной одежде: в джинсах, футболке и кроссовках. Главное, чтобы было удобно сидеть на лекциях.", "说明上课穿舒适的衣服和运动鞋，最重要的是坐着方便。", ["главное", "одежда", "кроссовки"]],
  ["b1", "Мне нравятся современные российские исполнители.", "说自己喜欢当代俄罗斯歌手。", ["современный", "исполнитель"]],
  ["b1", "Это очень быстрый и удобный вид транспорта, и можно избежать пробок на дорогах.", "说明这种交通很快很方便，还能避开堵车。", ["избежать", "пробка"]],
  ["b1", "В моём городе Нанкине люди по-разному проводят выходные.", "说南京的人用不同方式度过周末。", ["по-разному"]],
  ["b1", "Я собираюсь отдыхать и заниматься саморазвитием.", "说自己假期打算休息并进行自我提升。", ["саморазвитие"]],
  ["b1", "Возможно, я поеду в соседние города, чтобы увидеть новые места.", "说自己也许会去周边城市看看新地方。", ["возможно", "соседний"]],
];

const themeMetadata = {
  hotel: {
    theme: "hotel-experience",
    topicID: "topic-19",
    cueRu: "Как вы расскажете о своём опыте проживания в отеле?",
    speakerRole: "住店客人与朋友",
    expectedReply: "Понятно. А вы остановились бы в этом отеле ещё раз?",
  },
  music: {
    theme: "music-and-emotions",
    topicID: "topic-16",
    cueRu: "Как вы расскажете о песне, которая для вас важна?",
    speakerRole: "朋友之间",
    expectedReply: "Понимаю. А почему эта песня так важна для вас?",
  },
  sport: {
    theme: "sport-and-routine",
    topicID: "topic-28",
    cueRu: "Как вы расскажете о занятиях спортом и своём выборе?",
    speakerRole: "同学之间",
    expectedReply: "Здорово. А каким видом спорта вы занимаетесь сейчас?",
  },
  b1: {
    theme: "everyday-b1-response",
    topicID: "topic-14",
    cueRu: "Как вы естественно ответите собеседнику в этой ситуации?",
    speakerRole: "日常交谈者",
    expectedReply: "Понятно. Расскажите об этом немного подробнее.",
  },
};

const lexemeSpecs = [
  // lemma, gloss, POS, collocation, surface forms, extra grammar
  ["останавливаться", "入住；暂住", "verb", "останавливаться в отеле", ["останавливался"], { aspect: "imperfective", aspectPair: "остановиться", government: "в + 第六格（останавливаться в отеле）" }],
  ["четырёхзвёздочный", "四星级的", "adjective", "четырёхзвёздочный отель", ["четырёхзвёздочный"], {}],
  ["уютный", "舒适温馨的", "adjective", "уютный номер", ["уютный"], {}],
  ["кондиционер", "空调", "noun", "номер с кондиционером", ["кондиционером"], { grammaticalGender: "masculine" }],
  ["уборка", "清洁；打扫", "noun", "ежедневная уборка", ["уборка", "уборку"], { grammaticalGender: "feminine" }],
  ["полотенце", "毛巾", "noun", "чистое полотенце", ["полотенца"], { grammaticalGender: "neuter" }],
  ["халат", "浴袍", "noun", "чистый халат", ["халат"], { grammaticalGender: "masculine" }],
  ["бассейн", "游泳池", "noun", "ходить в бассейн", ["бассейн"], { grammaticalGender: "masculine" }],
  ["фитнес-центр", "健身中心", "noun", "фитнес-центр в отеле", ["фитнес-центр"], { grammaticalGender: "masculine" }],
  ["включённый", "已包含在内的", "adjective", "завтрак включён", ["включён"], {}],
  ["шумно", "吵闹地；很吵", "adverb", "ночью шумно", ["шумно"], {}],
  ["несмотря", "尽管", "preposition", "несмотря на это", ["несмотря"], { government: "на + 第四格（несмотря на это）" }],
  ["довольный", "满意的", "adjective", "остаться довольным", ["доволен", "довольным"], {}],
  ["связанный", "有联系的；相关的", "adjective", "быть связанным с человеком", ["связана", "связанным"], { government: "с + 第五格（связана с человеком）" }],
  ["впервые", "第一次", "adverb", "впервые услышать", ["впервые"], {}],
  ["вспоминать", "回想；想起", "verb", "вспоминать время вместе", ["вспоминаю"], { aspect: "imperfective", aspectPair: "вспомнить", government: "кого/что + 第四格" }],
  ["общение", "交流；交往", "noun", "вспоминать наше общение", ["общение", "общаемся"], { grammaticalGender: "neuter" }],
  ["трогательный", "感人的；打动人的", "adjective", "трогательная песня", ["трогательная"], {}],
  ["напоминать", "使想起；提醒", "verb", "напоминать о дружбе", ["напоминает"], { aspect: "imperfective", aspectPair: "напомнить", government: "кому о ком/чём；напоминать кому что" }],
  ["расставание", "分别；离别", "noun", "вспоминать о расставании", ["расставании"], { grammaticalGender: "neuter" }],
  ["воспоминание", "回忆", "noun", "тёплые воспоминания", ["воспоминания", "воспоминаниях"], { grammaticalGender: "neuter" }],
  ["одиноко", "孤单地；孤独", "adverb", "мне одиноко", ["одиноко"], {}],
  ["спокойнее", "更平静", "adverb", "становится спокойнее", ["спокойнее"], {}],
  ["мелодия", "旋律", "noun", "мелодия песни", ["мелодия"], { grammaticalGender: "feminine" }],
  ["история", "故事；经历", "noun", "у песни есть своя история", ["история"], { grammaticalGender: "feminine" }],
  ["особенный", "特别的", "adjective", "особенная песня", ["особенная", "особенной"], {}],
  ["чувство", "感受；情感", "noun", "сильные чувства", ["чувства"], { grammaticalGender: "neuter" }],
  ["занимать", "占据", "verb", "занимать важное место", ["занимает"], { aspect: "imperfective", aspectPair: "занять", government: "что + 第四格" }],
  ["плавание", "游泳", "noun", "заниматься плаванием", ["плаванием", "плавании"], { grammaticalGender: "neuter" }],
  ["бить", "击打；踢", "verb", "бить по мячу", ["бью"], { aspect: "imperfective", aspectPairNote: "没有单一机械体对；表达一次击打常用 ударить", government: "по + 第三格（бить по мячу）" }],
  ["лыжи", "滑雪板；滑雪", "noun", "ехать на лыжах", ["лыжах"], { grammaticalGender: "plural" }],
  ["борьба", "搏斗；较量", "noun", "психологическая борьба", ["борьба"], { grammaticalGender: "feminine" }],
  ["бросать", "投；扔", "verb", "бросать мяч в корзину", ["бросаю"], { aspect: "imperfective", aspectPair: "бросить", government: "что + 第四格；куда" }],
  ["корзина", "篮筐；篮子", "noun", "бросить мяч в корзину", ["корзину"], { grammaticalGender: "feminine" }],
  ["клюшка", "球杆", "noun", "держать клюшку", ["клюшку"], { grammaticalGender: "feminine" }],
  ["шайба", "冰球", "noun", "бить по шайбе", ["шайбе"], { grammaticalGender: "feminine" }],
  ["шахматный", "国际象棋的", "adjective", "шахматная фигура", ["шахматная", "шахматную"], {}],
  ["фигура", "棋子；形体", "noun", "двигать шахматную фигуру", ["фигуру"], { grammaticalGender: "feminine" }],
  ["занятие", "课程；活动", "noun", "занятие по спорту", ["занятие", "занятий", "занятия"], { grammaticalGender: "neuter" }],
  ["психологический", "心理的", "adjective", "психологическая борьба", ["психологическая"], {}],
  ["профессионал", "专业人士", "noun", "работать с профессионалом", ["профессионал", "профессионалом"], { grammaticalGender: "masculine" }],
  ["напряжение", "压力；紧张", "noun", "снять напряжение", ["напряжение"], { grammaticalGender: "neuter" }],
  ["пробежать", "跑完（一段距离）", "verb", "пробежать три километра", ["пробежать", "пробежали"], { aspect: "perfective", aspectPair: "пробегать", government: "сколько + 距离" }],
  ["секция", "兴趣小组；体育项目", "noun", "спортивная секция", ["секцию"], { grammaticalGender: "feminine" }],
  ["командный", "团队的", "adjective", "командный вид спорта", ["командный"], {}],
  ["активный", "活跃的；高强度的", "adjective", "активный вид спорта", ["активный", "активно"], {}],
  ["усталость", "疲劳", "noun", "чувствовать усталость", ["усталость"], { grammaticalGender: "feminine" }],
  ["расслабиться", "放松下来", "verb", "помогать расслабиться", ["расслабиться"], { aspect: "perfective", aspectPair: "расслабляться", government: "不及物；常用 помочь кому расслабиться" }],
  ["развивать", "培养；发展", "verb", "развивать командный дух", ["развивать"], { aspect: "imperfective", aspectPair: "развить", government: "что + 第四格" }],
  ["полезный", "有益的", "adjective", "полезно для здоровья", ["полезно"], { government: "для + 第二格" }],
  ["кроме того", "此外", "connector", "кроме того, мне кажется", ["Кроме того"], {}],
  ["хотя", "虽然；尽管", "conjunction", "хотя это сложно", ["хотя"], {}],
  ["довольно", "相当；颇为", "adverb", "довольно сложный", ["довольно"], {}],
  ["грамматика", "语法", "noun", "грамматика русского языка", ["грамматика"], { grammaticalGender: "feminine" }],
  ["посидеть", "坐一会儿", "verb", "посидеть в кафе", ["посидеть"], { aspect: "perfective", aspectPair: "сидеть", government: "где + 第六格" }],
  ["поговорить", "聊一聊", "verb", "поговорить с друзьями", ["поговорить"], { aspect: "perfective", aspectPair: "говорить", government: "с + 第五格；о + 第六格" }],
  ["своими глазами", "亲眼", "fixedPhrase", "увидеть своими глазами", ["своими глазами"], {}],
  ["доехать", "乘车到达", "verb", "доехать до станции", ["доехать"], { aspect: "perfective", aspectPair: "доезжать", government: "до + 第二格" }],
  ["станция", "车站", "noun", "доехать до станции", ["станции"], { grammaticalGender: "feminine" }],
  ["без выходных", "全年无休；周末不休", "fixedPhrase", "работать без выходных", ["без выходных"], {}],
  ["выбор", "选择；可选范围", "noun", "большой выбор", ["выбор", "выбора"], { grammaticalGender: "masculine" }],
  ["заказывать", "订购", "verb", "заказывать в интернете", ["заказываю"], { aspect: "imperfective", aspectPair: "заказать", government: "что + 第四格" }],
  ["торговый центр", "购物中心", "nounPhrase", "покупать в торговом центре", ["торговом центре", "торговых центрах"], { grammaticalGender: "masculine" }],
  ["рядом", "在附近", "adverb", "рядом с университетом", ["рядом"], { government: "с + 第五格" }],
  ["общежитие", "宿舍", "noun", "жить в общежитии", ["общежитии"], { grammaticalGender: "neuter" }],
  ["разрешено", "被允许；可以", "predicative", "это не разрешено", ["разрешено"], {}],
  ["наверное", "大概；可能", "modalWord", "наверное, были занятия", ["наверное"], {}],
  ["продолжаться", "持续", "verb", "продолжаться до вечера", ["продолжаются"], { aspect: "imperfective", aspectPairNote: "通常作为不及物未完成体使用", government: "до + 第二格" }],
  ["главное", "最重要的是", "predicative", "главное, чтобы было удобно", ["Главное"], {}],
  ["одежда", "衣服；穿着", "noun", "удобная одежда", ["одежде"], { grammaticalGender: "feminine" }],
  ["кроссовки", "运动鞋", "noun", "ходить в кроссовках", ["кроссовках"], { grammaticalGender: "plural" }],
  ["современный", "当代的；现代的", "adjective", "современный исполнитель", ["современные"], {}],
  ["исполнитель", "歌手；表演者", "noun", "российский исполнитель", ["исполнители"], { grammaticalGender: "masculine" }],
  ["избежать", "避免", "verb", "избежать пробок", ["избежать"], { aspect: "perfective", aspectPair: "избегать", government: "第二格（избежать пробок）" }],
  ["пробка", "堵车；交通拥堵", "noun", "избежать пробок", ["пробок"], { grammaticalGender: "feminine" }],
  ["по-разному", "以不同方式", "adverb", "по-разному проводить выходные", ["по-разному"], {}],
  ["саморазвитие", "自我提升", "noun", "заниматься саморазвитием", ["саморазвитием"], { grammaticalGender: "neuter", government: "заниматься + 第五格" }],
  ["возможно", "也许；可能", "modalWord", "возможно, я поеду", ["Возможно"], {}],
  ["соседний", "邻近的", "adjective", "соседний город", ["соседние"], {}],
  ["достопримечательность", "名胜；景点", "noun", "увидеть достопримечательности", ["достопримечательность", "достопримечательности"], { grammaticalGender: "feminine" }],
];

const lexemeStress = new Map(Object.entries({
  "останавливаться": "остана́вливаться",
  "четырёхзвёздочный": "четырёхзвёздочный",
  "уютный": "ую́тный",
  "кондиционер": "кондиционе́р",
  "уборка": "убо́рка",
  "полотенце": "полоте́нце",
  "халат": "хала́т",
  "бассейн": "бассе́йн",
  "фитнес-центр": "фи́тнес-це́нтр",
  "включённый": "включённый",
  "шумно": "шу́мно",
  "несмотря": "несмотря́",
  "довольный": "дово́льный",
  "снова": "сно́ва",
  "связанный": "свя́занный",
  "впервые": "впервы́е",
  "вспоминать": "вспомина́ть",
  "общение": "обще́ние",
  "трогательный": "тро́гательный",
  "напоминать": "напомина́ть",
  "расставание": "расстава́ние",
  "воспоминание": "воспомина́ние",
  "одиноко": "одино́ко",
  "спокойнее": "споко́йнее",
  "мелодия": "мело́дия",
  "история": "исто́рия",
  "слова": "слова́",
  "особенный": "осо́бенный",
  "чувство": "чу́вство",
  "занимать": "занима́ть",
  "плавание": "пла́вание",
  "бить": "би́ть",
  "лыжи": "лы́жи",
  "борьба": "борьба́",
  "бросать": "броса́ть",
  "корзина": "корзи́на",
  "клюшка": "клю́шка",
  "шайба": "ша́йба",
  "шахматный": "ша́хматный",
  "фигура": "фигу́ра",
  "занятие": "заня́тие",
  "психологический": "психологи́ческий",
  "профессионал": "профессиона́л",
  "напряжение": "напряже́ние",
  "пробежать": "пробежа́ть",
  "секция": "се́кция",
  "командный": "кома́ндный",
  "активный": "акти́вный",
  "усталость": "уста́лость",
  "расслабиться": "рассла́биться",
  "развивать": "развива́ть",
  "полезный": "поле́зный",
  "кроме того": "кро́ме того́",
  "хотя": "хотя́",
  "довольно": "дово́льно",
  "грамматика": "грамма́тика",
  "посидеть": "посиде́ть",
  "поговорить": "поговори́ть",
  "своими глазами": "свои́ми глаза́ми",
  "доехать": "дое́хать",
  "станция": "ста́нция",
  "около": "о́коло",
  "без выходных": "без выходны́х",
  "выбор": "вы́бор",
  "заказывать": "зака́зывать",
  "торговый центр": "торго́вый це́нтр",
  "рядом": "ря́дом",
  "общежитие": "общежи́тие",
  "разрешено": "разрешено́",
  "наверное": "наве́рное",
  "продолжаться": "продолжа́ться",
  "главное": "гла́вное",
  "одежда": "оде́жда",
  "кроссовки": "кроссо́вки",
  "современный": "совреме́нный",
  "исполнитель": "исполни́тель",
  "избежать": "избежа́ть",
  "пробка": "про́бка",
  "по-разному": "по-ра́зному",
  "саморазвитие": "саморазви́тие",
  "возможно": "возмо́жно",
  "соседний": "сосе́дний",
  "достопримечательность": "достопримеча́тельность",
}));

const acute = "\u0301";
function removeStress(value) {
  return value.replaceAll(acute, "");
}

function transferStress(stressedBase, surface) {
  const plainBase = removeStress(stressedBase);
  const accentIndex = stressedBase.indexOf(acute);
  if (accentIndex < 1) return surface;
  const stressedLetterIndex = accentIndex - 1;
  const prefixThroughStress = plainBase.slice(0, stressedLetterIndex + 1);
  if (
    surface.toLocaleLowerCase("ru-RU")
      .startsWith(prefixThroughStress.toLocaleLowerCase("ru-RU"))
  ) {
    return `${surface.slice(0, stressedLetterIndex + 1)}${acute}` +
      surface.slice(stressedLetterIndex + 1);
  }
  return surface;
}

function buildStressDictionary() {
  const dictionary = new Map();
  const core = JSON.parse(
    fs.readFileSync(path.join(resourceRoot, "long-term-sentences.json"), "utf8"),
  );
  const wordPattern = /[А-ЯЁа-яё\u0301-]+/gu;
  for (const sentence of core.sentences) {
    const plainWords = sentence.practiceRu.match(wordPattern) ?? [];
    const stressedWords = sentence.stressedForm.match(wordPattern) ?? [];
    if (plainWords.length !== stressedWords.length) continue;
    for (let index = 0; index < plainWords.length; index += 1) {
      const key = plainWords[index].toLocaleLowerCase("ru-RU");
      const value = stressedWords[index].toLocaleLowerCase("ru-RU");
      if (!dictionary.has(key)) dictionary.set(key, value);
    }
  }
  for (const [lemma, stressed] of lexemeStress) {
    const lemmaWords = lemma.split(/\s+/u);
    const stressedWords = stressed.split(/\s+/u);
    for (let index = 0; index < lemmaWords.length; index += 1) {
      dictionary.set(
        lemmaWords[index].toLocaleLowerCase("ru-RU"),
        stressedWords[index].toLocaleLowerCase("ru-RU"),
      );
    }
  }
  for (const [plain, stressed] of Object.entries({
    "также": "та́кже",
    "катя": "ка́тя",
    "начали": "на́чали",
    "бегать": "бе́гать",
    "утрам": "утра́м",
    "результате": "результа́те",
    "выбрал": "вы́брал",
    "баскетбол": "баскетбо́л",
  })) {
    dictionary.set(plain, stressed);
  }
  for (const [lemma, , , , surfaceForms] of lexemeSpecs) {
    const stressed = lexemeStress.get(lemma);
    if (!stressed || stressed.includes(" ")) continue;
    for (const surface of surfaceForms) {
      if (surface.includes(" ")) continue;
      dictionary.set(
        surface.toLocaleLowerCase("ru-RU"),
        transferStress(stressed, surface).toLocaleLowerCase("ru-RU"),
      );
    }
  }
  return dictionary;
}

const stressDictionary = buildStressDictionary();
function applyKnownStress(text) {
  return text.replace(/[А-ЯЁа-яё-]+/gu, (word) => {
    const stressed = stressDictionary.get(word.toLocaleLowerCase("ru-RU"));
    if (!stressed) return word;
    if (word[0] === word[0].toLocaleUpperCase("ru-RU")) {
      return stressed[0].toLocaleUpperCase("ru-RU") + stressed.slice(1);
    }
    return stressed;
  });
}

if (rawSentences.length !== 60) {
  throw new Error(`expected 60 curated sentences, got ${rawSentences.length}`);
}
if (lexemeSpecs.length !== 80) {
  throw new Error(`expected 80 curated lexemes, got ${lexemeSpecs.length}`);
}

const lexemeSpecByLemma = new Map(
  lexemeSpecs.map((spec) => [spec[0], spec]),
);
const sentences = rawSentences.map(
  ([sourceKey, practiceRu, promptZh, lemmas, sourceNeedle], index) => {
    for (const lemma of lemmas) {
      if (!lemma.startsWith("core:") && !lexemeSpecByLemma.has(lemma)) {
        throw new Error(`missing lexeme spec: ${lemma}`);
      }
    }
    const source = sourceLine(sourceKey, sourceNeedle ?? practiceRu);
    const metadata = themeMetadata[sourceKey];
    return {
      id: `supplement-sentence-${String(index + 1).padStart(3, "0")}`,
      promptZh,
      cueRu: metadata.cueRu,
      practiceRu,
      stressedForm: applyKnownStress(practiceRu),
      speechText: practiceRu,
      theme: metadata.theme,
      lexemeIDs: lemmas.map((lemma) =>
        lemma.startsWith("core:")
          ? lemma.slice("core:".length)
          : `supplement-lexeme-${lemma}`
      ),
      sourcePath: source.sourcePath,
      sourceText: source.sourceText,
      reviewStatus: "reviewed",
      provenanceType: practiceRu === (sourceNeedle ?? practiceRu)
        ? "courseMaterial"
        : "derived",
      qualityFlags: [],
      dialogueAct: sourceKey === "b1" ? "response" : "personalNarration",
      register: "neutral",
      speakerRole: metadata.speakerRole,
      addressForm: "notApplicable",
      expectedReply: metadata.expectedReply,
      alternativeReplyIDs: [],
      topicID: metadata.topicID,
      sourceHash: source.hash,
      corpusLayer: "dailySupplement",
    };
  },
);

const sentenceLinksByLemma = new Map();
for (const sentence of sentences) {
  for (const lexemeID of sentence.lexemeIDs) {
    if (!lexemeID.startsWith("supplement-lexeme-")) continue;
    const lemma = lexemeID.replace("supplement-lexeme-", "");
    const links = sentenceLinksByLemma.get(lemma) ?? [];
    links.push(sentence.id);
    sentenceLinksByLemma.set(lemma, links);
  }
}

const lexemes = lexemeSpecs.map(
  ([lemma, glossZh, partOfSpeech, collocation, surfaceForms, grammar]) => {
    const sentenceIDs = sentenceLinksByLemma.get(lemma) ?? [];
    if (sentenceIDs.length === 0) {
      throw new Error(`unlinked lexeme: ${lemma}`);
    }
    const exampleSentence = sentences.find(
      (sentence) => sentence.id === sentenceIDs[0],
    );
    return {
      id: `supplement-lexeme-${lemma}`,
      lemma,
      stressedForm: lexemeStress.get(lemma),
      speechText: lemma,
      partOfSpeech,
      glossZh,
      collocations: [collocation],
      example: exampleSentence.practiceRu,
      sentenceIDs,
      reviewStatus: "reviewed",
      ...grammar,
      surfaceForms,
      sourcePaths: [exampleSentence.sourcePath],
      sourceTexts: [exampleSentence.sourceText],
      provenanceTypes: [exampleSentence.provenanceType],
      qualityFlags: [],
      usageNote: grammar.government
        ? `优先按搭配整体提取：${collocation}`
        : `不要孤立背词，连同“${collocation}”一起说。`,
      contrastNote: null,
      commonMistakes: [],
      contrastGroupID: null,
      corpusLayer: "dailySupplement",
    };
  },
);

function buildChallenges() {
  const source = readSource("prompts");
  const challenges = [];
  const tablePattern = /^\|\s*\d+\s*\|\s*(.+?\?)\s*\|\s*(.+?)\s*\|\s*$/u;
  for (const line of source.text.split(/\r?\n/u)) {
    const match = line.match(tablePattern);
    if (!match) continue;
    const promptRu = match[1].trim();
    const promptZh = match[2].trim();
    if (challenges.some((item) => item.promptRu === promptRu)) continue;
    challenges.push({
      id: `speaking-challenge-${String(challenges.length + 1).padStart(3, "0")}`,
      promptRu,
      promptZh,
      structureHintsZh: [
        "先直接回答立场或事实",
        "补充一个原因",
        "最后给一个个人例子",
      ],
      replacementSlots: ["地点", "时间", "人物", "个人经历"],
      lexemeIDs: [],
      sourcePath: source.sourcePath,
      sourceText: line,
      sourceHash: source.hash,
      reviewStatus: "reviewed",
      provenanceType: "courseMaterial",
      qualityFlags: [],
    });
    if (challenges.length === 24) break;
  }
  if (challenges.length !== 24) {
    throw new Error(`expected 24 speaking challenges, got ${challenges.length}`);
  }
  return challenges;
}

const challenges = buildChallenges();
const sourceHashes = Object.fromEntries(
  [...sourceCache.entries()]
    .map(([sourcePath, source]) => [sourcePath, source.hash])
    .sort(([left], [right]) => left.localeCompare(right, "zh-Hans-CN")),
);
const candidateAudit = JSON.parse(
  fs.readFileSync(
    path.join(repositoryRoot, "Verification/supplemental-corpus-candidates.json"),
    "utf8",
  ),
);
const manifest = {
  schemaVersion: 1,
  contentGateClosed: true,
  allowedSourceRoots: [
    "01-按学期/大一下——莫斯科/基础俄语",
    "01-按学期/大二上/基础俄语",
    "01-按学期/！大二下/俄语",
  ],
  sourceHashes,
  candidateCount: candidateAudit.candidates.length,
  reviewedSentenceCount: sentences.length,
  reviewedLexemeCount: lexemes.length,
  excludedCount: candidateAudit.excluded.length,
};

function writeJSON(name, value) {
  fs.writeFileSync(
    path.join(resourceRoot, name),
    `${JSON.stringify(value, null, 2)}\n`,
  );
}

writeJSON("supplemental-manifest.json", manifest);
writeJSON("supplemental-lexemes.json", lexemes);
writeJSON("supplemental-sentences.json", sentences);
writeJSON("speaking-challenges.json", challenges);
process.stdout.write(
  `supplemental_build=PASS lexemes=${lexemes.length} ` +
  `sentences=${sentences.length} challenges=${challenges.length}\n`,
);
