# Premium Team

The plan and build checklist for a team tier on NewsBlur. Market research is in `PREMIUM_TEAM_RESEARCH.md`.

## How to use this file

- Every line with a box is something to decide, build, test or capture.
- `[ ]` is not done. `[x]` is done: built, tested and committed on this branch.
- Each feature section ends with a **Screenshots** list. Those are the pictures the feature page needs, one per distinct feature.
- Work happens in the order of the "Build order" section. A box is ticked in the same commit that finishes it.
- Decisions made while building are recorded under "Decisions" with the date.

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
- [x] Every step is finished on the web, iOS and Android before the next one starts
- [x] The PR is ready for review from the start, and the review bots review every push

- [x] The team is the owner's account. The owner is the one who pays, and everything the team shares falls under the owner's user id: billing, shared read status, team training and metered usage. There are no hidden accounts
- [x] The $129 tier is called Premium Team Enterprise
- [x] When someone who pays for their own plan joins a team, their Stripe or PayPal renewal is cancelled automatically and they keep what they already paid for until it runs out. App Store and Play subscriptions cannot be cancelled by us, so those teammates get a notice with a link
- [x] A removed teammate keeps Premium Pro on their private feeds for 14 days, with an email on day 1 and day 10
- [x] No free trial

How the shared site limit is counted is my reading, not yet confirmed: 10,000 distinct sites across the team's folders and every teammate's private feeds, so a site ten teammates follow counts once.

Still open. Each has a recommendation further down under "Open decisions":

- [ ] What else belongs in the $129 tier
- [ ] Who owns an account when single sign-on is required and a teammate is removed
- [ ] Whether ownership can be transferred, now that the owner's account is the one that pays
- [ ] Annual billing
- [ ] Price above 10 seats
- [ ] Which extension features to drop

## The upgrade dialog

The upgrade dialog (`media/js/newsblur/reader/reader_premium_upgrade.js`) has three cards on top (Premium, Premium Archive, Premium Pro) and a bottom row (Free, Self-Hosted).

- [ ] A "For teams" row between them with two cards side by side
- [ ] A "Start a team" button on each card that goes to Stripe Checkout
- [ ] A line under the row: "More than 10 teammates? Get in touch."
- [ ] A line at the bottom of the Premium Pro card: "Reading with coworkers? See Premium Team"
- [ ] A callout in the notifications dialog: "Set these up for your whole team"
- [ ] A callout in the folder menu: "Share this folder with a team"
- [ ] A callout in the account dialog for anyone not on a team

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

**Screenshots**

- [ ] The upgrade dialog with the "For teams" row
- [ ] Stripe Checkout for a team

## Features, part 1: the core

### 1. Seats and accounts

- [ ] Up to 10 teammates on one plan, with a contact link for larger teams
- [ ] Every teammate gets every Premium Pro feature: feeds fetched every 5 to 15 minutes, archive, Ask AI, regular expressions, MCP and CLI
- [ ] The team shares one Premium Pro account's allowances: 10,000 sites across team folders and everyone's private feeds
- [ ] The team shares 10 hours of Listen a week
- [ ] Every other Pro allowance (Ask AI, AI filters) is shared the same way
- [ ] Every teammate keeps private feeds and folders that the team cannot see
- [ ] Join with an existing NewsBlur account and keep everything in it
- [ ] Invite by email
- [ ] Invite with a join link
- [ ] Three roles: owner, manager, member
- [ ] One bill on the owner's account, with invoices
- [ ] An account can own one team and be a member of others
- [ ] Leave or be removed and the account drops back to its own plan with its private feeds intact
- [ ] Transfer ownership to another teammate, who takes over the bill (open decision)

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
- [ ] Reading in private feeds is never shown to anyone

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
- [ ] Session length limit for the team

**Screenshots**

- [ ] The Security tab with a verified domain
- [ ] The SAML setup form
- [ ] The login page asking for a work email
- [ ] Single sign-on on a phone

### 10. Billing

- [ ] Stripe only, on the web
- [ ] The owner's account pays. Premium Team and Premium Team Enterprise are plans on the owner's own NewsBlur account, bought the same way as Premium Pro
- [ ] An owner who already pays for Premium, Archive or Pro is switched to the team plan with the difference prorated
- [ ] A teammate's own Stripe or PayPal renewal is cancelled when they join. App Store and Play subscribers get a notice with a link
- [ ] Two monthly prices, $79 and $129, and switching between them prorates
- [ ] Invoices and card changes through the Stripe customer portal
- [ ] If payment fails: retries, an email to the owner, a grace period, then read only, then inactive
- [ ] Team folders and settings are kept when a team goes inactive, so it can come back
- [ ] Staff can raise a team's seat limit and set a custom price
- [ ] A warning email and a grace period before a removed teammate's sites are muted

**Screenshots**

- [ ] The Billing tab

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
- [ ] SMS for critical alerts (Distill)
- [ ] iOS critical alerts that break through Do Not Disturb for the on duty teammate
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
- [ ] White label reports for agencies (Awario)
- [ ] RSS and JSON output feed for every team folder (Inoreader)
- [ ] Public read only page for a team folder
- [ ] Embeddable widget of a team folder for an intranet

**Screenshots**

- [ ] The digest builder
- [ ] A digest email
- [ ] Digest open and click stats
- [ ] A public team folder page

### 15. Sources

- [ ] A team library of every site any teammate follows, with one click to add it to a team folder (Feeder)
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
- [ ] Groups of teammates, synced from the identity provider, used to share folders
- [ ] More than one team per account, with a switcher
- [ ] Separate workspaces per client for agencies (Syften, Meltwater)
- [ ] Sign in with Google or Microsoft for the $79 tier
- [ ] Two factor sign in required for teams without SSO
- [ ] Audit log export as CSV
- [ ] Audit log streaming to a SIEM
- [ ] Sign in history per teammate
- [ ] IP allow list
- [ ] Data retention setting for the team
- [ ] Full team export
- [ ] Usage dashboard: active teammates, most read sites, sites nobody reads (Inoreader)
- [ ] Preselect folders at invite time (Feedly)
- [ ] Priority support with a response time (not code: needs Sam)
- [ ] Security and privacy documents for procurement (not code: needs Sam)

**Screenshots**

- [ ] The usage dashboard
- [ ] The team switcher
- [ ] The audit log export

### 18. More billing

- [ ] Annual billing (open decision)
- [ ] Pay by invoice or purchase order
- [ ] Tax IDs on invoices
- [ ] Discount for nonprofits, schools and newsrooms
- [ ] Free trial for a team (open decision)
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
- [ ] Lock screen Live Activity for a breaking alert
- [ ] Apple Watch alerts with mark read and claim
- [ ] Team folders in the Mac app's menu bar

**Screenshots**

- [ ] A team folder on iPhone
- [ ] A team folder on Android
- [ ] The widget
- [ ] The Live Activity

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
- [ ] The Preferences dialog's builders (`make_group`, `make_row`, `make_cards`, `make_chips`, the status pill) are shared so other dialogs can use them

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

- [ ] `Team`: name, slug, owner (one team per owner), plan (`team` or `team_enterprise`), seat_limit, status
- [ ] `TeamMember`: team, user, role, status (invited, active, suspended, removed)
- [ ] `TeamInvite`: team, email, token, role, expiry
- [ ] `TeamFolder`: team, parent, title, position, read_mode, audience (everyone or chosen members)
- [ ] `TeamFeed`: team_folder, feed, position, added_by
- [ ] `TeamFolderMember`: team_folder, user, kind (audience or assigned)
- [ ] `TeamNotificationRule`: team_folder or feed, trigger, channels, audience, required
- [ ] `TeamChannel`: team, kind (slack, teams, webhook), URL or credentials
- [ ] `TeamDomain`: team, domain, verification token, verified_at, require_sso
- [ ] `TeamSSOConfig`: team, protocol, provider metadata, SCIM token hash
- [ ] `TeamActivity`: team, actor, action, target, timestamp
- [ ] The team is anchored on its owner. One helper answers "whose account does this teammate's team usage fall under" and returns the owner's user id

Everything in NewsBlur is keyed by user id (subscriptions, read state, classifiers, notifications, usage). The team reuses that machinery through its owner's user id, the account that pays. There are no hidden accounts.

What that means in practice:

- The owner's read state in a shared folder is the team's read state.
- The owner's training on a team folder is the team's training. A manager who trains a team folder writes to it.
- Listen, Ask AI and AI filter usage by any teammate is counted against the owner's account, with the teammate recorded for the breakdown.
- Slack, Teams and webhook posts are scored with the owner's training.
- The owner sees team folders the same way every teammate does, under the team's top level folder, and keeps private folders beside it.

### Team folders: merge at read time, real subscriptions underneath

The collision: a user's folders are one JSON blob (`UserSubscriptionFolders` in `apps/reader/models.py`), a folder is identified by its title, and a subscription belongs to exactly one user (`unique_together = ("user", "feed")` on `UserSubscription`).

- [ ] Each teammate gets a real `UserSubscription` for every team feed, so unread counts, read state, training, mutes, notifications and fetch priority keep working unchanged
- [ ] Team folders are not written into anyone's blob. `load_feeds` and `load_feeds_flat` (`apps/reader/views.py`) merge them in as one extra top level folder, so web, iOS and Android render them as ordinary folders
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
- [ ] A Celery task applies the read to each other teammate and publishes `story:read:<hash>` on their channel. The web client, iOS (`RealtimeUpdates.swift`) and Android (`RealtimeMessage.kt`) already apply that message
- [ ] The owner's read state is the team's canonical read state, which a late joiner copies
- [ ] Read receipts are a Redis hash per story, user id to timestamp, with a TTL
- [ ] Receipts are returned inside the story payload for team feeds, not through a new endpoint
- [ ] Each fan out records what it changed, so it can be undone

### Premium Pro for teammates

The premium code recomputes tier from payment history (`setup_premium_history` in `apps/profile/models.py`) and expires accounts on a schedule, so a team grant has to be a source that code respects. `has_oauth_reader_grant` already protects lifetime Pro grants the same way.

- [ ] An active `TeamMember` grants Pro. The effective tier is the higher of the team's grant and whatever the person pays for
- [ ] The site limit is counted across the team: distinct sites in team folders plus every teammate's private feeds, against Pro's 10,000 (`max_feed_limit` in `apps/profile/models.py`)
- [ ] Listen usage is counted across the team against Pro's 10 hours a week (`apps/listen/usage.py`)
- [ ] Ask AI and AI filter usage are counted across the team against Pro's limits (`apps/ask_ai/usage.py`)
- [ ] When the team hits a shared limit, the teammate who hit it is told it is the team's limit and who to ask
- [ ] A `has_team_grant` check wherever premium is recomputed or expired
- [ ] When a seat ends, the account re-runs its premium history and falls back to its own plan or to free
- [ ] `deactivate_premium` mutes sites over the free limit, so a removed teammate gets a warning email and a grace period first
- [ ] Feed fetch priority follows: a team feed counts its teammates as Pro subscribers

This is the riskiest integration in the plan. That code handles Stripe, PayPal, App Store and Play history and has a lot of special cases.

### Notifications

- [ ] Team rules become ordinary `MUserFeedNotification` rows, one per teammate and feed, tagged with the rule that created them
- [ ] A teammate's previous setting is kept and restored when the rule is removed
- [ ] New fields on that Mongo document are added in one deploy and written in the next
- [ ] Channel posts run once per story from the feed fetcher hook that calls `push_feed_notifications`, scored with the team's training

### Single sign-on and SCIM

- [ ] Today's login is username and password, plus native Apple and Google sign in (`apps/api/social_auth.py`), whose rule is that provider identities never link on email alone. SSO keeps the rule
- [ ] Linked identities are stored like `SocialIdentity`, whose `provider` column is only 16 characters, so either a wider value or a separate table
- [ ] Sessions last 10 years (`SESSION_COOKIE_AGE`) and the mobile apps authenticate with that cookie. SSO teams get a session length limit
- [ ] Deactivation deletes the user's sessions from Redis
- [ ] The apps sign in through the system browser and come back with a one time code, modelled on the native flow in `social_auth.py`
- [ ] Choose libraries after checking each is maintained. Candidates: `python3-saml` (needs xmlsec in the Docker image), Authlib for OIDC, `django-scim2` for SCIM

### Billing

The owner's account pays, so a team plan is one more plan on a `Profile`, next to Premium, Archive and Pro. The existing Stripe code already buys, switches, renews and expires plans for a `Profile`, and its webhooks already find the owner.

- [ ] Two more plans, `team` and `team_enterprise`, in `plan_to_stripe_price` (`apps/profile/models.py`), with their Stripe prices in settings
- [ ] Activating either plan gives the owner Pro and creates or reactivates the owner's `Team`
- [ ] Switching to or from a team plan goes through `switch_stripe_subscription`, prorated
- [ ] When the owner's plan lapses or is cancelled, the team goes through its grace period and then inactive, and every teammate's grant ends with it
- [ ] Joining a team cancels the new teammate's own Stripe or PayPal renewal
- [ ] The staff User Admin dialog (`media/js/newsblur/reader/reader_admin.js`) gets a team section: seat limit, plan, comp

### Rules from CLAUDE.md that apply to every step

- New tables only, so migrations stay backward compatible. Anything that later touches a hot table starts with a `lock_timeout`.
- New Mongo fields are added in one deploy and written in the next.
- Code that runs inside Celery needs `make celery` as well as `make deploy`.
- All new interface text goes through the localization API.
- Web screens are checked in Light, Dark, Warm and Gray. The Warm and Gray stylesheets are edited by hand, with targeted edits only.
- Android screens are checked in light, dark and black, with colors centralized for Sapia.
- New iOS files are Swift.

## Build order

One step at a time, one agent at a time, each ending in passing tests and a commit. A step with screens is built on the server, then the web, then iOS, then Android, and is finished on all three before the next step starts. The web version goes on localhost first so it can be looked at before the apps copy it.

Core:

- [ ] 1. `apps/team`: teams, members, roles, invites, join links, seat limit, activity log
- [ ] 2. Premium Pro for teammates, shared allowances counted against the owner, fallback when a seat ends, grace period
- [ ] 3. Billing: the two team plans on the owner's account, plan switches, lapses, cancelling a new teammate's own renewal, staff controls
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

- [ ] 27. Widgets, Live Activity, Apple Watch, Mac menu bar (section 20)
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
- [ ] A member calls the rename or delete endpoint directly on a team folder
- [ ] A team feed pushes a member over their personal site limit and gets muted
- [ ] A folder is shared with some teammates and another teammate can still load its stories

**Read status**

- [ ] A fanned out read fans out again and loops
- [ ] Mark all as read in a shared folder from an old app version clears the team with no way back
- [ ] Two teammates mark and unmark the same story at the same moment
- [ ] A teammate joins a shared folder and sees thousands of unread stories the team already cleared
- [ ] A teammate's read in a private feed shows up in someone's read receipts
- [ ] A story in two team folders with different read modes

**Seats and billing**

- [ ] Two invites are accepted at once and the team ends up with 11 seats
- [ ] A teammate with a personal Premium Archive subscription leaves the team and drops to free
- [ ] A team's payment fails and teammates lose Pro before the grace period ends
- [ ] The scheduled premium expiry deactivates a teammate whose only entitlement is the team
- [ ] A teammate's Listen or Ask AI usage is counted against their own account instead of the team owner's
- [ ] One account ends up owning two teams
- [ ] A teammate's own Stripe renewal keeps charging after they join

**Notifications**

- [ ] A teammate with a personal setting and a team rule on the same feed gets two notifications
- [ ] A Slack channel gets one post per teammate instead of one per story
- [ ] Removing a rule wipes a teammate's own earlier setting
- [ ] A required rule is turned off through the existing notifications endpoint
- [ ] The checkup shows green for a device whose token was revoked

**Single sign-on**

- [ ] An assertion for an email that belongs to an existing account takes over that account without proof
- [ ] A deactivated teammate's phone stays signed in
- [ ] An unverified domain is used to claim accounts
- [ ] Require SSO locks out the owner when the identity provider is misconfigured

## Open decisions

- [x] **Listen hours.** Decided 2026-11-26: the team shares Pro's 10 hours a week. Worst case about $94 a month per team at $2.16 per generated hour, the same exposure as one Pro subscriber.
- [x] **Sites per teammate.** Decided 2026-11-26: the team shares Pro's 10,000 sites.
- [x] **Splitting a team plan among strangers.** Decided 2026-11-26: accepted. Anyone the team invites can join.
- [ ] **The $129 tier against Inoreader.** Inoreader's 10 seat plan is $119.99 and includes SAML. What we have that they do not: SCIM, SSO in the mobile apps, shared read status, pushed folders and the notification checkup. Worth considering: move the audit log export and session length limit into $129 so it reads as the security tier.
- [ ] **Who owns an account.** Recommended: the person always does. A team can remove someone but never delete or read their account. With "Require SSO" on, a removed teammate regains password login by confirming a personal email address.
- [x] **Teammates who already pay.** Decided 2026-11-26: their Stripe or PayPal renewal is cancelled automatically when they join and they keep what they paid for until it runs out. App Store and Play subscribers get a notice with a link, since only the subscriber can cancel those.
- [x] **Grace period on removal.** Decided 2026-11-26: 14 days, with an email on day 1 and day 10.
- [x] **Free trial.** Decided 2026-11-26: none.
- [x] **Name of the $129 tier.** Decided 2026-11-26: Premium Team Enterprise.
- [ ] **Transferring ownership.** The owner's account is the one that pays and the one the team's shared state falls under. A transfer means the new owner takes over the bill and the team's read state and training move to their account. Options: build that, or leave it out and have teams ask support.
- [ ] **Annual billing.** Inoreader has no annual team price.
- [ ] **Price above 10 seats.** Inoreader charges $224.99 for 20 and $374.99 for 50.
- [ ] **Which extension features to drop.**

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
