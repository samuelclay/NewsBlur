---
name: newsblur-cli
description: Manage your NewsBlur from the terminal. Read feeds, search stories, save and share articles, train intelligence classifiers, discover new feeds, and automate workflows with the NewsBlur CLI. Use when the user wants to interact with their NewsBlur account, check feeds, manage subscriptions, or build scripts around their news reading.
---

# NewsBlur CLI

The NewsBlur CLI (`newsblur-cli`) gives you full access to your NewsBlur account from the terminal. Install it and authenticate before running any commands.

## Setup

```bash
uv pip install newsblur-cli
newsblur auth login
```

`auth login` opens a browser for OAuth authorization. The token is stored at `~/.config/newsblur/`.

For self-hosted instances, pass `--server` or set `NEWSBLUR_SERVER`:

```bash
newsblur --server https://my-newsblur.example.com auth login
```

## Readonly Mode

The CLI has a readonly mode that blocks all write operations (saving, sharing, training, subscribing, marking as read). Useful when handing the CLI to an AI agent.

```bash
newsblur auth readonly --on
```

Check current readonly status:

```bash
newsblur auth readonly
```

Disabling readonly logs you out and requires browser re-authentication. An AI agent cannot silently toggle this off.

```bash
newsblur auth readonly --off
# "You have been logged out and must re-authenticate."
newsblur auth login
```

If you are operating in readonly mode, all write commands will fail with an error. Read commands work normally.

## Output Formats

Every command supports these flags:

- `--json` — structured JSON output, pipe to `jq`
- `--raw` — unformatted plain text
- Default — human-readable formatted output

## Commands

### Stories

List unread stories across all feeds:

```bash
newsblur stories list
```

Filter by folder or limit results:

```bash
newsblur stories list --folder Tech --limit 5
```

Full-text search across your archive:

```bash
newsblur stories search "machine learning"
```

View saved/starred stories, optionally filtered by tag:

```bash
newsblur stories saved
newsblur stories saved --tag research
```

Browse stories from rarely-publishing feeds (easy to miss in a busy river):

```bash
newsblur stories infrequent
```

Fetch the original full article text from the source:

```bash
newsblur stories original <story_hash>
```

View stories you've already read:

```bash
newsblur stories read
```

### Daily Briefing

Get an AI-curated briefing with top stories, infrequent site gems, and long reads:

```bash
newsblur briefing
newsblur briefing --limit 1
newsblur briefing --json
```

### Feeds and Folders

List all subscriptions:

```bash
newsblur feeds list
```

View the folder tree with unread counts:

```bash
newsblur feeds folders
```

Get detailed info about a specific feed:

```bash
newsblur feeds info <feed_id>
```

Subscribe to a new feed:

```bash
newsblur feeds add https://example.com/feed.xml
newsblur feeds add https://blog.com -f Tech
```

Unsubscribe from a feed:

```bash
newsblur feeds remove <feed_id>
```

Move a feed between folders or rename it:

```bash
newsblur feeds organize move_feed --feed-id 42 --from News --to Tech
```

### Story Actions

Save a story with tags:

```bash
newsblur save <story_hash> --tag ai --tag research
```

Remove a story from saved:

```bash
newsblur unsave <story_hash>
```

Mark stories as read by feed, folder, or specific story hashes:

```bash
newsblur read --feed 42
newsblur read --folder Tech
newsblur read 123:abc 456:def
```

Share a story to your Blurblog:

```bash
newsblur share <story_hash> --comment "Worth reading"
```

### Intelligence Training

View your trained classifiers for a feed:

```bash
newsblur train show --feed 42
```

Train a like on an author, tag, title, or feed:

```bash
newsblur train like --feed 42 --author "Ben Thompson"
newsblur train like --feed 42 --tag analysis
newsblur train like --feed 42 --title "quarterly earnings"
```

Train a dislike:

```bash
newsblur train dislike --feed 42 --tag sponsored
newsblur train dislike --feed 42 --author "Guest Post"
```

### Feed Discovery

Search for new feeds by topic:

```bash
newsblur discover search "machine learning"
```

Find feeds similar to one you already follow:

```bash
newsblur discover similar --feed 42
```

Browse trending feeds:

```bash
newsblur discover trending
```

### Notifications

Manage per-feed notification settings:

```bash
newsblur notifications --feed 42
```

### Account

View your account info and subscription status:

```bash
newsblur account
```

## Scripting Examples

Pipe story titles to the terminal:

```bash
newsblur stories list --json | jq -r '.items[] | "\(.title) - \(.feed_title)"'
```

Extract briefing summaries:

```bash
newsblur briefing --json | jq '.items[0].section_summaries'
```

Save all unread stories from a folder with a tag:

```bash
for hash in $(newsblur stories list --folder Research --json | jq -r '.items[].story_hash'); do
  newsblur save "$hash" --tag to-review
done
```

Export your feed list:

```bash
newsblur feeds list --json | jq -r '.items[] | "\(.feed_title),\(.feed_address)"'
```

## Requirements

- Python 3.11+
- Premium Archive ($99/year) or Premium Pro ($29/month) subscription
- OAuth authentication via browser
