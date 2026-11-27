# Premium Team

The plan and build checklist for a team tier on NewsBlur. Market research is in `PREMIUM_TEAM_RESEARCH.md`.

## How to use this file

- Every line with a box is something to decide, build, test or capture.
- `[ ]` is not done. `[x]` is done: built, tested and committed on this branch.
- Each feature section ends with a **Screenshots** list. Those are the pictures the feature page needs, one per distinct feature.
- Work happens in the order of the "Build order" section. A box is ticked in the same commit that finishes it.
- Decisions made while building are recorded under "Decisions" with the date.
- Every step that adds or changes a screen gets its screenshots attached to the pull request, for the web, iOS, macOS and Android.

## What it is

A team is a group of up to 10 NewsBlur accounts on one bill. Each teammate keeps a private account with their own feeds. On top of that the team owns folders of feeds that appear in every teammate's feed list. A manager decides, folder by folder, whether read status is personal or shared, who is assigned to watch it, and which notifications everyone gets. The manager can then check that those notifications actually reach each teammate.

The pitch in one line: instant news alerts for your team, and proof that somebody read them.

## Decisions

Decided on 2026-11-25:

- [x] The name is Premium Team
- [x] Two tiers: $79/month and $129/month
- [x] The $129 tier adds SAML/OIDC single sign-on and SCIM. The $79 tier has neither
- [x] 10 seats on both tiers. More than 10 is "call for more"
- [x] Every teammate's own account gets Premium Pro
- [x] Single sign-on is full SAML and OIDC plus SCIM

Decided on 2026-11-26:

- [x] Build everything in both feature parts below, not only the core
- [x] No onboarding call
- [x] Team dialogs follow the redesigned Preferences dialog: tabs, grouped rows, illustrated option cards, changes saved as they are made
- [x] The feature page lives on the welcome page, with screenshots for every section
- [x] A team is one Premium Pro account that happens to have up to 10 people using it. Everything Pro meters is shared across the team: 10,000 sites in total, 10 hours of Listen a week in total, and the same for any other Pro allowance
- [x] Anyone the team invites can join. No work email or shared domain is required
- [x] Every step is finished on the web, iOS, macOS and Android before the next one starts. macOS is the Mac build of the iOS app, so each iOS screen is also checked there
- [x] The PR is ready for review from the start, and the review bots review every push

- [x] The team is the owner's account. The owner is the one who pays, and everything the team shares falls under the owner's user id: billing, shared read status, team training and metered usage. There are no hidden accounts
- [x] The $129 tier is called Premium Team Enterprise
- [x] When someone who pays for their own plan joins a team, their Stripe or PayPal renewal is cancelled automatically and they keep what they already paid for until it runs out. App Store and Play subscriptions cannot be cancelled by us, so those teammates get a notice with a link
- [x] No grace period. Leaving a team or being removed downgrades the account at once, to the plan the person has on their own or to free, with one email saying so. This replaces an earlier 14 day grace, dropped on 2026-11-26 because it let people rotate through a team's seats and keep Premium Pro for two weeks each
- [x] No free trial
- [x] The shared site limit counts distinct sites: every different site in team folders or in any teammate's private feeds counts once, however many teammates follow it
- [x] An owner can hand the team to another teammate without contacting support. The new owner accepts and enters a card, the team's shared read status and training move to their account, and the old owner's team plan ends
- [x] Monthly billing only. No annual price
- [x] Dropped from the extensions: the onboarding call, priority support with a response time, security and privacy documents, the nonprofit, school and newsroom discount, SMS alerts, Apple Watch alerts, the lock screen Live Activity, and critical alerts through Do Not Disturb. Everything else in part 2 is built
- [x] White label branding is only available on Premium Team Enterprise
- [x] Also only on Premium Team Enterprise: audit log export and SIEM streaming, the IP allow list, session length limits and sign in history, groups synced from the identity provider, and the data retention setting with full export. The activity log itself is on both tiers
- [x] Read status follows the site. Once a site is in a team folder with shared read status or read receipts, it is a team site wherever it appears in a teammate's feed list. A private copy of it shows the team badge and says reads are shared, and the join screen says so. Reading on sites that are in no team folder is never shown to anyone
- [x] An account is in one team at a time, as owner or member. Agencies separate clients inside one team with folders shared to chosen teammates. No team switcher
- [x] "More than 10 teammates? Get in touch" opens a short form (team name, seats wanted, a note) that emails Sam with the account attached
- [x] A team whose payment lapses goes inactive the day its paid period ends, with one email to everyone and no grace. A payment that later succeeds brings the team straight back
- [x] When a site a teammate follows privately becomes a team site, the private copy shows the team badge and nothing else is said
- [x] With single sign-on required, what happens to a removed teammate's account depends on how it was created. An account that existed before joining stays the person's. An account that single sign-on created is locked, with an export of its private feeds on request
- [x] One push per build step, so the review bots review each finished step once
- [x] The team screens on iOS and Android are native: SwiftUI on iOS and Compose on Android, each in that app's own settings style. The web dialog follows the redesigned Preferences, with no Done button and changes saved as made
- [x] Everything is feature complete on the web, iOS, macOS and Android: every team dialog, every option, every read status indicator. Nothing is web only
- [x] Both team plans are for sale on every platform: Stripe and PayPal on the web, the App Store on iOS and macOS, and Google Play on Android, the way Premium, Archive and Pro are sold today
- [x] Store prices are $79.99 and $129.99 a month. Web prices stay $79 and $129
- [x] The App Store and Play products are created when billing reaches the apps, with their names, prices and descriptions shown to Sam before they are saved
- [x] The team's name is asked for after purchase, on every platform. The team starts with a default name and the first thing shown afterwards is the team dialog asking for the real one
- [x] An owner who switches down from a team plan keeps the team until the month already paid for runs out, then the lower plan starts
- [x] On an ownership transfer, the old owner is refunded the unused part of their month when they paid by Stripe or PayPal. App Store and Play purchases cannot be refunded by us
- [x] When a team lapses, the owner's own account is treated like any lapsed plan: it keeps Premium Pro features through the usual expiry window, with the usual emails, while the team itself is off
- [x] Verifying payment notices and app purchases for every plan is part of step 3, on this PR
- [x] If a provider's webhook signing secret is not configured in production, its notices are still handled, and each one reports an error so the missing secret cannot go unnoticed
- [x] App Store sandbox purchases (App Review, TestFlight, sandbox testers) start and renew a plan like any other, for anyone, and a sandbox team behaves exactly like a paid one. Sandbox payments are kept out of revenue totals
- [x] Purchases reported by app versions already released are handled as they are today. Only the signed form, used for team plans and by app versions from this release on, is verified with Apple
- [x] A team that is active must be paid for or comped. One that is neither, with no paid through date, is lapsed by the hourly task, and only the owner of a team that is paid for or comped is spared the nightly expiry
- [x] Only staff can comp a team, and a comped team stays comped: a later payment for it changes nothing and staff are emailed
- [x] A new team is named after its owner ("samuel's team") until the owner renames it
- [x] When a team's coverage ends, an owner who still has a valid plan of their own goes back to exactly that plan: a lifetime plan, or one bought elsewhere that is still paid for. An owner with no other plan goes through the normal expiry window. The owner's own plan is remembered the same way a teammate's is
- [x] A payment notice that arrives late or twice cannot undo a newer one, and a payment for a period that has already lapsed starts and revives nothing
- [x] On Stripe a payment counts as confirmed when the subscription is active and its latest invoice is paid. A full refund or a dispute ends the team at once. A partial refund does not
- [x] A switch down from a team plan on Stripe is a subscription schedule: the paid plan until the period ends, then the lower one. `Team.pending_plan` shows the owner what is coming
- [x] Voice previews and transcription are shared across the team like Listen and Ask AI. Days and weeks follow the owner's timezone, and a staff Listen reset for any teammate resets the team's hours
- [x] The message at a shared limit names the team. Only the site limit message names the owner, since making room for sites is something the owner can do
- [x] If one owner ends up paying for a team plan in two places, the newest purchase wins, the older web renewal is cancelled, and staff are emailed. The stores take the money before the server hears of a purchase, so this cannot be refused up front
- [x] Invite links are a path, `/team/join/<token>`, because the apps can claim a path but not a query string. The invite is carried through login or signup the way gift codes are, and the welcome page names the team before signup
- [x] AI filters are pay per use. A teammate can use them once the owner turns usage billing on, and the cost goes on the owner's card with each teammate's share recorded
- [x] Someone whose private feeds push the team past 10,000 sites can still join. Their sites beyond what fits are muted, newest first, and they choose which to keep

Still open. Each has a recommendation further down under "Open decisions":

- [ ] Price above 10 seats

## The upgrade dialog

The upgrade dialog (`media/js/newsblur/reader/reader_premium_upgrade.js`) has three cards on top (Premium, Premium Archive, Premium Pro) and a bottom row (Free, Self-Hosted).

- [ ] A "For teams" row between them with two cards side by side
- [ ] A "Start a team" button on each card that goes to Stripe Checkout
- [ ] A line under the row: "More than 10 teammates? Get in touch."
- [ ] A line at the bottom of the Premium Pro card: "Reading with coworkers? See Premium Team"
- [ ] A callout in the notifications dialog: "Set these up for your whole team"
- [ ] A callout in the folder menu: "Share this folder with a team"
- [ ] A callout in the account dialog for anyone not on a team
- [ ] The "For teams" row with both plans in the iOS and macOS premium screen, bought through the App Store
- [ ] The "For teams" row with both plans in the Android premium screen, bought through Google Play

**Premium Team, $79/month.** Up to 10 teammates. Everything in Premium Pro, shared by the whole team, plus:

- [ ] Team folders that appear in every teammate's feed list
- [ ] Add a site once and the whole team is following it
- [ ] Shared read status, chosen folder by folder
- [ ] See which teammates have read a story
- [ ] Assign teammates to folders so every folder has an owner
- [ ] Managers set notifications for the whole team
- [ ] Check that every teammate's notifications are working
- [ ] Send stories to Slack, Microsoft Teams or a webhook
- [ ] Train a folder once for everybody
- [ ] One bill, with invoices

**Premium Team Enterprise, $129/month.** Everything in Premium Team, plus:

- [ ] Single sign-on with SAML or OIDC
- [ ] Works with Okta, Microsoft Entra ID, Google Workspace and OneLogin
- [ ] SCIM adds and removes teammates automatically
- [ ] Verify your domain and coworkers join on signup
- [ ] Require single sign-on for everyone on your domain
- [ ] Single sign-on in the iOS and Android apps
- [ ] Removing a teammate signs them out everywhere
- [ ] White label reports, digests and public pages with your own branding
- [ ] Audit log export, IP allow list and session limits
- [ ] Data retention and full export

**Screenshots**

- [ ] The upgrade dialog with the "For teams" row
- [ ] Stripe Checkout for a team

## Features, part 1: the core

### 1. Seats and accounts

- [ ] Up to 10 teammates on one plan
- [ ] "More than 10 teammates? Get in touch" opens a short form that emails staff with the team name, seats wanted, a note and the account
- [ ] Every teammate gets every Premium Pro feature: feeds fetched every 5 to 15 minutes, archive, Ask AI, regular expressions, MCP and CLI
- [x] The team shares one Premium Pro account's allowances: 10,000 sites across team folders and everyone's private feeds
- [x] The team shares 10 hours of Listen a week
- [x] Every other Pro allowance (Ask AI, AI filters) is shared the same way
- [ ] Every teammate keeps private feeds and folders that the team cannot see
- [ ] Join with an existing NewsBlur account and keep everything in it
- [ ] Invite by email
- [ ] Invite with a join link
- [ ] Invite links are `/team/join/<token>`. On the web they open the join screen, and on a phone with the app installed they open the app
- [ ] A logged out visitor who opens an invite sees the team's name on the welcome page, and the invite survives login or signup
- [ ] Three roles: owner, manager, member
- [ ] One bill on the owner's account, with invoices
- [ ] An account is in one team at a time, as owner or member
- [ ] Leave or be removed and the account drops back to its own plan at once. Its private feeds stay, and on the free plan they are muted until the person picks 64 to keep
- [ ] Transfer ownership to another teammate, who accepts, enters a card and takes over the bill
- [ ] On transfer the team's shared read status and training move to the new owner's account

**Screenshots**

- [ ] The Members tab of the team dialog
- [ ] The invite form and a pending invite
- [ ] The join screen a new teammate sees

### 2. Team folders

- [ ] Team folders appear in every teammate's feed list on the web
- [ ] Team folders appear in every teammate's feed list on iOS
- [ ] Team folders appear in every teammate's feed list on Android
- [ ] Add a site to a team folder and it shows up for everyone within seconds
- [ ] Rename, reorder, move or remove once and it changes for the whole team
- [ ] Share a folder with the whole team or only some teammates
- [ ] New teammates get the right folders the moment they join
- [ ] Team folders are marked so nobody confuses them with their own
- [ ] Members cannot rename or delete team folders. They see "Managed by your team"
- [ ] A site can be in a team folder and in a private folder at the same time
- [ ] A private copy of a site that is in a shared or read receipt team folder shows the team badge and says its reads are shared
- [ ] Newsletters and briefing feeds stay personal and cannot be placed in a team folder

**Screenshots**

- [ ] A feed list with private folders and team folders side by side
- [ ] A manager adding a site to a team folder
- [ ] The team folder dialog
- [ ] What a member sees on a folder they cannot edit

### 3. Read status

- [ ] Three modes per team folder: personal, personal with read receipts, or shared
- [ ] Shared: a story read by one teammate is read for everyone
- [ ] Read receipts: see who has read a story and when
- [ ] A count on each story of how many teammates have read it
- [ ] Reads sync live to every teammate's open app
- [ ] Turning shared mode on is not retroactive, with a one time option to bring everyone to the manager's read state
- [ ] A teammate who joins a shared folder later starts from the team's read state
- [ ] "Mark all as read" in a shared folder asks first and says how many teammates it affects
- [ ] Undo a team wide mark all as read
- [ ] Read status follows the site: a site in a shared or read receipt team folder is a team site wherever a teammate reads it
- [ ] A site in two team folders takes the most shared of their read modes, and the folder dialog says so
- [ ] Reading on sites that are in no team folder is never shown to anyone
- [ ] The join screen says which reading the team can see
- [ ] Only reads made after a site becomes a team site are shared. Earlier reads are never shown

**Screenshots**

- [ ] The three read modes as option cards in the folder dialog
- [ ] A story list with "Read by" pills
- [ ] The "Read by" line on an open story
- [ ] The mark all as read confirmation in a shared folder

### 4. Assignments and coverage

- [ ] Assign one or more teammates to a folder
- [ ] Badges on each folder show who is assigned
- [ ] A banner at the top of each team folder shows the read mode, who is assigned and whether notifications are on
- [ ] A coverage view lists every team folder with its owners, unread backlog and when someone last read it
- [ ] Folders nobody has opened lately are flagged

**Screenshots**

- [ ] The banner at the top of a team folder
- [ ] Assignee badges in the feed list
- [ ] The coverage view with one folder flagged

### 5. Notifications

- [ ] A manager sets notifications on a team folder and every teammate gets them
- [ ] A manager sets notifications on a single site in a team folder
- [ ] Choose who gets them: everyone, the assigned teammates, or named people
- [ ] Choose what triggers them: every new story, Focus stories only, or stories matching team training
- [ ] Choose whether teammates can turn them off
- [ ] Instant delivery to iPhone
- [ ] Instant delivery to Android
- [ ] Instant delivery by email
- [ ] Instant delivery to the browser, even when NewsBlur is not open
- [ ] A teammate's own setting and a team rule on the same site produce one notification, not two
- [ ] Rules set by a manager show "Set by your team" in the teammate's notifications dialog, with a lock if required
- [ ] A checkup grid of teammates and folders that shows whose notifications are working and whose are not
- [ ] Problems are spelled out: no device registered, notifications turned off on the phone, email bouncing, not seen in 90 days
- [ ] Send a test notification to one teammate or the whole team and see who received it

**Screenshots**

- [ ] A notification rule in the folder dialog
- [ ] The checkup grid with green, yellow and red cells
- [ ] A test notification arriving on a phone
- [ ] "Set by your team" in a member's notifications dialog

### 6. Slack, Microsoft Teams and webhooks

- [ ] Post new stories to a Slack channel
- [ ] Post new stories to a Microsoft Teams channel
- [ ] Send new stories to any webhook
- [ ] One post per story in a channel, however many teammates follow the folder
- [ ] Choose the channel per folder
- [ ] The same triggers as phone notifications: every story, Focus only, or team training

**Screenshots**

- [ ] The channels list in the team dialog
- [ ] A story posted in Slack
- [ ] A story posted in Microsoft Teams

### 7. Training

- [ ] Train a team folder once and every teammate gets the same Focus and hidden stories
- [ ] Teammates can add their own training on top
- [ ] Team training is marked as the team's in the trainer, and only managers can change it
- [ ] Notify the team only when a story matches team training

**Screenshots**

- [ ] The trainer on a team folder showing team training
- [ ] A story list where team training has put stories in Focus

### 8. The team dialog

- [ ] A team dialog with tabs for Members, Folders, Notifications, Activity, Billing and Security
- [ ] Built from the same pieces as the redesigned Preferences dialog: grouped rows, option cards with drawings, chips, a "Saved" pill, instant tooltips
- [ ] Every change is saved as it is made
- [ ] An activity log of who added, removed and changed what
- [ ] The team folder dialog: name and icon, who gets it, read mode, assignments, notifications
- [ ] Works in the Light, Dark, Warm and Gray themes
- [ ] A native team screen on iOS, in SwiftUI, in the app's four themes
- [ ] The same screen on macOS, laid out for a Mac window
- [ ] A native team screen on Android, in Compose, in light, sepia, dark and black

**Screenshots**

- [ ] Each tab of the team dialog
- [ ] The activity log
- [ ] The team dialog in each theme

### 9. Single sign-on and provisioning (Premium Team Enterprise)

- [ ] SAML 2.0 single sign-on, set up by the owner without a sales call
- [ ] OIDC single sign-on
- [ ] Works with Okta, Microsoft Entra ID, Google Workspace, OneLogin and other standard providers
- [ ] Sign in from the identity provider's app launcher
- [ ] Sign in from NewsBlur's login page with a work email
- [ ] Domain verification by DNS record
- [ ] Coworkers on a verified domain join the team automatically at first sign in
- [ ] Require single sign-on for everyone on the domain
- [ ] SCIM 2.0 provisioning creates, updates and deactivates teammates
- [ ] An existing account is linked only after its owner proves it is theirs
- [ ] Single sign-on in the iOS app
- [ ] Single sign-on in the Android app
- [ ] Deactivating a teammate signs them out of every device at once
- [ ] A removed teammate whose account existed before joining keeps it, and gets back in by confirming a personal email address and setting a password
- [ ] A removed teammate whose account was created by single sign-on is locked, and can ask for an export of their private feeds
- [ ] Session length limit for the team
- [ ] Everything marked Enterprise only in section 17 is refused on the $79 tier by the server, not only hidden

**Screenshots**

- [ ] The Security tab with a verified domain
- [ ] The SAML setup form
- [ ] The login page asking for a work email
- [ ] Single sign-on on a phone

### 10. Billing

- [ ] Stripe on the web
- [ ] PayPal on the web, offered under each team card the way it is for the other plans
- [ ] App Store subscriptions for both plans on iOS and macOS
- [ ] Google Play subscriptions for both plans on Android
- [ ] Whichever store sold the plan, the owner's paid period end is recorded so the team lapses on the right day
- [ ] A team bought in one place shows as the current plan everywhere, and cannot be bought a second time somewhere else
- [ ] The owner's account pays. Premium Team and Premium Team Enterprise are plans on the owner's own NewsBlur account, bought the same way as Premium Pro
- [ ] An owner who already pays for Premium, Archive or Pro is switched to the team plan with the difference prorated
- [ ] A teammate's own Stripe or PayPal renewal is cancelled when they join. App Store and Play subscribers get a notice with a link
- [ ] Two monthly prices, $79 and $129, and switching between them prorates
- [ ] Invoices and card changes through the Stripe customer portal
- [ ] If the owner cancels or a payment fails, the team goes inactive the day the paid period ends, with one email to every teammate. No grace
- [ ] A payment that succeeds later brings the team back at once
- [ ] Team folders and settings are kept when a team goes inactive, so it can come back
- [ ] Staff can raise a team's seat limit and set a custom price
- [ ] One email to a teammate who leaves or is removed, saying which plan their account is on now

**Screenshots**

- [ ] The Billing tab
- [ ] The team plans in the iOS premium screen
- [ ] The team plans in the Android premium screen

## Features, part 2: extensions

Where an idea comes from a competitor, the competitor is named.

### 11. Reading together

- [ ] Presence: "Maya is reading this folder now"
- [ ] Claim a story: "I've got this one", shown to the team
- [ ] Assign a single story to a teammate with a due date (Feedly)
- [ ] Story status for triage: new, in review, done, ignored
- [ ] Must read flag from a manager, with a count of who has acknowledged it
- [ ] Comments on stories, private to the team, with mentions (Inoreader, Feedly)
- [ ] Mention a teammate and it notifies them on their phone or in Slack (Feedly)
- [ ] Shared highlights and notes on a story (Inoreader, Feeder)
- [ ] Team saved stories with shared tags, as a board the whole team adds to (Feedly, Inoreader)
- [ ] Reactions on stories
- [ ] "While you were out": what the team read and flagged while you were away
- [ ] Hand a story to a teammate from the share menu
- [ ] Team blurblog: one shared stream of everything the team has shared

**Screenshots**

- [ ] Presence and a claimed story in a story list
- [ ] A comment thread with a mention
- [ ] A must read story and its acknowledgment count
- [ ] The team board of saved stories
- [ ] "While you were out"

### 12. Coverage and schedules

- [ ] Timetables: who is on duty for a folder by day and hour
- [ ] Notifications that only go to whoever is on duty
- [ ] Handoff note at the end of a shift
- [ ] Vacation mode that reassigns a teammate's folders
- [ ] Rotating assignment across teammates
- [ ] Escalation: if nobody opens an alert in 15 minutes, notify the manager
- [ ] Time to first read per folder, as a number the manager can track
- [ ] Weekly coverage report by email: what came in, what got read, by whom
- [ ] Alert when a folder goes unread for a set number of days

**Screenshots**

- [ ] The timetable for a folder
- [ ] A handoff note
- [ ] The weekly coverage report email

### 13. Alerts and delivery

- [ ] Keyword alerts across every team feed at once
- [ ] Spike alerts when a keyword suddenly shows up in many stories (Brand24)
- [ ] Duplicate stories clustered into one alert
- [ ] Broken feed alerts, so a dead feed is not mistaken for a slow news week
- [ ] Quiet hours per teammate and per team
- [ ] Batched alerts: one notification every 15 minutes or every hour
- [ ] Slack app with buttons: mark read, claim, save, open in NewsBlur
- [ ] Discord (Feeder)
- [ ] Telegram (Feeder)
- [ ] Google Chat (Visualping)
- [ ] PagerDuty and Opsgenie for critical keywords
- [ ] Signed webhooks with retries and a delivery log
- [ ] Different channels per folder or per client (Syften)
- [ ] Alert rules on a schedule, such as business hours only
- [ ] Email alerts to a distribution list that is not a teammate

**Screenshots**

- [ ] A keyword alert rule
- [ ] A spike alert
- [ ] A broken feed alert
- [ ] The Slack message with buttons
- [ ] The webhook delivery log

### 14. Digests and reports

- [ ] Scheduled email digest of a team folder to people who do not have a seat (Feedly, Inoreader, Muck Rack)
- [ ] Digest builder with the team's logo and a chosen layout (Inoreader)
- [ ] Open and click stats per digest recipient (Feedly)
- [ ] AI written daily team briefing across team folders
- [ ] Weekly report as PDF or spreadsheet (Brand24, Awario)
- [ ] White label branding, on Premium Team Enterprise only: reports, digests, public pages and widgets carry the team's name and logo and none of NewsBlur's (Awario)
- [ ] RSS and JSON output feed for every team folder (Inoreader)
- [ ] Public read only page for a team folder
- [ ] Embeddable widget of a team folder for an intranet

**Screenshots**

- [ ] The digest builder
- [ ] A digest email
- [ ] Digest open and click stats
- [ ] A public team folder page

### 15. Sources

- [ ] A team library of the sites in team folders plus sites teammates choose to submit, with one click to add one to a team folder. A teammate's private feeds never appear in it (Feeder)
- [ ] Members suggest a site and a manager approves it
- [ ] A team newsletter address, so email newsletters land in a team folder
- [ ] Shared Web Feeds for sites without RSS
- [ ] Page change tracking for pages that are not feeds (Visualping, Inoreader)
- [ ] Import a list of Google Alerts as feeds
- [ ] Import and export a team folder as OPML
- [ ] Starter folders by field: security advisories, regulators, tech press
- [ ] Suggested sites for a team folder based on what is already in it
- [ ] Reddit, YouTube and podcast sources in team folders
- [ ] Podcast and video transcripts searchable by the team (Inoreader)

**Screenshots**

- [ ] The team library
- [ ] A site suggestion waiting for approval
- [ ] Starter folders

### 16. Search and AI

- [ ] Shared AI prompt filters on a team folder
- [ ] Ask AI across a team folder: "what happened with our competitors this week"
- [ ] Shared saved searches
- [ ] One search across everything the team has ever received
- [ ] Company and person tracking: follow a name across all team feeds (Feedly, Inoreader)
- [ ] Translate stories for the team (Inoreader, Feedly)
- [ ] Pooled AI usage with a breakdown per teammate (Inoreader)
- [ ] Pooled Listen hours with a breakdown per teammate
- [ ] Bring your own AI key (Inoreader)

**Screenshots**

- [ ] Ask AI answering a question about a team folder
- [ ] Team search results
- [ ] The pooled usage breakdown

### 17. Admin and security

- [ ] More roles: folder editor, billing only, read only viewer (Feedly)
- [ ] Free viewer seats that can read team folders and receive digests but not change anything
- [ ] Groups of teammates, used to share folders
- [ ] Groups synced from the identity provider (Premium Team Enterprise only)
- [ ] Client workspaces inside one team: a named set of folders, channels and teammates per client (Syften, Meltwater)
- [ ] Sign in with Google or Microsoft for the $79 tier
- [ ] Two factor sign in required for teams without SSO
- [ ] Audit log export as CSV (Premium Team Enterprise only)
- [ ] Audit log streaming to a SIEM (Premium Team Enterprise only)
- [ ] Sign in history per teammate (Premium Team Enterprise only)
- [ ] IP allow list (Premium Team Enterprise only)
- [ ] Data retention setting for the team (Premium Team Enterprise only)
- [ ] Full team export (Premium Team Enterprise only)
- [ ] Usage dashboard: active teammates, most read sites, sites nobody reads (Inoreader)
- [ ] Preselect folders at invite time (Feedly)

**Screenshots**

- [ ] The usage dashboard
- [ ] A client workspace
- [ ] The audit log export

### 18. More billing

- [ ] Pay by invoice or purchase order
- [ ] Tax IDs on invoices
- [ ] Self serve seat packs above 10

**Screenshots**

- [ ] An invoice with a tax ID

### 19. Integrations

- [ ] Team MCP server and CLI, so an AI agent can read and triage the team's folders
- [ ] Team API keys that are not tied to a person (Sparkfeed)
- [ ] Zapier, IFTTT and n8n triggers for team folders (Inoreader)
- [ ] Create a Jira, Linear, Asana or Trello ticket from a story
- [ ] Send a story to Notion or a Google Sheet
- [ ] Push a story to Salesforce or HubSpot (Klue, Crayon)
- [ ] A proper Microsoft Teams app, since Microsoft retired its RSS connector in May 2026
- [ ] Calendar feed of the on duty schedule

**Screenshots**

- [ ] An AI agent triaging a team folder through MCP
- [ ] A ticket created from a story

### 20. Apps

- [ ] Team badges, banners and "Read by" in the iOS app
- [ ] Team badges, banners and "Read by" in the Android app
- [ ] The team dialog and folder dialog in the iOS app
- [ ] The team dialog and folder dialog in the Android app
- [ ] Home screen widget for a team folder
- [ ] Team folders in the Mac app's menu bar

**Screenshots**

- [ ] A team folder on iPhone
- [ ] A team folder on Android
- [ ] The widget

### 21. Self hosted

- [ ] A team license for self hosted NewsBlur with the team features unlocked

## The feature page

A page for Premium Team that the welcome page (`templates/reader/welcome.xhtml`) links to and previews.

- [ ] A Premium Team section on the welcome page with the pitch and a link to the full page
- [ ] The full feature page, one section per numbered section above
- [ ] Every feature listed under its section
- [ ] One to several screenshots per section, taken from the Screenshots lists
- [ ] The two prices and what separates them
- [ ] A "Start a team" button that signs up or logs in, then opens the team checkout
- [ ] Reads well on a phone
- [ ] All text goes through the localization API

## Groundwork

Things that are not team features but that the team features need.

- [x] Android push through Firebase Cloud Messaging. Shipped in PR #2235 on 2026-11-26. Play builds only; F-Droid keeps polling
- [ ] Web Push, so browser notifications arrive when NewsBlur is not open. Today `send_web` only publishes to an open tab
- [ ] Notification frequency is honored. `NotificationFrequency` is stored today but nothing reads it
- [ ] A notification budget for team rules. Email is capped at 20 a day per user (`MAX_EMAILS_SENT_PER_DAY_PER_USER`) and at most 3 stories are sent per fetch per user
- [ ] Each device reports whether notifications are allowed in system settings
- [ ] Each device acknowledges a test notification
- [ ] Slack, Microsoft Teams and webhook output. IFTTT is the only outbound integration today
- [ ] The Preferences dialog's builders (`make_group`, `make_row`, `make_cards`, `make_chips`, the status pill) move to a shared mixin in `media/js/newsblur/common/` that both dialogs extend
- [ ] The team dialog carries the Preferences dialog's class as well as its own, so it gets the row, card and chip styles in all four themes without edits to the hand maintained Warm and Gray stylesheets
- [ ] The team dialog saves one change per control through the team endpoints. It reuses the "Saved" pill but not the Preferences form diff

## How it works

### Teams and roles

| Role | Can do |
|---|---|
| Owner | Everything, plus billing, single sign-on, deleting the team, transferring ownership. One per team |
| Manager | Create and edit team folders, assign teammates, set notifications, invite and remove members |
| Member | Read team folders, add their own training on top of the team's, keep their own private feeds |

A person joins with a NewsBlur account. If they already have one, they keep it. The team never sees their private feeds, folders, saved stories or reading.

### Team folders

- Team folders live under one top level folder named after the team. Inside it, managers build whatever tree they want.
- A manager's changes reach every teammate's open app within seconds.
- Each folder is shared with everyone or with a chosen set of teammates.
- Members cannot rename, move or delete team folders. They can collapse them, change their own view settings and train on top.

### Read status

| Mode | Whose unread counts | What teammates see |
|---|---|---|
| Personal | Each teammate's own | Nothing |
| Read receipts | Each teammate's own | Who has read each story |
| Shared | One for the whole team | Who read it first, and when |

Focus counts can still differ between teammates in shared mode, because each person's own training is layered on top.

### Icons, banners and overlays

It has to be obvious at a glance what is shared.

- **Feed list.** The team's top level folder shows the team name and member count. Each team folder has a team badge. Shared folders get a second badge. Hovering a folder shows who is assigned.
- **Story list header.** A banner on every team folder: "Team folder. Shared read status. Assigned to Maya and Dev. Notifications on for 6 of 6." Managers get a link to the folder dialog.
- **Story rows.** In shared and read receipt folders, a small pill: "Read by Maya" or "3 of 6 read".
- **Story detail.** A "Read by" line with names and times.
- **Notifications dialog.** Rules set by a manager show "Set by your team", with a lock if they cannot be turned off.

### Dialogs

All of them are built from the redesigned Preferences dialog's pieces (`media/js/newsblur/reader/reader_preferences.js`): tabs across the top, titled groups of rows, a name and a line of explanation on the left of each row and its control on the right, option cards with small drawings, chips for lists, a "Saved" pill, and no Done button.

1. **Team dialog.** Tabs: Members, Folders, Notifications, Activity, Billing, Security.
2. **Team folder dialog.** Name and icon, who gets it, read mode, assignments, notifications.
3. **Notification checkup.** The grid described below.
4. **Join screen.** What joining means, what the team can and cannot see.
5. **Upgrade dialog.** The "For teams" row.

### Notifications

A manager creates a rule on a team folder or a single site:

- **What:** every new story, Focus stories, or stories matching team training
- **Where:** each teammate's phone, email and browser, plus a Slack channel, a Teams channel or a webhook
- **Who:** everyone with the folder, the assigned teammates, or named people
- **Control:** teammates can turn it off, or it is required

The checkup grid has a row per teammate and a column per folder. Each cell is green, yellow or red:

- Green: the rule applies and at least one device has received a notification recently
- Yellow: the rule applies but nothing has been delivered yet
- Red, with the reason: no device registered, notifications turned off in the phone's settings, email unverified or bouncing, teammate not seen in 90 days

### Single sign-on and provisioning

- The owner verifies a domain with a DNS TXT record, then pastes identity provider metadata (SAML) or a client ID and secret (OIDC).
- Sign in works from the provider's app launcher and from NewsBlur's login page.
- First sign in creates the account and joins it to the team.
- "Require SSO" turns off password login for accounts on the domain.
- SCIM creates, updates and deactivates teammates. Deactivation removes the seat, removes team folders, drops the account to its own plan and deletes every session.
- The mobile apps sign in through the system browser and return to the app.

## How it fits the code

There is no team, organization or seat concept in the repo today. The nearest things are gift codes (`MGiftCode` in `apps/profile/models.py`) and the lifetime Pro grants in `apps/oauth/reader_grants.py`.

### New app: `apps/team`

All new tables, which the migration rules treat as always safe. Nothing is added to `profile_profile`, `auth_user` or `reader_usersubscription`.

- [x] `Team`: name, slug, owner (one team per owner), plan (`team` or `team_enterprise`), seat_limit, status
- [x] `TeamMember`: team, user, role, status (active, removed). One active membership per user across all teams
- [x] `TeamInvite`: team, email, token, role, expiry
- [ ] `TeamFolder`: team, parent, title, position, read_mode, audience (everyone or chosen members)
- [ ] `TeamFeed`: team_folder, feed, position, added_by
- [ ] `TeamFolderMember`: team_folder, user, kind (audience or assigned)
- [ ] `TeamNotificationRule`: team_folder or feed, trigger, channels, audience, required
- [ ] `TeamChannel`: team, kind (slack, teams, webhook), URL or credentials
- [ ] Every channel and webhook URL is checked with `validate_public_url` when it is saved and again when it is sent, and is posted with a short timeout, so a manager cannot point task servers at an internal address or hang a worker
- [ ] Channel URLs and the OIDC client secret are credentials: stored encrypted, never logged, and never returned whole by an endpoint
- [ ] `TeamDomain`: team, domain, verification token, verified_at, require_sso
- [ ] `TeamSSOConfig`: team, protocol, provider metadata, SCIM token hash
- [x] `TeamActivity`: team, actor, action, target, timestamp
- [x] The team is anchored on its owner. One helper answers "whose account does this teammate's team usage fall under" and returns the owner's user id

Everything in NewsBlur is keyed by user id (subscriptions, read state, classifiers, notifications, usage). The team reuses that machinery through its owner's user id, the account that pays. There are no hidden accounts.

What that means in practice:

- The owner's read state in a shared folder is the team's read state.
- Team training is folder training on a team folder. It is kept separate from the owner's own training on a site, so what the owner trained privately before a site joined a team folder stays private.
- Listen, Ask AI and AI filter usage by any teammate is counted against the owner's account, with the teammate recorded for the breakdown.
- Slack, Teams and webhook posts are scored only with the team folder's training, never with the owner's own training on a site.
- The owner sees team folders the same way every teammate does, under the team's top level folder, and keeps private folders beside it.

### Team folders: merge at read time, real subscriptions underneath

The collision: a user's folders are one JSON blob (`UserSubscriptionFolders` in `apps/reader/models.py`), a folder is identified by its title, and a subscription belongs to exactly one user (`unique_together = ("user", "feed")` on `UserSubscription`).

- [ ] Each teammate gets a real `UserSubscription` for every team feed, so unread counts, read state, training, mutes, notifications and fetch priority keep working unchanged
- [ ] Team folders are not written into anyone's blob. `load_feeds` and `load_feeds_flat` (`apps/reader/views.py`) merge them in as one extra top level folder, so web, iOS and Android render them as ordinary folders
- [ ] One function resolves a user's folders with their team folders merged in, and every server path that maps a folder to its sites uses it, not only `load_feeds`: `flatten_folders` callers, river of a folder, mark a folder read, folder RSS, `load_folder_feed_ids` in `apps/analyzer/models.py`, and `calculate_feed_scores`
- [ ] A `team_folders` key in the same response maps each team folder path to its id, read mode, assignees and whether this user can edit. Old clients ignore it
- [ ] Every endpoint that edits folders rejects or reroutes team paths: add, delete, rename and move for feeds and folders
- [ ] Managers' edits go to the team models and publish `reload:feeds` to every teammate's channel, which all three clients already handle
- [ ] `save_feed_order` writes the whole blob back from the client, so it strips the team folder before saving
- [ ] Leaving a team removes the overlay and deletes the subscriptions for team feeds that are not also in the personal blob
- [ ] A rename fans out to each teammate through `_update_classifiers_for_folder_path_change`, so folder icons, auto mark read, collapsed state, folder scoped training, classifier notifications and briefing sources follow
- [ ] Subscriptions created for team feeds skip `add_subscription`'s write to the blob and stay active regardless of the member's personal site limit

### Shared read status: fan out on write

Read state is keyed by user id everywhere: the Redis `RS:{user}` sets, `mark_read_date` on the subscription, and every reader of them (`calculate_feed_scores`, clustering, `trim_user_read_stories`). A team read set that all of those readers merge would touch the hottest paths in the codebase. Applying each read to every teammate changes nothing on the read side, and with 10 seats it is nine small writes.

- [ ] Hooks on `mark_story_hashes_read`, `mark_feed_read` and mark unread (`apps/reader/models.py`), with a flag so a fanned out write does not fan out again
- [ ] The hook decides by site, not by folder: a read fans out when the site is in any team folder the reader has whose mode is shared, and writes a receipt when any is shared or read receipts
- [ ] A Celery task applies the read to each other teammate and publishes `story:read:<hash>` on their channel. The web client, iOS (`RealtimeUpdates.swift`) and Android (`RealtimeMessage.kt`) already apply that message
- [ ] The owner's read state is the team's canonical read state, which a late joiner copies
- [ ] Read receipts are a Redis hash per story, user id to timestamp, with a TTL
- [ ] Receipts are returned inside the story payload for team feeds, not through a new endpoint
- [ ] Each fan out records what it changed, so it can be undone

### Premium Pro for teammates

The tier flags on `Profile` (`is_premium`, `is_archive`, `is_pro`) are read in more than 120 places, including database joins that set feed fetch priority (`Feed.count_subscribers` in `apps/rss_feeds/models.py`) and the profile the iOS and Android apps parse. An effective tier computed on the side cannot reach all of those, so a teammate carries the real Pro flags and a new table remembers what they had on their own.

Two things the first draft of this plan got wrong, found by reading the code:

- `setup_premium_history` cannot bring someone back down to their own plan. It only ever raises a tier, and tiers bought in the App Store, on Play or by gift exist only as the activation call made at the time. So the grant keeps a snapshot of the person's own tier and restores it.
- `deactivate_premium` mutes every site, not only the ones over the free limit. The person then picks their 64 in the feed chooser. The email sent when a seat ends has to say that.

The grant:

- [x] `TeamProGrant` in `apps/team`: one row per person holding team Pro, with their own tier at the moment they joined (free, trial, premium, archive, archive extra, pro), their own trial end if they were on a trial, and when the grant began
- [x] `grant_team_pro` sets the Pro flags on the teammate's `Profile` without calling `activate_pro`, so no welcome email, staff email or payment row is produced
- [x] The grant never writes `premium_expire`. That stays the teammate's own paid through date
- [x] On a new grant: the teammate's muted sites are reactivated up to what the team has room for, feeds are scheduled at Pro speed, and the archive backfill starts if they were not already on Archive
- [x] `release_team_pro` restores exactly the snapshotted tier if it is still paid for, restores a trial that is still running, and otherwise calls `deactivate_premium`
- [x] One row per person, removed when the seat ends, so team Pro is never snapshotted as someone's own tier

Guards on the existing premium code (`apps/profile/models.py` and `apps/profile/tasks.py`):

- [x] The `PremiumExpire` task skips anyone holding a grant and the owner of an active team
- [x] `deactivate_premium` on a grant holder lowers their snapshot to free and returns, so a store expiry cannot strip team Pro
- [x] `activate_premium`, `activate_archive` and `activate_pro` on a grant holder raise the snapshot and return. That one guard covers store receipts, gift redemption, Stripe webhooks and referral credit
- [x] The App Store renewal handler (`apps/profile/apple_subscriptions.py`) ranks a teammate by their own tier, so their renewal is not dropped as a cross tier purchase
- [x] Referral credit (`MReferral.award_credit`) is computed from the person's own tier
- [x] `can_register_oauth_application` accepts a grant

A seat's life:

- [x] none to active: an invite is accepted on an active team
- [x] active to ended: the teammate leaves or is removed, or the team lapses. Team Pro ends at once in every case, with one email
- [x] No grace state, no reminder emails and no dates to track. The grant row exists exactly as long as the seat is active on an active team
- [x] A teammate whose own plan ran out while they were on the team drops to free when the seat ends

A team's life:

- [x] `Team.paid_through` holds the end of the owner's paid period. The lapse cannot use `premium_expire`, which counts every payment as a year
- [x] `activate_team` and `deactivate_team` are the two functions billing calls. Deactivating releases every teammate's grant at once and sends one email to everyone. Activating grants again with fresh snapshots
- [x] The hourly task only lapses teams and repairs overwritten flags. It no longer ends grace or sends reminders
- [x] The same beat task lapses a team whose `paid_through` has passed
- [x] If the owner's account is deleted, the team goes inactive and its teammates are released

A new teammate's own subscription:

- [x] On join, a Celery task calls `cancel_premium_stripe` and `cancel_premium_paypal`. Both stop renewal at the end of the paid period, with no refund, and leave the separate AI filter billing subscription alone
- [x] App Store and Play subscribers are found from their recent payment rows, shown a note on the join screen, and sent one email with the links to cancel
- [x] A lapsed team that comes back does not cancel anything again. Cancelling happens only on join

Shared allowances. The scope is the owner plus each teammate for the period they were on the team. Usage rows keep the teammate's own user id, which is the per teammate breakdown, so no field is added to any Mongo document.

- [x] Sites: one check in `apps/team/sites.py`, with the team row locked, wherever a site becomes active: adding a site, OPML import, batch subscribe, the feed chooser, unmute and `auto_activate`. A site any teammate already follows costs nothing
- [x] The count is distinct active sites across the team, exact when enforcing and cached for five minutes when displayed
- [x] Someone whose private feeds push the team past 10,000 can still join. Their sites beyond what fits are muted, newest first, and they choose which to keep in the feed chooser
- [x] Listen: the 10 hours a week are counted across the scope (`apps/listen/usage.py`), and the message at the cap names the team and its owner
- [x] Ask AI and transcription: counted across the scope (`apps/ask_ai/usage.py`)
- [x] Archive Assistant's 100 a day: counted across the scope (`apps/archive_assistant/models.py`)
- [x] AI filters are pay per use, not an allowance. A teammate can use them once the owner has turned usage billing on, and the charge goes to the owner's Stripe customer against the owner's spending limit, with the teammate recorded on each cost row
- [x] Only the owner can turn usage billing on for the team
- [x] When the team hits a shared limit, the teammate who hit it is told it is the team's limit and who to ask

Counting:

- [x] Paid subscriber counts and gauges (`apps/monitor/views/newsblur_users.py`, `apps/statistics/models.py`) leave grant holders out, and a new gauge counts team seats
- [x] Feed fetch priority follows the flags, so team sites are fetched at Pro speed

This is the riskiest integration in the plan. That code handles Stripe, PayPal, App Store and Play history and has a lot of special cases.

### Team training: fan out on write

The apps and the web client score stories themselves from the classifiers the server sends them, and the server scores unread counts from the same per user classifiers. Merging a second user's classifiers in at score time would touch every one of those paths. Copying team training to each teammate touches none of them, the same reasoning as read status.

- [ ] Team training is stored as folder scoped classifiers on the team folder's path, the scope Premium Archive already has (`scope` and `folder_name` on the classifiers in `apps/analyzer/models.py`). No new fields
- [ ] A manager's change to team training is written to the owner's classifiers and copied to every teammate who has the folder
- [ ] A teammate who joins or is given the folder later gets a copy of the team's training
- [ ] Members cannot change classifiers scoped to a team folder. Their own training on a site stays feed scoped and personal
- [ ] The owner's feed scoped training on a site is personal like anyone else's, including training from before the site joined a team folder
- [ ] Server side scoring finds team folders through the shared folder resolver, so team training changes unread counts and notifications as well as what the clients show

### Notifications

- [ ] Team rules become ordinary `MUserFeedNotification` rows, one per teammate and feed, tagged with the rule that created them
- [ ] A teammate's previous setting is kept and restored when the rule is removed
- [ ] New fields on that Mongo document are added in one deploy and written in the next
- [ ] Channel posts run once per story from the feed fetcher hook that calls `push_feed_notifications`, scored only with the team folder's classifiers

### Single sign-on and SCIM

- [ ] Today's login is username and password, plus native Apple and Google sign in (`apps/api/social_auth.py`), whose rule is that provider identities never link on email alone. SSO keeps the rule
- [ ] Linked identities are stored like `SocialIdentity`, whose `provider` column is only 16 characters, so either a wider value or a separate table
- [ ] Sessions last 10 years (`SESSION_COOKIE_AGE`) and the mobile apps authenticate with that cookie. SSO teams get a session length limit
- [ ] Deactivation deletes the user's sessions from Redis
- [ ] The apps sign in through the system browser and come back with a one time code, modelled on the native flow in `social_auth.py`
- [ ] Choose libraries after checking each is maintained. Candidates: `python3-saml` (needs xmlsec in the Docker image), Authlib for OIDC, `django-scim2` for SCIM

### Billing

The owner's account pays, so a team plan is one more plan on a `Profile`, next to Premium, Archive and Pro. The existing code already buys, switches, renews and expires plans for a `Profile` through Stripe, PayPal, the App Store and Google Play. Findings from reading it that shape this step:

- A team is started only from a payment confirmed with the provider's own API or a signed receipt, never from a notification's contents alone.
- `premium_expire` counts one payment as a year (`billing_period_days` in `apps/profile/models.py`). The $79 and $129 payments have to count as a month, or an owner who paid once would keep Pro for a year.
- Stripe charges a renewal about an hour after the period ends, and PayPal later than that. A team that lapsed at the exact end of its period would tell everyone the plan had ended and then come straight back. So the hourly task lapses a team one day after `paid_through`.
- Nothing listens for Stripe's subscription deleted event today.
- Switching a monthly plan on PayPal prorates over the real paid period.
- Team products on iOS are bought with StoreKit 2, and the signed transaction is verified on the server.
- `setup_premium_history` picks the first listed Stripe subscription without skipping the AI filter usage subscription, which would hide a team subscription once the owner turns usage billing on.

One function for all four providers:

- [x] `record_team_payment(user, plan, provider, paid_through, reference)` in `apps/team/billing.py`, called only on a confirmed payment. It creates or finds the owner's team, sets its plan and provider, moves `paid_through` forward, reactivates the team if it had lapsed, and sets the owner's Pro flags
- [x] Payment notices from Stripe and PayPal are verified before they are acted on, for every plan. This needs each provider's signing secret in settings
- [ ] App Store and Play purchases are verified with the store before any plan starts, for every plan
- [x] It does not go through `activate_pro`, which would send the Pro welcome email and call back into the payment sync. The owner gets a team welcome email, and staff get the usual upgrade email with the team plan named
- [x] Someone who holds team Pro from another person's team and buys a team plan gets no second team. Their purchase is flagged to staff
- [x] New columns on `Team`: the billing provider and its reference, the pending owner and when the transfer was requested, and when the name was confirmed
- [x] `Profile.canonical` and the web globals carry the team plan, the person's role, the billing provider, the paid through date and any pending transfer, so every client can show the current plan. Today the clients read only the tier flags, where an owner and a teammate both look like Pro
- [x] The Stripe products and prices exist in test and live mode, created 2026-11-26, monthly, in USD:

  | Plan | Lookup key | Live price | Test price |
  |---|---|---|---|
  | Premium Team, $79 | `newsblur-premium-team-79` | `price_0UgCfDwdsmP8XBlaft9XCHfp` | `price_0UgCfCwdsmP8XBlakBsOX3AZ` |
  | Premium Team Enterprise, $129 | `newsblur-premium-team-enterprise-129` | `price_0UgCfDwdsmP8XBlaqkniOnJy` | `price_0UgCfDwdsmP8XBlakzTInxlu` |

Stripe:

- [x] `team` and `team_enterprise` in `plan_to_stripe_price`
- [x] The Stripe loop in `setup_premium_history` skips the usage billing subscription and hands a team subscription's status and period end to `record_team_payment`
- [x] `stripe_signup` and `stripe_subscription_updated` know the team plans
- [x] The subscription deleted event and the invoice paid event are connected
- [x] `stripe_checkout` refuses a team purchase from a teammate who is not the owner, and when a store already bills the team

PayPal:

- [x] The PayPal plans exist in live and sandbox, created 2026-11-27, monthly, in USD, on the product the Premium and Archive plans use:

  | Plan | Live plan | Sandbox plan |
  |---|---|---|
  | Premium Team, $79 | `P-8S7370738J488325JNMEUTOI` | `P-26G78309H2256220LNMEUTOA` |
  | Premium Team Enterprise, $129 | `P-82711566SE765874KNMEUTOI` | `P-4PW05904U2821301YNMEUTOI` |

- [x] Both plans in `plan_to_paypal_plan_id`. The web client gets a team plan id from the server (`/team/paypal_plan`) only when the account may buy one
- [x] `paid_through` comes from the subscription's next billing time, only while it is active with no failed payments
- [x] Proration uses the real paid period, not 365 days

App Store (iOS and macOS, one bundle id, one set of products):

- [ ] Products `newsblur_premium_team` and `newsblur_premium_team_enterprise` in the existing subscription group, above Pro, at $79.99 and $129.99 a month, with names and descriptions in the 21 languages the other products have
- [x] Both in `APPLE_PRODUCTS` (`apps/profile/apple_subscriptions.py`) at their own rank, with the newest purchase deciding which of the two the owner has
- [x] A team owner's rank is the team rank, so their renewals are not dropped as a cross tier purchase
- [x] Team purchases call `record_team_payment` with Apple's signed expiry date
- [ ] The app buys team products with StoreKit 2 and posts the signed transaction, which the server verifies
- [x] Refund and revoke notices for team products end the team

Google Play:

- [ ] Products `nb.premium.team.79` and `nb.premium.team.enterprise.129`, each with one monthly base plan, with a title, description and benefits in the 21 languages the other products have
- [x] The server maps them, checking the enterprise id first since one id contains the other
- [ ] The app sends the purchase token, and the server verifies a team purchase with Google before starting a team
- [x] Real time notifications pass Google's expiry time to `record_team_payment`
- [x] An expiry notice for a token that was replaced by an upgrade does not end the team

Lapse and return:

- [x] Only a confirmed payment moves `paid_through`. Past due, on hold, suspended and failed renewal notices change nothing
- [x] The hourly task lapses a team one day after `paid_through`
- [x] On the web, a payment that recovers (Stripe charge succeeded, PayPal sale completed) brings the team back through `record_team_payment`
- [x] In the stores, a payment that recovers (Apple recovered, Play recovered or restarted) brings the team back the same way
- [x] A refund or revoke ends the team at once
- [x] After a lapse the owner's own account goes through the normal `PremiumExpire` window

Switching:

- [x] Premium, Archive or Pro up to a team plan, and Team up to Enterprise, take effect at once with proration where the provider has it
- [x] Switching down from a team plan on the web keeps the team until the paid month ends, then starts the lower plan. Stripe does this with a subscription schedule and PayPal with a subscription that starts on that date
- [x] In the stores, an upgrade is immediate and a downgrade takes effect at renewal, which is how each store already works
- [x] Cancelling outright runs to the end of the paid month, and the team row is kept

Ownership transfer:

- [x] `transfer_ownership` is a request, not a swap. It records the pending owner, and the request runs out after 7 days. The owner can cancel it and the pending owner can decline it, and it ends if the pending owner leaves the team
- [x] The pending owner accepts by buying a team plan on any platform. `record_team_payment` then completes the transfer in one transaction: roles swap, the team's plan, provider, reference and paid period become the new owner's payment's, and the team never lapses in between
- [x] Only the pending owner of a team may buy a team plan while holding a seat on it, on all four providers
- [x] Nobody's grant is released and nobody's flags change at the handover. The new owner's grant becomes an owner's, with the end of their own plan recorded. The old owner's becomes a teammate's, remembering the plan they have on their own, never the team's
- [x] A team plan's payments count toward the expiry of the account that owns the team and nobody else's, so the old owner's team payments do not become a plan of their own
- [x] The old owner's Stripe or PayPal subscription is stopped and the unused part of the month refunded, prorated over the real period. A refund that fails leaves the transfer standing and staff are emailed. A store subscriber gets an email with the link to cancel, and staff are emailed once
- [x] The old owner's later payment notices do nothing to the team
- [x] A comped team is handed over on acceptance with nothing to pay, and stays comped
- [x] The shared allowances, AI filter billing and the nightly expiry exemption follow the new owner

Staff and the contact form:

- [ ] The staff User Admin dialog (`media/js/newsblur/reader/reader_admin.js`) gets a team block: seat limit, plan, comp a team with no payment and no lapse date, and end a comp
- [ ] A full staff refund for an owner ends the team now
- [ ] "More than 10 teammates? Get in touch" posts to a login required view that emails staff through the existing staff notification task

The web dialog:

- [ ] The two team cards get their own buttons, since they sit beside the plan ladder and a Pro reader can also start a team
- [ ] A team billed through a store shows "Billed through the App Store" or "Billed through Google Play" with no button
- [x] The page after checkout waits for the team to exist, then opens the team dialog asking for its name

### Rules from CLAUDE.md that apply to every step

- New tables only, so migrations stay backward compatible. Anything that later touches a hot table starts with a `lock_timeout`.
- New Mongo fields are added in one deploy and written in the next.
- Code that runs inside Celery needs `make celery` as well as `make deploy`.
- All new interface text goes through the localization API.
- Web screens are checked in Light, Dark, Warm and Gray. The Warm and Gray stylesheets are edited by hand, with targeted edits only.
- Android screens are checked in light, dark and black, with colors centralized for Sapia.
- New iOS files are Swift.

## Build order

One step at a time, one agent at a time, each ending in passing tests and a commit. A step with screens is built on the server, then the web, then iOS and macOS, then Android, and is finished on all of them before the next step starts. The web version goes on localhost first so it can be looked at before the apps copy it.

Core:

- [x] 1. `apps/team`: teams, members, roles, invites, join links, seat limit, activity log
- [x] 2. Premium Pro for teammates, shared allowances counted against the owner, and the fall back to a person's own plan the moment a seat ends
- [ ] 3. Billing: the two team plans on the owner's account through Stripe, PayPal, the App Store and Google Play, plan switches, lapses, staff controls
- [ ] 4. Shared dialog pieces from Preferences, the team dialog with Members and Billing tabs, the join screen, the upgrade dialog row and callouts (web, iOS, Android)
- [ ] 5. Team folders on the server: models, real subscriptions, merged folder list, edit guards, rename fan out, leaving
- [ ] 6. Team folders on screen: badges, manager editing, Folders tab, team folder dialog (web, iOS, Android)
- [ ] 7. Read status on the server: modes, fan out, receipts, late joiners, undo
- [ ] 8. Read status on screen: banner, pills, "Read by", mode cards, mark all as read confirmation (web, iOS, Android)
- [ ] 9. Assignments and the coverage view (web, iOS, Android)
- [ ] 10. Web Push and the other notification groundwork
- [ ] 11. Team notification rules, the checkup grid, test notifications (web, iOS, Android)
- [ ] 12. Slack, Microsoft Teams and webhook channels
- [ ] 13. Team training and notifications on team training (web, iOS, Android)
- [ ] 14. Single sign-on: domains, SAML, OIDC, account linking, require SSO, sessions
- [ ] 15. SCIM provisioning
- [ ] 16. The Security tab and the SSO login flow (web, iOS, Android)

Extensions, in the order of the sections above, each on all three platforms where it has a screen:

- [ ] 17. Reading together (section 11)
- [ ] 18. Coverage and schedules (section 12)
- [ ] 19. Alerts and delivery (section 13)
- [ ] 20. Digests and reports (section 14)
- [ ] 21. Sources (section 15)
- [ ] 22. Search and AI (section 16)
- [ ] 23. Admin and security (section 17)
- [ ] 24. More billing (section 18)
- [ ] 25. Integrations (section 19)
- [ ] 26. Self hosted (section 21)

Launch:

- [ ] 27. The home screen widget and the Mac menu bar (section 20)
- [ ] 28. Translations for every new string
- [ ] 29. Screenshots for every section
- [ ] 30. The feature page and the welcome page section
- [ ] 31. Blog post

## Tests: ways this can fail

Written before any code. Each one is a test.

**Folders**

- [ ] A client saves feed order and the team folder gets written into the personal blob
- [ ] A teammate has a private folder with the same name as the team
- [ ] A teammate already follows a team feed privately, then leaves the team, and loses the feed
- [ ] A teammate already follows a team feed privately and has it muted
- [ ] A manager renames a team folder and a teammate's folder scoped training stops applying
- [ ] The owner's private training on a site starts applying to every teammate when the site joins a team folder
- [ ] A member changes team training through the existing classifier endpoint
- [ ] Team training shows in the apps but the server's unread counts ignore it
- [ ] A team folder opens in the feed list but its river, mark as read or RSS feed cannot find it
- [ ] A member calls the rename or delete endpoint directly on a team folder
- [ ] A team feed pushes a member over their personal site limit and gets muted
- [ ] A folder is shared with some teammates and another teammate can still load its stories

**Read status**

- [ ] A fanned out read fans out again and loops
- [ ] Mark all as read in a shared folder from an old app version clears the team with no way back
- [ ] Two teammates mark and unmark the same story at the same moment
- [ ] A teammate joins a shared folder and sees thousands of unread stories the team already cleared
- [ ] A read on a site that is in no team folder shows up in someone's read receipts
- [ ] A read in the private copy of a site that is also in a shared team folder is not shared
- [ ] A manager adds a site a member follows privately and the member's private copy shows no team badge
- [ ] Reads from before a site became a team site show up in receipts
- [ ] A site in two team folders with different read modes does not take the most shared one

**Seats and billing**

- [x] Two invites are accepted at once and the team ends up with 11 seats
- [ ] A teammate with a personal Premium Archive subscription leaves the team and drops to free
- [x] A team's payment fails and teammates keep Pro after the paid period ends
- [x] A teammate who leaves or is removed gets no email, or two
- [ ] A lapsed team pays again and its folders, roles or settings are gone
- [x] The scheduled premium expiry deactivates a teammate whose only entitlement is the team
- [x] A teammate's Listen or Ask AI usage is counted against their own account instead of the team owner's
- [x] One account ends up owning two teams, or active in two teams at once
- [ ] An Enterprise only feature works on the $79 tier when its endpoint is called directly
- [x] A teammate's own Stripe renewal keeps charging after they join
- [x] A team plan bought in the App Store or on Play does not start a team, or lapses on the wrong day
- [ ] One owner ends up paying for a team plan in two places
- [x] The hourly task lapses a team between the end of its period and the renewal arriving
- [x] The owner keeps personal Pro for a year after paying once
- [x] The AI filter usage subscription hides the team subscription
- [ ] A team is started without a payment the provider confirms
- [x] Two payment notices at once create the team twice
- [x] A team owner's switch between providers refunds most of a month
- [x] A transfer mutes the new owner's sites, or records the old owner's team Pro as their own plan
- [x] The old owner's store subscription keeps renewing the team after a transfer
- [x] A Play expiry notice for an upgraded token ends the team
- [x] A staff refund leaves the team running
- [x] A comp is set on a paid team by mistake, so it never lapses
- [x] A switch down from a team plan ends the team before the paid month is over
- [x] Joining refunds the teammate, cancels at once instead of at the end of the period, or cancels their AI filter billing
- [x] The nightly expiry sends a teammate the expiry email because of an old trial date
- [x] A new signup who joins during their trial is expired by the trial branch
- [x] An App Store renewal during the seat is dropped, and the person falls to free after leaving
- [x] A Play expiry notice strips team Pro
- [x] Archive bought or gifted during the seat is lost when the seat ends
- [x] Someone leaves a team and keeps Premium Pro, for a minute or for good
- [x] Leaving and rejoining records team Pro as the person's own tier
- [x] A plan that is still paid for drops to free when the seat ends, or a plan that ran out survives it
- [x] A webhook that saves the whole profile row overwrites the grant
- [x] Joining sends the Pro welcome email or the staff upgrade email, or writes a payment row
- [x] A shared meter counts usage from before someone joined or after they left, or gives each person their own 10 hours
- [x] AI filters bill the teammate's own Stripe customer or ignore the owner's spending limit
- [x] The team passes 10,000 sites through add a site, OPML import, unmute or the feed chooser
- [x] A site several teammates follow is counted more than once, or muted sites are counted
- [x] Deleting the owner's account leaves teammates on Pro for good

**Notifications**

- [ ] A teammate with a personal setting and a team rule on the same feed gets two notifications
- [ ] A Slack channel gets one post per teammate instead of one per story
- [ ] The owner's private training on a site changes what a team channel receives
- [ ] Removing a rule wipes a teammate's own earlier setting
- [ ] A required rule is turned off through the existing notifications endpoint
- [ ] The checkup shows green for a device whose token was revoked
- [ ] A webhook URL that points at an internal address is saved or called
- [ ] A slow webhook holds up a Celery worker
- [ ] A channel URL shows up whole in a log line or an API response

**Single sign-on**

- [ ] An assertion for an email that belongs to an existing account takes over that account without proof
- [ ] A deactivated teammate's phone stays signed in
- [ ] An unverified domain is used to claim accounts
- [ ] Require SSO locks out the owner when the identity provider is misconfigured
- [ ] An account that existed before joining is locked when its teammate is deprovisioned

## Open decisions

- [x] **Listen hours.** Decided 2026-11-26: the team shares Pro's 10 hours a week. Worst case about $94 a month per team at $2.16 per generated hour, the same exposure as one Pro subscriber.
- [x] **Sites per teammate.** Decided 2026-11-26: the team shares Pro's 10,000 sites.
- [x] **Splitting a team plan among strangers.** Decided 2026-11-26: accepted. Anyone the team invites can join.
- [x] **What else belongs in the $129 tier.** Decided 2026-11-26: white label branding, audit log export and SIEM streaming, the IP allow list, session limits and sign in history, groups synced from the identity provider, and data retention with full export. For comparison, Inoreader's 10 seat plan is $119.99 and includes SAML but none of those and no SCIM.
- [x] **Who owns an account.** Decided 2026-11-26: it depends on how the account was created. One that existed before joining stays the person's. One that single sign-on created is locked on removal, with an export on request. A team can never read anyone's private account.
- [x] **Teammates who already pay.** Decided 2026-11-26: their Stripe or PayPal renewal is cancelled automatically when they join and they keep what they paid for until it runs out. App Store and Play subscribers get a notice with a link, since only the subscriber can cancel those.
- [x] **Grace period on removal.** Decided 2026-11-26: none. Leaving or being removed downgrades the account at once.
- [x] **Free trial.** Decided 2026-11-26: none.
- [x] **Name of the $129 tier.** Decided 2026-11-26: Premium Team Enterprise.
- [x] **Transferring ownership.** Decided 2026-11-26: self serve. The new owner accepts and enters a card, the team's shared read status and training are copied to their account, and the old owner's team plan ends.
- [x] **Annual billing.** Decided 2026-11-26: monthly only.
- [x] **How shared sites are counted.** Decided 2026-11-26: distinct sites across the team.
- [ ] **Price above 10 seats.** Inoreader charges $224.99 for 20 and $374.99 for 50.
- [x] **Which extension features to drop.** Decided 2026-11-26: the onboarding call, priority support, security documents, the nonprofit discount, SMS alerts, Apple Watch alerts, the Live Activity and critical alerts. White label branding stays, on Premium Team Enterprise only.

## Marketing

The research ranks the most winnable search territory as delivery ("rss to slack", "rss to microsoft teams", "slack news alerts"), then team readers ("team rss reader", "shared rss reader for teams"), then replacing the free tool ("google alerts for teams"). The full list is in the research file.

- [ ] The feature page (see above)
- [ ] A page for RSS to Slack
- [ ] A page for RSS to Microsoft Teams, which can speak to the connector Microsoft retired in May 2026
- [ ] A page for RSS to webhook
- [ ] A page for security teams
- [ ] A page for agencies
- [ ] A page for competitive intel
- [ ] A page for legal and regulatory teams
- [ ] A page for newsrooms
- [ ] A comparison page against Feedly for teams
- [ ] A comparison page against Inoreader for teams
- [ ] A comparison page against Feeder for teams
- [ ] A comparison page against Google Alerts
- [ ] A blog post announcing it, through the existing blog workflow

Facts for those pages. Each needs checking against the live source before it is published:

- [ ] Feedly's team features start at $1,600 a month
- [ ] Feedly and Inoreader team folders are opt in. Ours are pushed
- [ ] Read status is individual at Feedly and Inoreader. Feeder shares it but only for a whole workspace and without showing who read what
- [ ] No reader found assigns folders to people or verifies notification delivery
