# English Natural Corpus Review

## Decision

The first English bundle was too template-driven: the same formal sentence
pattern was copied across many topics. It has been replaced with a reviewed,
scene-based set of 24 everyday themes, 240 sentences, and 480 clickable
expression/chunk records. The four highest-priority themes are for the
student's most important real-world need: talking with international teachers
at university and participating in class.

The new content is authored from common conversational patterns. *Friends*
is used only as a style reference for casual turn-taking, reactions, fillers,
and relationship talk. Episode transcripts and recognisable show-specific
catchphrases are not copied into the product.

## Evidence used for the redesign

- British Council, “Essential conversational English phrases for making
  friends abroad”: conversation starters, follow-up questions, invitations,
  staying in touch, and the recommendation to keep phrases simple and casual.
  <https://englishonline.britishcouncil.org/blog/articles/essential-conversational-english-phrases-for-making-friends-abroad/>
- British Council, “Your guide to small talk topics, phrases and openers in
  English”: small-talk openers, active-listening responses, follow-up
  questions, and natural ways to end a conversation.
  <https://englishonline.britishcouncil.org/blog/articles/your-guide-to-small-talk-topics-phrases-and-openers-in-english/>
- BBC Learning English, “Real Easy English — Socialising”: spoken-conversation
  rhythm, hesitation, follow-up questions, and everyday social vocabulary.
  <https://downloads.bbc.co.uk/learningenglish/realeasyenglish/RealEasyEnglish_socialising_transcript_.pdf>
- A Friends-oriented learning article was consulted only to identify useful
  categories such as casual reactions, agreement, fillers, and phrasal verbs;
  its episode lines are not included as source text.
  <https://blog.secret2english.com/friends-tv-english/>

## Content rules

- Every card has a Chinese intention, an English cue, a complete spoken line,
  one reasonable next reply, and one clickable focus chunk.
- `reviewStatus` is `reviewed`; `provenanceType` is `derived`; the source path
  is a local curated scene rather than an episode transcript.
- The bundle avoids elementary greeting-only cards and avoids repeated
  “formal template” sentences across themes.
- `speechText` is clean English only, so the existing TTS and clickable-word
  flows can use it directly.

## Scene coverage

The first four topics in the app's English queue are deliberately reserved for
campus/classroom communication:

- 校园遇见老师 — greeting an international teacher and checking simple
  campus details.
- 请教老师与约时间 — asking for help, clarification, office hours, or a
  short meeting.
- 课堂提问与澄清 — asking a question, checking a point, and repairing a
  misunderstanding during class.
- 课堂回答与讨论 — answering with a partial idea, agreeing or disagreeing
  politely, adding an example, and explaining an idea when a word is missing.

The remaining 20 everyday topics are retained unchanged: 朋友与近况、约时间与临时改期、没听清与重新说明、惊讶与接话、工作与学习、请求与帮忙、邀请与社交、购物与退换、吃饭与咖啡、出行、问路、电话与消息、身体状态、问题与投诉、道歉与失误、讲故事、朋友与关系、影视与音乐、阅读与观点、日常事务与家里。

The four campus topics use student/teacher speaker metadata. Greetings and
requests use a polite register; classroom questions and answers use a neutral
spoken register. The daily scheduler and topic selector consume this same
priority order, so the school material appears first without deleting or
rewriting the other scenes.

The reproducible generator is `Scripts/build-natural-english-corpus.py`.
