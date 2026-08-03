# English Natural Corpus Review

## Decision

The first English bundle was too template-driven: the same formal sentence
pattern was copied across many topics. It has been replaced with a reviewed,
scene-based set of 20 everyday themes, 200 sentences, and 400 clickable
expression/chunk records.

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

朋友与近况、约时间与临时改期、没听清与重新说明、惊讶与接话、工作与学习、请求与帮忙、邀请与社交、购物与退换、吃饭与咖啡、出行、问路、电话与消息、身体状态、问题与投诉、道歉与失误、讲故事、朋友与关系、影视与音乐、阅读与观点、日常事务与家里。

The reproducible generator is `Scripts/build-natural-english-corpus.py`.
