---
layout: post
title: "MCP Server & CLI: Connect AI agents to your NewsBlur"
tags: ["web"]
---

I read a lot of feeds. Hundreds of them, across dozens of folders. Some mornings I can sit down and work through everything. Other mornings I want to ask "what did I miss?" and get a real answer, not a generic summary from a tool that doesn't know what I care about. The problem has always been that AI assistants can't see your feeds. They don't know what you subscribe to, what you've trained as interesting, or what you saved last week. They're working blind.

Today I'm launching the NewsBlur MCP Server. MCP (Model Context Protocol) is an open standard that lets AI agents connect to external tools and data. With the NewsBlur MCP server, Claude, Codex, Cursor, Windsurf, and any other MCP-compatible tool can read your feeds, manage your stories, train your classifiers, and organize your subscriptions. It's your NewsBlur, accessible to your AI agent.

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

Codex, Cursor, and Windsurf each have their own config format. Setup instructions for all of them are on the <a href="https://newsblur.com/feature/mcp-cli">MCP feature page</a>.

On first use, a browser window opens for you to log in and authorize access. Authentication uses OAuth 2.0, the same standard used by third-party apps. Your credentials are never stored on the MCP server, and you can revoke access at any time from your account settings.

### Command-line interface

Everything the MCP server can do is also available from your terminal. Install with pip:

```
pip install newsblur
```

Then log in and start using it:

```bash
newsblur auth login
newsblur stories list                          # unread stories
newsblur stories list --folder Tech --limit 5  # filter by folder
newsblur stories search "machine learning"     # full-text search
newsblur stories saved --tag research          # saved stories by tag
newsblur briefing                              # daily briefing
newsblur feeds list                            # all subscriptions
newsblur feeds add https://example.com         # subscribe
newsblur save 123:abc --tag ai                 # save with tags
newsblur train like --feed 42 --author "Name"  # train classifier
newsblur discover trending                     # trending feeds
```

Output defaults to formatted text, but pass `--json` to get structured output you can pipe to jq or use in scripts. There's also a `--server` flag for self-hosted NewsBlur instances.

<!-- SCREENSHOT: Terminal showing newsblur CLI output, maybe `newsblur stories list` with formatted story output -->
<img src="/assets/mcp-server-cli-output.png" style="width: 90%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

### Availability

The MCP server and CLI are available now for <a href="https://newsblur.com/?next=premium">Premium Archive</a> and Premium Pro subscribers. Setup takes one command and one browser authorization.

If you have ideas for new tools, workflows, or improvements, please share them on the <a href="https://forum.newsblur.com">NewsBlur forum</a>.
