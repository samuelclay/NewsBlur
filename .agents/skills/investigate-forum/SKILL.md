---
name: investigate-forum
description: Triage the NewsBlur support forum (forum.newsblur.com). Use when the user runs /investigate-forum, pastes a forum.newsblur.com topic URL, or says "check the forum", "triage the forum", "what's waiting on the forum", "look at this forum post". Finds topics whose last post is not from Sam, investigates each one newest first, and either opens a fix PR in a worktree with a before/after and a drafted reply (tier 1), drafts a reply only, or interviews Sam with AskUserQuestion when a decision or a production change is needed (tier 2). Read-only against production. Never posts to the forum and never merges.
---

# Investigate Forum

Sam runs this about once a day and comes back every few hours to approve things.
The job: for each forum topic still waiting on Sam, do the investigation he would do,
get a fix as far as a reviewed PR when it is safe to, and leave a reply he can paste.

## Ground rules

These hold for every topic, every run. Do not reinterpret them mid-run.

1. **At most three topics per run, one at a time, newest activity first.** The queue is cut at three (`--limit`, default 3); the rest wait for the next run so open PRs get merged before more pile up. Finish a topic (state recorded) before opening the next. No parallel subagents across topics. A subagent may help inside one topic (for example, a second opinion on a fix) but the loop stays sequential.
2. **Production is read-only.** Pre-authorized: Django ORM reads, mongoengine reads, redis read commands (`GET`, `HGETALL`, `ZRANGE`, `SMEMBERS`, `KEYS` on a narrow pattern, `INFO`), log greps, `sentry-cli issues list`, Play Console crash reads. Never `.save()`, `.update()`, `.delete()`, `.create()`, bulk writes, redis writes, container restarts, deploys, or `make deploy`/`make celery`. Anything that changes production state is tier 2 and needs an explicit yes through AskUserQuestion, then run exactly the approved command and nothing more.
3. **Never post to the forum.** Replies are drafted for Sam to paste. Never call any Discourse write endpoint.
4. **Never merge or push to main.** PRs are opened ready for review with the `forum` label. Sam merges.
5. **Tier 1 means no input needed.** The bug is reproducible, the fix is local to the code, no product decision is involved, no user account is touched. Everything else is tier 2.
6. **Reproduce before fixing.** Per CLAUDE.md: write the failing test first, then fix, then show it passing. If it cannot be reproduced, say so in the PR and the reply rather than guessing.
7. **Reply-only topics are tier 1.** A how-to question, a known limitation, a duplicate, a "works as designed": draft the reply, record it, move on. No interview needed.
8. **Ask with AskUserQuestion, never plain text.** Tier 2 decisions, and anything mid-fix that could go two materially different ways.
9. **When the auto-mode classifier blocks an approved prod write, hand it to Sam.** Write the exact script or SQL to a file at the repo root, print the one-line command that runs it, record `tier2-pending` with that command in the note, and move on. Never look for another route to the same write.
10. **Before any prod `merge_feeds`, check for branches.** `Feed.objects.filter(branch_from_feed=<duplicate>)` must be empty or re-parented first; until PR #2133 is deployed, a merge that deletes a feed with branches deletes the branches and their subscriptions too (CBC incident, 2026-09-14). Prefer `force=False` so the heavier feed survives. Once #2133 is deployed, every merge logs `MERGE_FEEDS_INVENTORY` JSON lines and a bad one is reversed with `manage.py restore_merged_feed --log FILE --feed-id ID --dry-run` first, then without `--dry-run`; grep the lines from `docker logs task-celery` on the worker that ran the merge.
11. **A PR is done only when `/commit-pr` says so.** Green CI on the current head, zero unresolved Claude or Codex review threads, marked ready for review. The push-to-clean loop lives in the `commit-pr` skill; this skill never re-implements it.

## Arguments

`/investigate-forum [flags] [forum URL ...]`

| Flag | Meaning |
|---|---|
| (none) | Topics with activity in the last 7 days, newest first, skipping ones already in `state.json`, capped at 3 topics per run |
| `--days N` | Widen or narrow the activity window |
| `--since YYYY-MM-DD` | Window start date, overrides `--days` |
| `--topic ID` or a forum URL | Only that topic (repeatable). Ignores window and state. A pasted forum URL anywhere in the prompt counts as this. |
| `--all` | Include topics already recorded in state.json |
| `--limit N` | Stop after N topics (default 3; `--limit 0` removes the cap). Three is the cap because each topic can fan out into a worktree, a PR, and review rounds, and Sam merges between runs. |
| `--dry-run` | Investigate and classify only. No worktrees, no PRs, no state writes. Print what would happen. |

## Files in this skill

| File | Purpose |
|---|---|
| `fetch_topics.py` | Pulls the queue from the public Discourse JSON API. No key needed. |
| `screenshot.py` | Headless before/after PNGs of a worktree stack via the Playwright docker image |
| `state.json` | Committed record of what was done per topic (see Step 7) |

Run both scripts from the repo root with `python3 .agents/skills/investigate-forum/<script>`.

## Step 0: Preflight

From the main repo checkout on `main`:

```bash
git status --short            # expect clean, or only state.json changes
git fetch origin && git status -sb | head -1   # note if main is behind origin
docker ps --format '{{.Names}}' | grep -c newsblur_db_   # shared DBs must be up (4)
gh auth status 2>&1 | head -2
```

If main has uncommitted changes other than `state.json`, stop and tell Sam; worktrees branch from main and a dirty main means the branch point is ambiguous. If the shared DBs are down, run `make` in the main repo first.

## Step 1: Fetch the queue

```bash
python3 .agents/skills/investigate-forum/fetch_topics.py --summary          # headers
python3 .agents/skills/investigate-forum/fetch_topics.py                    # headers + full raw threads
python3 .agents/skills/investigate-forum/fetch_topics.py --topic 13833      # one topic
```

Pass `--days`, `--since`, `--all`, `--limit` straight through. The output is newest activity first and already excludes topics whose last post is Sam's (`samuelclay`) and topics handled in `state.json` at their current last post. A topic that was handled but has a newer post since comes back marked `FOLLOW-UP`; treat it as new, but read the state entry first so the previous PR or reply is not duplicated.

Before starting the loop, also list any `state.json` entries with `"status": "tier2-pending"`. Those are questions Sam has not answered yet. Re-ask each one at the top of the run (Step 5) so he can clear them before new work begins.

Print the queue as a short numbered list so Sam can see the plan, then start with item 1.

## Step 2: Investigate one topic

Read the whole thread. Note who posted, what platform (web, iOS, Android, Mac, API), which account features are involved (premium tier, newsletters, archive, briefing, Ask AI), and whether another forum member already answered correctly.

### Classify

Pick exactly one:

| Outcome | When | Then |
|---|---|---|
| **Fix PR (tier 1)** | A code defect you can reproduce locally, fix without a product decision, and prove with a test. Includes docs and copy fixes. | Step 3 |
| **Reply only (tier 1)** | Question with a known answer, works-as-designed, a duplicate of something shipped, another member already answered and it only needs confirmation, or a feed problem caused by the publisher. | Step 4 |
| **Tier 2** | Needs a product or design decision, touches a specific user's account or subscription, needs a prod write (refetch a feed, change a user, resend an email), needs Sam's memory (pricing, roadmap, a past conversation), or the fix is large enough that Sam should agree to the approach first. | Step 5 |
| **Skip** | Praise with nothing to answer, spam, a topic that resolved itself, or an announcement thread with no question. | Record `skipped` with a one-line reason and move on. |

When unsure between tier 1 and tier 2, it is tier 2. When unsure between reply-only and skip, reply.

### Investigation toolbox

**Codebase.** Grep first. The web frontend is Backbone under `media/js/newsblur/`, Django apps under `apps/`, iOS under `clients/ios/`, Android under `clients/android/`. Check `git log -S'<phrase>' --since='3 months ago'` for recent changes near the symptom; many forum reports follow a deploy.

**Local reproduction.** The main stack is `https://localhost` (`make` to start). Dev users: `chrome`, `samuel`, `archive14`, `free3`, `free4`, `archive11`. Autologin at `/reader/dev/autologin/<user>/`. API calls via `make api URL=/reader/feeds`. Subscription state is set through the Django shell recipe in CLAUDE.md under "User State".

**Production, read-only.** All through `./utils/ssh_hz.sh -n <server> "<command>"`. Shell examples (each is a one-shot Django shell; escape inner quotes as shown):

```bash
# Who is this forum user on NewsBlur? Match on username or email from the thread.
./utils/ssh_hz.sh -n happ-web-01 "docker exec -t newsblur_web python manage.py shell -c \"
from django.contrib.auth.models import User
for u in User.objects.filter(username__iexact='mtaylor') | User.objects.filter(email__iexact='someone@example.com'):
    p = u.profile
    print(u.pk, u.username, u.email, u.last_login, 'premium' if p.is_premium else 'free', 'archive' if p.is_archive else '', 'pro' if p.is_pro else '', p.premium_expire)
\""

# A feed by URL or id: fetch state, error counts, schedule, subscribers.
./utils/ssh_hz.sh -n happ-web-01 "docker exec -t newsblur_web python manage.py shell -c \"
from apps.rss_feeds.models import Feed, MFetchHistory
for f in Feed.objects.filter(feed_address__icontains='tmz.com')[:10]:
    print(f.pk, f.feed_address, f.active, f.num_subscribers, f.last_update, f.next_scheduled_update, f.fetched_once, f.has_feed_exception, f.has_page_exception)
    print(MFetchHistory.feed(f.pk)['feed_fetch_history'][:5])
\""

# Newsletter address for a user (username-secret@newsletters.newsblur.com) and their newsletter feeds.
./utils/ssh_hz.sh -n happ-web-01 "docker exec -t newsblur_web python manage.py shell -c \"
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed
u = User.objects.get(username='mtaylor')
print(u.profile.secret_token)
for f in Feed.objects.filter(feed_address__startswith='newsletter:', usersubscription__user=u)[:20]:
    print(f.pk, f.feed_address, f.feed_title, f.last_update, f.num_subscribers)
\""

# Recent web or task logs around a symptom.
./utils/ssh_hz.sh -n happ-web-01 "docker logs newsblur_web --since 24h 2>&1 | grep -i 'newsletter' | tail -50"
./utils/ssh_hz.sh -n htask-celery-01 "docker logs task-celery --since 24h 2>&1 | grep -i 'tmz' | tail -50"

# Redis, read commands only.
./utils/ssh_hz.sh -n hdb-redis-story-1 "redis-cli hgetall feed:12345"
```

Server names live in `ansible/inventories/hetzner.ini`. Sentry: `sentry-cli --url https://sentry.newsblur.com issues list -o newsblur -p web --status unresolved --query "<keyword>"` (projects: web, task, node, monitor). Android crashes: the Play Developer Reporting recipe in CLAUDE.md. Email delivery (newsletters, notifications) goes through ImprovMX into `apps/newsletters/views.py:newsletter_receive`; bounce text quoted by a user is the best evidence there.

Never paste a user's email address or secret token into the PR or the reply. Refer to them by forum username.

## Step 3: Fix PR flow (tier 1, or tier 2 after Sam approves the fix)

Branch and worktree are named `forum-<topic id>-<three or four word slug>`, for example `forum-13833-newsletter-spam-score`.

1. **Create the worktree from main and start its stack.**
   ```bash
   git worktree add .worktree/forum-13833-newsletter-spam-score -b forum-13833-newsletter-spam-score main
   cd .worktree/forum-13833-newsletter-spam-score && make worktree
   ```
   `make worktree` prints the workspace URLs and ports. Containers are `newsblur_web_<name>`, `newsblur_celery_<name>`, etc. Restart `newsblur_celery_<name>` after touching anything a Celery task imports.

2. **Reproduce with a failing test first.** Test classes are `Test_*`, methods `test_*`. Run `make test SCOPE=apps.<app> ARGS="-v 2"` from the worktree and keep the failing output for the PR. For client bugs (iOS, Android) follow the platform notes in CLAUDE.md and `clients/ios/CLAUDE.md`; a unit test where one is feasible, otherwise a clear manual repro.

3. **Before screenshot** when the symptom is visible in the web UI. Put screenshots in `.worktree/<name>/screenshots/` (that directory is inside the gitignored worktree, so nothing is committed).
   ```bash
   python3 ../../.agents/skills/investigate-forum/screenshot.py --workspace forum-13833-newsletter-spam-score \
       --user chrome --js "NEWSBLUR.reader.open_river_stories()" --wait 4000 --out screenshots/before.png
   ```
   `--path`, `--selector`, `--theme dark`, `--full-page`, and repeated `--js` are available; see the script docstring. Read the PNG afterwards to confirm it shows the bug. Backend-only fixes skip screenshots and show the failing then passing test output instead.

4. **Fix.** Smallest change that makes the test pass. Match the code style rules in CLAUDE.md (Black 110, snake_case JS, comments that name the file, no TODOs). Restart the worktree Celery container if the change runs inside a task.

5. **Prove it.** Test passes. After screenshot with the identical command as before, then read it. Run `make lint` from the worktree if Python changed.

6. **Commit.** One focused commit per logical change, subject in the imperative naming the user-visible fix with the topic in parentheses, attribution lines from the current session appended. Stage specific files, not `git add -A`.
   ```bash
   git add apps/rss_feeds/models.py utils/feed_fetcher.py apps/rss_feeds/test_rss_feeds.py
   git commit -m "$(cat <<'EOF'
   Never ration a forbidden feed shared by active readers by their proxy budget (forum #13832)

   <why, wrapped at 72 characters>

   Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
   Claude-Session: <session url>
   EOF
   )"
   ```

7. **Hand off to `/commit-pr`.** Invoke the `commit-pr` skill from the worktree with: the title (same as the commit subject), the label `forum`, the screenshot attachments, and the PR body below. That skill pushes, opens the PR as a draft, watches CI, fixes failures, promotes the PR to ready for review, waits for the Claude and Codex review bots, fixes every review thread, and returns only when the PR is verifiably clean or it is blocked. Do not duplicate any of that here; if it reports a blocker, carry the blocker into the state entry and the report.

   PR body to pass in:
   ```markdown
   ## Forum topic
   https://forum.newsblur.com/t/<slug>/<id>
   <one sentence: what @username reported>

   ## Cause
   <two or three sentences, name the file and function>

   ## Fix
   <what changed and why this is the smallest safe change>

   ## Reproduction
   - Failing test before: `make test SCOPE=apps.x ARGS="-v 2"` (output excerpt)
   - Passing after (output excerpt)
   - Before / after screenshots attached

   ## Deploy notes
   <make deploy, make celery, both, or none; migrations; Celery restart>

   ## Forum reply draft
   **Reply for [#<id> <title>](https://forum.newsblur.com/t/<slug>/<id>)** (<username>):

   <the reply from Step 6, plain text>

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   <session url>
   ```

8. **Stop the stack, keep the worktree.** `make worktree-stop` from the worktree, then `cd` back to the main repo. Sam runs `make worktree-close` after merging.

9. Record state (Step 7) with `pr-open`, the PR URL, branch, worktree path, and the reply.

## Step 4: Reply-only flow

Draft the reply per Step 6, then record `reply-drafted` with the reply and a one-line note on why no code change is needed. If the answer depends on something you checked in prod (a feed's fetch history, a tier), say what you checked in the note so Sam can trust it.

## Step 5: Tier 2 flow

Do the investigation fully first so the question is concrete. Then one AskUserQuestion per topic with:

- A one-paragraph summary of the finding in the question text (what the user sees, what you found, what you checked).
- Options that are real choices, recommended option first and marked `(Recommended)`. Typical shapes:
  - "Fix it in a PR" vs "Reply only, explain the limitation" vs "Skip for now"
  - "Run `<exact prod command>`" vs "Do not touch prod, reply instead"
  - Two design directions with a sentence each on the trade-off
- For account-specific work (an upgrade that did not apply, a newsletter address that stopped working), spell out the exact write you would run and what it changes. Run only that after a yes, then show the output.

If Sam picks a fix, continue with Step 3. If he picks reply-only, Step 4. If the session ends before he answers, record `tier2-pending` with the question text so the next run re-asks it.

Mid-fix forks (two reasonable implementations, an ambiguous expected behavior) also get an AskUserQuestion, short, with your recommendation first.

## Step 6: Draft the forum reply

Written as Sam, ready to paste into Discourse. Plain text with at most light markdown (a link, a code span). Rules, and they are strict because CLAUDE.md is strict about them:

- No em dashes, no hyphens as punctuation. Restructure the sentence.
- No greeting, no "thanks for reaching out", no sign-off, no exclamation-heavy enthusiasm.
- Lead with the answer or the finding. Then the cause in plain words. Then what changes for them, or what you need from them.
- Under about 120 words unless the thread asks several questions.
- If a fix is in a PR, write the reply as if it is deployed ("Found it and fixed it, it'll be live in the next deploy") because Sam posts after merging. Note in the state entry that the reply assumes deploy.
- If a fix is not possible or is the publisher's problem, say so directly and offer the workaround.
- When another member already gave the right answer, credit them by username in the first sentence.
- Ask for exactly what is needed to go further (a feed URL, a screenshot, a username) and nothing more.

Sam's real replies, for voice:

> Yep, those stories are probably being removed. Open the individual feed and there should be a "Show Hidden Stories" button.

> Ok, found the bug and deployed a fix. When you tell NewsBlur to hide a topic, it was sending "sports" to the AI without saying which direction you meant. The AI read that as "Dean likes sports" and flagged those stories as matching.

> You should receive an email when it's finished but it usually takes no more than a few hours. Do you have a link to the feed that needs its backfill? Not every feed gets a backfill, some feeds just don't support it.

> Daily Briefings are a Premium Archive feature, but the app never tells you that, and that gap is causing both problems you're seeing.

Present the draft in the final report as plain text, not inside a blockquote.

## Step 7: Record state

`state.json` is committed. After each topic, update `topics["<id>"]`:

```json
{
  "title": "WIRED Newsletters blocked as spam",
  "url": "https://forum.newsblur.com/t/wired-newsletters-blocked-as-spam/13833",
  "status": "pr-open",
  "tier": 1,
  "handled_at": "2026-09-13T22:40:00Z",
  "last_posted_at": "2026-09-13T21:18:38.917Z",
  "pr": "https://github.com/samuelclay/NewsBlur/pull/1234",
  "branch": "forum-13833-newsletter-spam-score",
  "worktree": ".worktree/forum-13833-newsletter-spam-score",
  "note": "ImprovMX scores forwarded HTML newsletters as spam; nothing on our side rejects them",
  "reply": "Found it. ...",
  "question": null
}
```

`status` is one of `pr-open`, `reply-drafted`, `tier2-pending`, `skipped`, `done`. `last_posted_at` must be copied verbatim from `fetch_topics.py --topic <id> --json` (never typed from memory; the milliseconds matter), because an exact match is how follow-ups are detected. `question` holds the pending AskUserQuestion text for `tier2-pending`. `reply` holds the draft. Keep older keys when updating an entry.

At the end of the run (or after each topic when the run is long), commit the state file on main, not pushed:

```bash
git add .agents/skills/investigate-forum/state.json
git commit -m "$(cat <<'EOF'
Forum triage: record topics 13833, 13832

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: <session url>
EOF
)"
```

With `--dry-run`, skip this step entirely.

## Step 8: Report

The final message is what Sam reads when he comes back. For each topic handled this run, in the order handled:

- Topic title and forum link on the first line.
- Outcome: PR link with its verified state from `/commit-pr` (CI green and review threads clear, or the exact blocker), or reply-only, or the tier 2 decision he made, or skipped with the reason.
- The reply draft as plain text, ready to copy, under a bold label that links straight to the topic so Sam can click through and paste. Always this exact shape, with the topic URL from the fetch output:

  `**Reply for [#13833 WIRED Newsletters blocked as spam](https://forum.newsblur.com/t/wired-newsletters-blocked-as-spam/13833)** (mtaylor):`

  The same linked label goes at the top of the PR body's "Forum reply draft" section and into any email or message draft that refers to a topic.
- Anything left for him: merge and deploy target (`make deploy`, `make celery`, or both), a `make worktree-close` reminder, a pending question.

Then a one-line tally: handled, PRs opened, replies drafted, pending questions, skipped. Nothing else.

## Resuming

State makes runs idempotent. On the next run, `fetch_topics.py` hides handled topics unless someone posted again. Sam replying on the forum makes the topic disappear from the queue on its own. To revisit a handled topic deliberately, pass `--topic <id>` or `--all`.
