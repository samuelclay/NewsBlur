---
description: Post a feature to the Features Board on production and write tweets
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---

## Context

- Recent blog posts: !`ls -t blog/_posts/*.md | head -10`
- Current features on prod: !`./utils/ssh_hz.sh -n happ-web-01 "docker exec -t newsblur_web python manage.py shell -c \"from apps.reader.models import Feature; [print(f'{f.date.strftime(\\\"%b %d, %Y\\\")}: {f.description}') for f in Feature.objects.all()[:6]]\""`

## Writing style

All text you write (feature descriptions and tweets) must sound like a human wrote it. Avoid AI slop:
- **No em dashes or double hyphens** -- don't use dashes as punctuation at all. Restructure the sentence instead.
- **No overly polished or corporate language** -- keep it direct and natural
- **No filler phrases** like "excited to announce", "we're thrilled", "game-changer"
- Write the way a developer would describe their own product

## Your task

Create a new Feature entry on the NewsBlur production database for the topic: **{{ arguments }}**, then write tweets.

### Step 1: Find the matching blog post

Search `blog/_posts/` for a blog post matching the topic "{{ arguments }}". Read the full blog post to understand:
- What the feature does
- Key capabilities and highlights
- Which subscription tiers have access
- The blog post date and URL slug

Derive the blog URL from the filename: `https://blog.newsblur.com/YYYY/MM/DD/slug-from-filename/`
(e.g., `blog/_posts/2026-03-25-daily-briefing.md` → `https://blog.newsblur.com/2026/03/25/daily-briefing/`)

### Step 2: Study existing feature style

Look at the existing features from the Context section above. Note:
- **Length**: 1-3 sentences, concise and punchy
- **Tone**: Product-focused, highlights what's new and useful
- **Structure**: Feature description + `<a href="...">Read the blog post</a>.`
- **Content**: Leads with what it does, packs in key details, sometimes mentions tier availability
- The description field contains raw HTML (the blog link is an anchor tag)

### Step 3: Write 4-5 feature options

Write 4-5 different feature descriptions, each following the existing style. Vary them by:
- Which aspects of the feature to highlight (breadth vs. depth)
- Length (shorter vs. slightly longer)
- What details to include (sections, delivery methods, customization, tier info)

Present all options as plain text in the conversation (not inside AskUserQuestion previews, which truncate HTML). Number each option and include the full text with the HTML blog link.

### Step 4: Ask the user to choose a feature

Use AskUserQuestion (single-select, no previews) to ask which option they prefer. Use descriptive labels that identify the angle of each option (e.g., "Balanced, both features" or "Problem-first framing").

### Step 5: Post to production

Once the user picks an option, create the Feature on production:

```bash
./utils/ssh_hz.sh -n happ-web-01 "docker exec -t newsblur_web python manage.py shell -c \"
from apps.reader.models import Feature
import datetime
f = Feature(
    description='<THE CHOSEN DESCRIPTION WITH HTML LINK>',
    date=datetime.datetime.utcnow() + datetime.timedelta(minutes=1)
)
f.save()
print(f'Created Feature #{f.id}: {f}')
\""
```

Make sure to properly escape quotes in the description for the nested shell command.

### Step 6: Confirm feature

Report the Feature ID and that it's live on production.

### Step 7: Write 4-5 tweet options

Write 4-5 tweets about the feature for the user to post. Each tweet should:
- Be under 280 characters (excluding the URL, which Twitter shortens)
- End with the blog post URL on its own line
- Vary in angle: some covering both features, some focusing on one, some with concrete examples, some short and punchy
- Follow the writing style rules above (no em dashes, no AI slop)

Present all tweet options as plain text in the conversation, clearly numbered with the full text.

### Step 8: Ask the user to pick tweets

Use AskUserQuestion (multi-select, no previews) to ask which 2-3 tweets they want to use. Use descriptive labels that summarize the angle of each tweet.

### Step 9: Present final tweets

Display the selected tweets clearly formatted and ready to copy.
