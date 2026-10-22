---
layout: post
title: "Listen: NewsBlur reads your stories aloud on the web, iOS, Mac, and Android"
tags: ["web", "ios", "android"]
image: /assets/listen-hero.jpg
---

Every story in NewsBlur now has a Listen button. Press it and NewsBlur reads the story to you, starting with the headline and going paragraph by paragraph, highlighting each one as it goes. When the story ends, the next one starts. It works on the web, iPhone, iPad, Mac, and Android starting today, and it can read stories in all 21 languages NewsBlur speaks.

Here's Jon, the default English voice, reading that paragraph:

<audio controls preload="none" src="/assets/listen-sample-jon.mp3" style="width: 100%;margin: 8px auto 16px;display: block;"></audio>

And if you're reading this in NewsBlur, you can press Listen right now and have the rest of this post read to you.

<img src="/assets/listen-hero.jpg" alt="Listen playing on a MacBook, an iPad, an iPhone, and an Android phone, each showing the Now Playing controls" style="width: 100%;margin: 24px auto;display: block;">

This one launched everywhere on the same day. The web, the iOS and Mac apps, and the Android app all got Listen together, with its interface translated into the same 21 languages from <a href="{% post_url 2026-10-14-newsblur-in-your-language %}">last week's language launch</a>. If you already play podcasts in NewsBlur's <a href="{% post_url 2026-03-02-mini-media-player %}">media player</a>, Listen turns any story into one more thing to queue up.

### Press Listen

On the web, Listen sits with the other story buttons, and the **y** key does the same thing. On iPhone, iPad, and Android it's in the row of buttons at the end of each story. On the Mac it's in the **Story** menu, also on **Y**, with a play and pause button in the toolbar.

<img src="/assets/listen-start.webp" alt="The Listen button on iPhone and Android story buttons, the web's Listen side option with its tooltip, and Listen in the Mac app's Story menu" style="width: 100%;margin: 24px auto;display: block;">

On the web, stories play in the sidebar, in the same mini player that handles podcasts and YouTube. On iPhone, iPad, and Android, a mini player sits above the bottom bar. Tap it to open Now Playing, with a scrubber, 15 seconds back, 30 seconds forward, speed, and a button to skip to the next story.

### Follow along

While a story plays, the paragraph being read is highlighted and the story scrolls gently to keep it in view. If you scroll away to look at something, it waits a few seconds before following again. Click or tap any paragraph to jump straight to it, which is also the quickest way past a long intro.

<img src="/assets/listen-follow-along.webp" alt="Paragraphs highlighted as they're read on an iPad, an iPhone, and an Android phone" style="width: 100%;margin: 24px auto;display: block;">

Listen reads the headline, then the article's paragraphs, headings, lists, and quotes. It skips what doesn't work out loud: images, captions, code blocks, tables, and embeds. And if a feed only publishes a summary, Listen fetches the full article from the site and reads that, so you hear the whole story and not just the first two sentences.

### Up Next

Next to Listen is a small **+** that adds the story to **Up Next**. Queue a few stories while you read, press play, and walk away. Drag to reorder, and swipe or tap × to remove one.

<img src="/assets/listen-up-next.webp" alt="Adding stories to Up Next on iPhone and the web, and the Up Next list in Now Playing on Android" style="width: 100%;margin: 24px auto;display: block;">

When Up Next runs out, Listen keeps going with the next unread stories in whatever feed or folder you're in. Each story is marked read when it finishes, and the reader follows along to the next one. If you'd rather it stop after each story, turn off **Auto-continue**.

Up Next is the same queue your podcasts use, and it's saved to your account. Queue a story on your phone and it's waiting in Up Next on the web.

### Pick a voice

The voices come from <a href="https://elevenlabs.io">ElevenLabs</a>. Each language has ten recommended voices, and you can search the rest of the ElevenLabs library by gender, age, accent, and style. Every voice has a play button so you can hear it before you choose.

<img src="/assets/listen-voices.webp" alt="The voice picker on iPhone and the web, and the speed control on Android" style="width: 100%;margin: 24px auto;display: block;">

**Delivery** sets how much emotion goes into the reading: Steady, Natural, or Expressive. **Fine-tune voice** opens up the stability, similarity, and style settings behind those three if you want to tinker.

Speed goes from 0.75× to 3×, with presets and a slider for anything in between. The pitch stays put at any speed, so 1.5× sounds like a fast talker and not a chipmunk.

### Every language gets its own voice

Listen works out what language each story is written in and reads it with your voice for that language. Jon reads my English stories, and when a French story comes through, Victoria picks it up. Choose a different voice for any language from the menu at the top of the voice list. These are the defaults:

<img src="/assets/listen-languages.webp" alt="NewsBlur's 21 languages with the default Listen voice for each: English, Jon; Español, Lydia; Français, Victoria; Deutsch, Lea; Português (Brasil), Keren; Italiano, Violetta; Nederlands, Ruth; Polski, Magdalena; Türkçe, Derya; Русский, Marina; Українська, Yaroslava; العربية, Sara; עברית, Noa; हिन्दी, Monika Sogam; Bahasa Indonesia, Arunika; Tiếng Việt, Ngân Nguyễn; ไทย, Mali; 日本語, Yui; 한국어, Anna Kim; 简体中文, Stacy; 繁體中文, Anna Su" style="width: 100%;margin: 24px auto;display: block;">

### Keeps playing with the screen off

On iPhone, iPad, and Android, Listen keeps going when you lock your phone or switch apps. It shows up on the lock screen, in Control Center, and in Android's media controls, with the same 15 and 30 second skips, and headphone buttons play and pause.

<img src="/assets/listen-lock-screen.webp" alt="Listen on the iPhone lock screen and in Android's media controls" style="width: 100%;margin: 24px auto;display: block;">

### On the Mac

The Mac app has **Listen** and **Add to Up Next** in the Story menu, and a play and pause button in the toolbar so you can stop a story without hunting for the player. Now Playing opens as a sheet over the reader, with the same Up Next list as everywhere else.

<img src="/assets/listen-mac.webp" alt="Now Playing in the NewsBlur Mac app, with Listen and Add to Up Next in the Story menu" style="width: 100%;margin: 24px auto;display: block;">

### Try it for 30 seconds

Listen is part of <a href="https://newsblur.com/?next=premium">Premium Archive and Premium Pro</a>. On a free or Premium account you can still try it: Listen plays a 30 second preview of a few stories a day, with a countdown in the player and an upgrade button when it's done. Voice previews in the picker work too, so you can find a voice you like first.

<img src="/assets/listen-preview.webp" alt="The 30 second preview banner on iPhone, Android, and the web" style="width: 100%;margin: 24px auto;display: block;">

### How it works

Reading every story in everyone's feeds ahead of time would be a huge waste, so Listen makes the audio on demand. When you press play, NewsBlur splits the story into short segments, usually a paragraph each, and asks ElevenLabs for the first one. The audio streams to you while it's still being generated, so it starts quickly, and the next segment is fetched while the current one plays. Each segment is sent along with the text around it so the voice keeps its rhythm across paragraph breaks.

<img src="/assets/listen-how-it-works.webp" alt="A story split into paragraphs: the ones already played are saved, the current one is highlighted, the next one is streaming from ElevenLabs, and the rest aren't made until you get there" style="width: 100%;margin: 24px auto;display: block;">

Once a segment has been read in a voice, it's saved. The next person who listens to that story with the same voice gets it right away, and if you stop halfway through a story, the rest of it never gets made at all.

### Availability

Listen is available today on the web, in NewsBlur for iPhone, iPad, and Mac on the [App Store](https://apps.apple.com/app/newsblur/id463981119), and in NewsBlur for Android on [Google Play](https://play.google.com/store/apps/details?id=com.newsblur). If you don't want the button, you can hide it, along with any other story button, in Preferences on the web and in the apps, and that choice syncs between them.

I'd love to hear which voice you picked and how Listen handles your feeds. Let me know on the <a href="https://forum.newsblur.com">NewsBlur forum</a>.
