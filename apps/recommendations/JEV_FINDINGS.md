# Jev discovery feasibility experiment

Measured on September 19, 2026 using one consenting production account and
read-only extraction. This report contains aggregate findings; private reading
history, prompts, responses, and credentials are not included in Git.

## What Jev could do

[Jev](https://openrouter.ai/typesafe/jev-1.13) is TypeSafe's text-based structured
decision model. It returns typed choices for tasks such as classification. The
experiment used OpenRouter's `/api/alpha/decisions` endpoint, whose responses
identified the model as `typesafe/jev-1.13-20260917`.

The product hypothesis, inspired by
[Rob Hallam's thread](https://x.com/robj3d3/status/2101074194260000982), was to ask
several questions about each article: substance, promotion, bait, visual
dependence, topic, personal interest, and overlap with the reader's history.
Shared article features could be cached across readers; personal comparisons
would run on a shortlist.

## What the experiment found

| Measurement | Result |
| --- | --- |
| Successful API requests | 375 of 375 |
| Distinct stories scored | 257 |
| Question answers | 2,315 |
| Billed input / output tokens | 2,559,938 / 71,575 |
| Total measured cost | $0.107517, within the $10 experiment cap |
| Client request latency | Median 201 ms; p95 324 ms, generally at concurrency 3 |
| New-source candidate pool after alias/duplicate exclusions | 121 of 143 candidates |

Existing production signals are sufficient for a discovery prototype: recent
read hashes, per-story reading duration, saved/shared stories, and explicit
intelligence training. They need careful interpretation. The dwell value is a
daily maximum, capped at 1,200 seconds and retained for eight days; it is not
total attention or a durable session history. The recent read list has no event
timestamps. Brief reads and unread stories are not reliable dislike labels.

Content availability mattered. Of 203 usable dwell stories, 82 had at least 100
words of RSS text. Already-cached original text raised this to 148 without
fetching new pages. Feed-ID exclusion alone also admitted alternate feeds from
publishers already followed; 22 candidate aliases/duplicates needed exclusion.

The reader said they would open all three examples presented for feedback:
the Project Lily investigation, Flock camera vulnerabilities, and a lentil-based
meat recipe. These were assistant-selected examples and stated intent, not
observed reads or an unbiased relevance sample.

## Interest prediction was not strong enough for automatic skipping

Training examples preceded September 18. The held-out sample used September
18–19 stories without earlier dwell observations. Of 66 stories, 56 met the
comparison thresholds: 18 with at least 30 seconds recorded and 38 with at most
15 seconds. Longer reading is only an attention proxy.

| Method | Held-out AUC |
| --- | --- |
| Jev personal interest, one article per request | 0.580 |
| Jev personal interest, batched articles | 0.591 |
| Generic Jev substance/promotion/bait features | 0.585 |
| TF-IDF similarity to the same profile | 0.651 |
| Existing explicit training score | 0.504 |

AUC measures whether longer-read stories rank above brief-read stories; 0.5 is
chance. Jev's approximate bootstrap 95% interval was 0.40–0.74. This small,
correlated sample and the exploration of several methods do not establish a
statistical winner, and the online baseline in `discovery.py` is not identical
to the offline evaluation pipeline.

An interest cutoff below 0.35 skipped no held-out stories. Raising it to 0.50
skipped seven, including two of the 18 longer reads. A separate dry run on 46
verified unread stories kept 18, skipped five, and left 23 undecided. All five
skips came from existing negative training. Both requested Focus policies were
simulated: hide while keeping unread, or mark skipped posts read. Neither was
executed, and automatic Focus is not part of this implementation.

## Cost implications

At the measured text lengths and batching, five shared questions cost about
$0.57 per 10,000 equivalent story evaluations. Two personal questions cost
$0.87 batched or $2.74 with one article per request. These extrapolations omit
retrieval, indexing, storage, and orchestration and are not throughput promises.

No comparison against the existing Haiku classifier was run. Adding Discovery
does not itself save money; savings require replacing existing work at adequate
quality. Reusable article features are a plausible next experiment, while direct
personal-interest prediction needs more validation.

## Implementation decision

Start with a separate, reversible Discovery stream using text similarity,
reading duration, saves/shares, and explicit More/Less feedback. Votes affect
future rankings while keeping the current article and read state in place.
Each article retains its source title, favicon, and ordinary reader header.
Two compact header buttons expand into a confirmation after saving. Clicking
the confirmation reopens the choices; selecting the current choice clears it.
A stream-header sparkline opens a dialog with More/Less lists, all-time active
counts, and a 30-day UTC chart grouped by the last change to each active choice.
Readers can switch or clear any choice, including for stories that have expired.
Cleared choices do not contribute to the counts, chart, or recommendation ranker.
Use that feedback to evaluate later semantic features or a learned ranker.
The initial web path makes no Jev calls and needs no OpenRouter credential.

Important limits remain: the candidate pool inherits the coverage of the
existing trending lists, so small feeds and image-led posts may be missed;
feedback currently uses story hashes rather than a persistent cross-feed
article identity; exposure logging and durable attention events are not yet
implemented. No online recommendation-quality test or automatic-skipping
validation has been completed.

Private experiment artifacts and the cost ledger remain under
the gitignored `.jev-discover/` directory in this worktree. The helper reads its key from
`/srv/secrets-newsblur/keys/openrouter-jev.env`. No additional model calls were
made while preparing this PR.
