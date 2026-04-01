---
layout: post
title: "The NewsBlur MCP Server and CLI Tool"
tags: ["web"]
---

NewsBlur has always had an API. Every feature in the web app, the iOS app, and the Android app runs through it. But APIs are for developers. Today I'm shipping two new ways to interact with your NewsBlur: an MCP server that lets AI agents read your feeds, manage stories, and train classifiers on your behalf, and a command-line tool that puts your entire NewsBlur in your terminal. One is for your AI. The other is for you. Both use the same 22 operations, and both work right now.

MCP (Model Context Protocol) is an open standard that lets AI agents connect to external tools and data. With the NewsBlur MCP server, Claude, Codex, Cursor, Windsurf, and any other MCP-compatible agent can read your feeds, manage your stories, train your classifiers, and organize your subscriptions.

<!-- SCREENSHOT: Claude Code or Claude Desktop showing a conversation where the agent reads NewsBlur feeds and summarizes stories -->
<img src="/assets/mcp-server-claude-conversation.png" style="width: 100%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

### 22 tools for your agent

The MCP server exposes 22 tools that cover everything you do in NewsBlur:

**Reading** — List feeds and folders with unread counts. Load stories from any feed, folder, or all subscriptions at once. Filter by unread, focus, or starred. Search across your entire archive with full-text search. Pull the original article text from the source. Get your AI daily briefing. Browse stories from your rarely-publishing infrequent feeds.

**Actions** — Mark stories as read by hash, by feed, or by folder. Save stories with tags, notes, and highlights. Subscribe and unsubscribe. Move feeds between folders. Rename feeds and folders. Share stories to your Blurblog.

**Intelligence** — View your trained classifiers across all feeds. Train new likes and dislikes by author, tag, title, or text content. The full range of training levels is available, including the new super dislike that overrides all other positive scores.

**Discovery** — Search for new feeds by topic. Find feeds similar to ones you already follow. Browse trending feeds.

<!-- SCREENSHOT: The MCP feature page on newsblur.com showing the 22 tools grid -->
<img src="/assets/mcp-server-tools-grid.png" style="width: 90%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

### What this looks like in practice

You ask your agent: "What are my infrequent stories today?" It calls `newsblur_get_infrequent_stories` and comes back with a summary of the stories from your low-volume feeds, the ones that publish once a week and are easy to miss in a busy river.

You say: "Save that Stratechery article and tag it ai, investing." The agent calls `newsblur_save_story` with the right story hash and tags. Done.

You ask: "What have I saved about climate policy this month?" It searches your saved stories and gives you a summary you can actually work with.

The agent knows your feeds, your folders, your classifiers, your saved stories. It's working with your actual NewsBlur data, not guessing.

### Connect in one command

For Claude Code:

```
claude mcp add --transport http newsblur https://newsblur.com/mcp/
```

For Claude Desktop, add this to your `claude_desktop_config.json`:

```json
{
  "newsblur": {
    "type": "http",
    "url": "https://newsblur.com/mcp/"
  }
}
```

Codex, Cursor, and Windsurf each have their own config format. Setup instructions for all of them are on the <a href="https://newsblur.com/features/mcp">MCP Server feature page</a>.

On first use, a browser window opens for you to log in and authorize access. Authentication uses OAuth 2.0, the same standard used by third-party apps. Your credentials are never stored on the MCP server, and you can revoke access at any time from your account settings.

### Command-line interface

Everything the MCP server can do is also available from your terminal. Full documentation is on the <a href="https://newsblur.com/features/cli">CLI feature page</a>. Install with pip:

```
uv pip install newsblur-cli
```

Then log in and start using it:

```bash
newsblur auth login
```

**Read stories** from feeds, folders, or everything at once:

```bash
newsblur stories list                          # unread stories
newsblur stories list --folder Tech --limit 5  # filter by folder
newsblur stories search "machine learning"     # full-text search
newsblur stories saved --tag research          # saved stories by tag
newsblur stories infrequent                    # rarely-publishing feeds
newsblur stories original 123:abc456           # fetch full article text
```

**Get your daily briefing** with AI-curated summaries:

```bash
newsblur briefing                              # today's briefing
newsblur briefing --limit 1                    # just the latest
newsblur briefing --json                       # structured output
```

**Manage feeds and folders:**

```bash
newsblur feeds list                            # all subscriptions
newsblur feeds folders                         # folder tree with counts
newsblur feeds add https://example.com         # subscribe
newsblur feeds add https://blog.com -f Tech    # subscribe into a folder
newsblur feeds remove 42                       # unsubscribe
newsblur feeds organize move_feed --feed-id 42 --from News --to Tech
```

**Take actions on stories:**

```bash
newsblur save 123:abc --tag ai --tag research  # save with tags
newsblur unsave 123:abc                        # remove from saved
newsblur read --feed 42                        # mark feed as read
newsblur share 123:abc --comment "Worth reading"
```

**Train your intelligence classifiers:**

```bash
newsblur train show --feed 42                  # view current training
newsblur train like --feed 42 --author "Name"  # train a like
newsblur train dislike --feed 42 --tag sponsor # train a dislike
```

**Discover new feeds:**

```bash
newsblur discover search "machine learning"    # search by topic
newsblur discover similar --feed 42            # find similar feeds
newsblur discover trending                     # trending feeds
```

Every command supports `--json` for structured output you can pipe to jq or use in scripts, and `--raw` for unformatted text. There's also a global `--server` flag for self-hosted NewsBlur instances:

```bash
newsblur --server https://my-newsblur.example.com auth login
newsblur briefing --json | jq '.items[0].section_summaries'
```

<!-- SCREENSHOT: Terminal showing newsblur CLI output, maybe `newsblur stories list` with formatted story output -->
<img src="/assets/mcp-server-cli-output.png" style="width: 90%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

### Readonly mode

Giving an AI agent access to your NewsBlur is powerful, but maybe you want to start with guardrails. The CLI has a readonly mode that blocks all write operations: no saving, no sharing, no training, no subscribing, no marking as read. Your agent can read your feeds and search your stories, but it cannot change anything.

```bash
newsblur auth readonly --on
```

With readonly on, any write command returns an error instead of executing. The agent sees your data but cannot touch it.

The important part is what happens when you turn it off. Disabling readonly mode logs you out and requires you to re-authenticate in the browser:

```bash
newsblur auth readonly --off
# "You have been logged out and must re-authenticate."
newsblur auth login
```

This is deliberate. An AI agent cannot silently toggle readonly off and start making changes. Only a human sitting at a browser can re-authorize write access. If you hand the CLI to an agent and want to be sure it stays read-only, it will.

### Availability

The MCP server and CLI are available now for <a href="https://newsblur.com/?next=premium">Premium Archive</a> and Premium Pro subscribers. Setup takes one command and one browser authorization. See the <a href="https://newsblur.com/features/mcp">MCP Server</a> and <a href="https://newsblur.com/features/cli">CLI Tool</a> feature pages for full documentation.

If you have ideas for new tools, workflows, or improvements, please share them on the <a href="https://forum.newsblur.com">NewsBlur forum</a>.
