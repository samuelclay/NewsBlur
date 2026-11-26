# Premium Team: market research

Checked 2026-11-25. Companion to `PREMIUM_TEAM.md`.

How to read the evidence labels:

- **Live**: read on the vendor's own page on the date above.
- **3P**: third party estimate (Vendr, review sites, competitor blogs). Often stale.
- **Unofficial**: from a document that is public but clearly not meant to be quoted.

Quotes came through a page summarizer. Spot check the wording on the source page before any of it goes into public copy.

## The short version

1. **There is a price hole exactly where $79 and $129 sit.** Feedly sells nothing between $144/year for one person and $19,200/year for a team. Inoreader fills the hole with seat bands ($119.99/month for 10 seats). Feeder charges per seat ($150 to $200/month for 10).
2. **Nobody does what the brief describes.** Shared read status exists only at Feeder, as an all or nothing switch per workspace. No reader assigns feeds to people, shows who read a story, shows which folders nobody is watching, or lets a manager verify that teammates' notifications work.
3. **Folders are opt in at Feedly and Inoreader.** Teammates have to choose to follow a team folder. Only Feeder pushes a default workspace to everyone.
4. **Slack and Microsoft Teams delivery is table stakes.** Every team product has it and several gate it to upper tiers. NewsBlur has no Slack, Teams or webhook output today.
5. **SSO is usually behind a sales call.** Feedly, Feeder, Sparkfeed and start.me quote it. Inoreader is the exception: SAML in every Team tier, self serve, but no SCIM and (as of February 2024) no SSO in its mobile apps.
6. **Microsoft retired the Teams RSS connector on May 22, 2026.** Its replacement (Workflows) is tied to one person and breaks when that person leaves. That is an open door for "RSS to Microsoft Teams".

## Price map

| Product | Team price | Model | Seats | SSO |
|---|---|---|---|---|
| **Premium Team (proposed)** | **$79/month** | Flat | 10, call for more | No |
| **Premium Team with SSO (proposed)** | **$129/month** | Flat | 10, call for more | SAML, OIDC, SCIM |
| Inoreader Team | $44.99 / $74.99 / $119.99 / $224.99 / $374.99 per month | Seat bands | 3 / 5 / 10 / 20 / 50 | SAML in every band, no SCIM |
| Inoreader Team Intelligence | $64.99 to $629.99 per month | Seat bands | 3 to 50 | Same |
| Feeder Professional | $19.99 per user per month, $14.99 yearly | Per seat | No minimum | Enterprise only, by quote |
| Feedly Business (legacy) | $18 per user per month, 3 minimum | Per seat | n/a | No longer sold |
| Feedly Market Intelligence | $1,600/month (10 seats), $2,400/month (25 seats), annual only | Flat | 10 / 25 | Top tier only |
| Feedly Threat Intelligence | By quote. $48k to $68k/year (Unofficial) | Flat | n/a | Top tier only |
| RSS.app Pro | $83.32/month | Flat | 10 | No |
| SereneReader Team | $25/month | Flat | 5 | No |
| start.me Team | $30/month (3P) | Flat | 20 licences | Enterprise only |
| Sparkfeed Pro | $12 per user per month | Per seat | Max 10 | Enterprise only |

What this means for the two prices:

- **$79 for 10 seats** is $41 under Inoreader's 10 seat band and roughly half of Feeder at 10 seats. It is $4 above Inoreader's 5 seat band, so a team of 5 or fewer pays slightly more with us and gets Pro level seats and shared read status for it.
- **$129 for 10 seats with SSO** is $9 above Inoreader's 10 seat band, which already includes SAML. Price alone does not win this comparison. SCIM, SSO in the mobile apps, shared read status, pushed folders and managed notifications do.
- Above 10 seats, Inoreader jumps to $224.99 (20 seats). "Call for more" has room up to there.

## Feedly

Positioning has moved to AI and intelligence products. The team features live only in the Enterprise products.

- **Plans.** Free (100 feeds), Pro ($72/year, 1,000 feeds), Pro+ ($144/year, 2,500 feeds, "There is no shared team workspace"), then Market Intelligence and Threat Intelligence. Annual only and sales led. The pricing FAQ says price follows "the computation power needed to run the AI Models and AI Feeds", not seats. (Live)
- **Team folders and feeds.** Opt in. The creator is "the only person on the team that has that Folder" until teammates "actively follow". Admins can preselect feeds and boards at invite time. No locked or forced folders found. (Live)
- **Team boards.** Manually saved articles with notes, highlights, comments, tags and "assign follow-ups". Mentions by `+email` or `@slack`. (Live)
- **Newsletters.** Built from boards, folders or AI Feeds on a schedule. 5 to 20 templates, 100 or 250 recipients, recipients need no seat, open and click stats per recipient. (Live)
- **Slack and Teams.** A channel subscribes to a team feed or board, with optional AI summary, dedupe and translation. (Live)
- **Roles.** Admin, Editor, Viewer. (Live)
- **SSO.** SAML with just in time provisioning, domain mapping, optional strict enforcement. Setup means emailing metadata to Feedly. "Feedly does not SCIM." (Live)
- **Read status.** "'Mark as read' and 'read' are all on the individual level." No who read what view. (Live, article last updated 2021)
- **One team per company.** Multiple teams are handled with naming prefixes. (Live)
- **Complaints.** The enterprise and AI pivot, features gated to Enterprise, no monthly web billing on Pro+, API only on the top tier. Trustpilot 1.7 of 5 from 36 reviews. (3P)

## Inoreader

The closest competitor on price and the most complete team reader.

- **Plans.** Pro $9.99/month. Team in five seat bands (table above), monthly only, self serve checkout, trial through sales. (Live)
- **Pooled limits since April 2026.** One pool per team: 10,000 feeds, 150 to 200 monitoring feeds, 100 to 150 rules, 5 to 10 email digests, 5M to 10M AI tokens, API 100 calls a day. Billing shows each member's share of each pool. (Live)
- **Team folders.** Built by an admin, shared with selected members, opt in ("follow in one click"). Team filters (dedupe, content) apply to the whole folder. (Live)
- **Channels.** Invite only spaces where members share single articles with a note, comment and mention each other. Auto forward to Slack or Teams. (Live)
- **Team tags, dashboards, file uploads, shared highlights and notes, keyword spotlights.** (Live)
- **Email digests.** Admin created, scheduled, drag and drop template, logo, AI summaries. (Live)
- **SSO.** SAML in every Team band, self serve, keyed on email domain. No SCIM. Departed staff are removed by hand. Did not work in the mobile apps as of February 2024. (Live)
- **Activity timeline.** Shares, comments, new members, folders, tags, digests. No reading data. (Live)
- **Nothing found for** shared read status, assigning feeds or stories, coverage, or manager controlled notifications.
- **Complaints.** Pro renewals went from $49 to $89 a year in February 2024, growing limits, cluttered UI, removal of social features for individuals in January 2025. (3P)

## Feeder

The only product with shared read status.

- **Professional.** $19.99 per user per month ($14.99 yearly), 10,000 feeds, 1 minute refresh. Enterprise by quote adds SAML, Entra SCIM, API and invoicing. (Live)
- **Shared unreads.** A switch per workspace that the team admin sets. "Any time a team member interacts with a post, it updates for everyone in that workspace." Not retroactive. All or nothing per workspace, and no record of who read what. (Live)
- **Pushed default workspace.** "Every team has a default workspace, and new members join it automatically." It cannot be left. Members see "Managed by your Team Admin". (Live)
- **Admin set rules.** A teammate sees them "under Rules from your team admin, and only Team Admins can change it." Rules that post to Slack apply team wide. (Live)
- **Delivery.** Slack, Teams, Discord, Telegram, webhooks, Zapier. (Live)
- **Pitch.** "Keep your whole team ahead of the news." Aimed at security, compliance, pharma, finance and newsrooms. (Live)

## Everyone else

- **No team plan:** Feedbin, BazQux, Readwise Reader, Folo, Raindrop.io, Matter, Refind, Blogtrottr, Feedrabbit.
- **Gone:** Netvibes (retired as a standalone service), Cronycle and FlowReader (appear defunct), tt-rss.org (retired November 2025, community fork continues).
- **Self hosted (FreshRSS, Miniflux):** multi user, but every user has separate subscriptions and read state.
- **Slack's RSS app:** free, `/feed subscribe <url>` posts into a channel. No read state, no filtering. This is what most small teams actually use.
- **MonitoRSS:** flat per workspace, "Add unlimited teammates, free", metered by feeds. The framing is worth noting even though it is a Discord bot.

## The adjacent market: news monitoring and alerts

These are what a team buys when it outgrows Google Alerts.

| Tier | Examples | Price |
|---|---|---|
| Free | Google Alerts, Talkwalker Alerts, Slack RSS app | $0 |
| Self serve | Awario, F5Bot, Syften, Distill, Visualping, Brand24, BuzzSumo | $30 to $500 per month, metered by keywords or pages, with seats and Slack gated to upper tiers |
| Contract | Muck Rack, Cision, Meltwater, Klue, Crayon, Dataminr, Feedly | $5k to $70k per year, annual, sales led (mostly 3P) |

Specific gates worth knowing (Live): Slack starts at $299/month at BuzzSumo, $140/month at Visualping (5 users), $49.95/month at Syften and $49.99/month at F5Bot. Brand24 with unlimited users is $299/month.

Workflows that recur across these products and that an RSS reader can deliver cheaply:

- Routing alerts to channels and to specific people
- Shared alerts with an owner, roles, tags and assignment
- Scheduled digests for stakeholders who never log in
- Coverage reports as PDF or spreadsheet, white labelled for agencies
- Spike alerts when a keyword's volume jumps (Brand24 calls them storm alerts)
- Separate workspaces per client for agencies

What an RSS reader cannot cheaply deliver: social listening, broadcast and print, licensed paywalled content, sentiment and reach metrics, journalist databases.

What small teams cobble together today: Google Alerts by email, the Slack RSS app or Zapier into a channel, individual reader accounts, Visualping for pages without feeds, a shared spreadsheet and a weekly meeting. The complaints: Google Alerts misses things or stops silently, a broken feed "looks like a slow news week", raw feeds in Slack are noisy, and assigned owners lapse within weeks. These complaints come from vendor blogs, not first hand threads. Reddit and G2 could not be loaded.

## Who would buy this

Ranked by fit. This ranking is judgment, not sourced data.

1. **Security and threat intel teams** (small SOCs, MSSPs). Already live on RSS and pipe advisories into Slack. "Did everyone see it" is the pitch.
2. **Agencies** (boutique PR, public affairs). Team folders map to clients and a flat price beats per seat.
3. **Competitive intel at startups and small companies.** They run Google Alerts plus a Slack channel. Klue and Crayon are out of reach.
4. **Legal, regulatory and compliance.** Regulators publish feeds and a miss is costly. Visualping at $100 to $140 shows the budget exists.
5. **Small newsrooms and newsletter publishers.** Instant alerts are the core need. Budgets are thin and they want social sources.
6. **In house PR and comms.** They expect social, broadcast and sentiment, so RSS undershoots.
7. **Investor relations and research libraries.** Budget exists but they want licensed content and long procurement.

## Search phrases

Qualitative only. No volume data was available.

- **Delivery (most winnable, held by utilities like rss.app and Zapier):** rss to slack, slack news alerts, rss to microsoft teams, news alerts in microsoft teams, breaking news alerts for teams
- **Team reader (Feedly, Inoreader, Feeder):** team rss reader, shared rss reader for teams, rss reader for business
- **Replace the free tool (Brand24, Awario and Mention blogs dominate):** google alerts alternative, google alerts for teams, google alerts to slack, google alerts not working
- **Category (Meltwater, Cision, G2 dominate):** news monitoring tool for teams, affordable media monitoring, meltwater alternative, cision alternative
- **Persona (fragmented):** competitor news alerts, cve alerts slack, threat intelligence rss feeds, regulatory news monitoring, feedly alternative for teams, inoreader alternative for teams

## What to copy and what to skip

Copy:

- Feeder's pushed default folder with "Managed by your Team Admin"
- Feeder's shared unreads, but per folder and with a record of who read what
- Inoreader's pooled limits with a per member breakdown
- Inoreader's and Feedly's scheduled digests to people without a seat
- Feedly's preselected folders at invite time
- Public self serve pricing and self serve SSO
- Slack and Teams delivery per folder with dedupe

Skip, at least at first:

- AI feeds, trend dashboards and "intelligence" positioning. Feedly's users complain about exactly this.
- Social listening and sentiment
- Channels as a separate chat space. Comments on stories are enough.

## Pages that could not be loaded

G2, Capterra and GetApp (403), Reddit (blocked), Vendr marketplace pages (403), start.me (403), Feedspot (403), The Old Reader (404), feedly.com/pricing (JS app, read from its script bundle instead), inoreader.com/teams (sign in wall), Signal AI, NewsWhip and Ground News pricing (404), Factiva and LexisNexis (blocked).

## Sources

Feedly:
- https://feedly.com/market-intelligence/pricing
- https://feedly.com/threat-intelligence/pricing
- https://docs.feedly.com/article/736-team-folders-vs-personal-folders
- https://docs.feedly.com/article/150-how-do-i-get-my-teammates-to-follow-my-feeds
- https://docs.feedly.com/article/805-feeds-and-boards
- https://docs.feedly.com/article/757-roles-and-permission
- https://docs.feedly.com/article/756-feedly-enterprise-sso-integration-guide
- https://docs.feedly.com/article/550-when-i-mark-an-article-as-read-in-a-team-feed-will-others-still-see-it-as-unread
- https://docs.feedly.com/article/737-managing-multiple-teams-in-feedly-best-practices-for-clear-and-organized-workflows
- https://docs.feedly.com/article/841-feedlys-integration-for-microsoft-teams
- https://feedly.com/legal/security
- https://docs.feedly.com/article/863-feedly-pro-support-knowledge-private (Unofficial. Do not quote publicly.)
- https://news.ycombinator.com/item?id=45522425 and https://news.ycombinator.com/item?id=47037738
- https://nz.trustpilot.com/review/feedly.com

Inoreader:
- https://www.inoreader.com/pricing
- https://www.inoreader.com/pricing/enterprise
- https://www.inoreader.com/blog/2026/04/introducing-shared-feature-pools-for-inoreader-teams.html
- https://www.inoreader.com/blog/2026/03/introducing-new-collaboration-features-for-inoreader-teams.html
- https://www.inoreader.com/blog/2024/01/manage-shared-feeds-with-new-team-folders.html
- https://www.inoreader.com/help/teams/team-folders
- https://www.inoreader.com/blog/2024/02/new-single-sign-on-sso-feature-for-enterprise-clients.html
- https://www.inoreader.com/help/teams/activity-collaboration
- https://www.inoreader.com/help/teams/access-limits-plans
- https://www.inoreader.com/blog/2025/08/redesigned-email-digests-for-more-control-and-flexibility.html
- https://www.inoreader.com/developers/rate-limiting
- https://talk.macpowerusers.com/t/rss-reader-inoreader-subscription-costs-doubled-90-yr-alternatives/36251

Feeder and other readers:
- https://feeder.co/pricing
- https://feeder.co/help/teams/workspaces/
- https://feeder.co/help/collaboration/shared-unreads-for-workspaces
- https://feeder.co/help/teams/how-to-share-feeds-with-your-team/
- https://feeder.co/business
- https://rss.app/pricing
- https://serenereader.com/pricing
- https://sparkfeed.dev/pricing
- https://monitorss.xyz/pricing
- https://slack.com/help/articles/218688467-Add-RSS-feeds-to-Slack
- https://learn.microsoft.com/microsoftteams/m365-custom-connectors
- https://office365itpros.com/2026/09/18/teams-workflows-updates/

News monitoring:
- https://brand24.com/prices/
- https://awario.com/pricing/
- https://buzzsumo.com/pricing/
- https://mention.com/en/pricing/
- https://muckrack.com/pricing
- https://www.meltwater.com/en/pricing
- https://visualping.io/pricing
- https://distill.io/pricing/
- https://f5bot.com/
- https://syften.com/
- https://www.talkwalker.com/alerts
- https://ground.news/group-subscriptions
