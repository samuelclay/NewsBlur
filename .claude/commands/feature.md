---
description: Post a feature to the Features Board on production, matching style of existing features
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
---

## Context

- Recent blog posts: !`ls -t blog/_posts/*.md | head -10`
- Current features on prod: !`./utils/ssh_hz.sh -n happ-web-01 "docker exec -t newsblur_web python manage.py shell -c \"from apps.reader.models import Feature; [print(f'{f.date.strftime(\\\"%b %d, %Y\\\")}: {f.description}') for f in Feature.objects.all()[:6]]\""`

## Your task

Create a new Feature entry on the NewsBlur production database for the topic: **{{ arguments }}**

### Step 1: Find the matching blog post

Search `blog/_posts/` for a blog post matching the topic "{{ arguments }}". Read the full blog post to understand:
- What the feature does
- Key capabilities and highlights
- Which subscription tiers have access
- The blog post date and URL slug

The blog URL format is: `https://blog.newsblur.com/YYYY/MM/DD/slug-from-filename/`
(e.g., `blog/_posts/2026-03-25-daily-briefing.md` → `https://blog.newsblur.com/2026/03/25/daily-briefing/`)

### Step 2: Study existing feature style

Look at the existing features from the Context section above. Note:
- **Length**: 1-3 sentences, concise and punchy
- **Tone**: Product-focused, highlights what's new and useful
- **Structure**: Feature description + `<a href="...">Read the blog post</a>.`
- **Content**: Leads with what it does, packs in key details, sometimes mentions tier availability
- The description field contains raw HTML (the blog link is an anchor tag)

### Step 3: Write 4-5 options

Write 4-5 different feature descriptions, each following the existing style. Vary them by:
- Which aspects of the feature to highlight (breadth vs. depth)
- Length (shorter vs. slightly longer)
- What details to include (sections, delivery methods, customization, tier info)

Present all options clearly numbered with the full text (including the HTML blog link).

### Step 4: Ask the user to choose

Use AskUserQuestion to ask which option they prefer (or if they want edits). Wait for their response.

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

### Step 6: Confirm

Report the Feature ID and that it's live on production.
