# NewsBlur CLI

A command-line interface for [NewsBlur](https://newsblur.com), the visual intelligence RSS reader. Read feeds, manage stories, train classifiers, and more from your terminal.

## Install

```bash
pip install newsblur-cli
```

## Quick Start

```bash
# Log in (opens your browser for OAuth)
newsblur auth login

# Get your daily briefing
newsblur briefing

# List your feeds
newsblur feeds list

# Read stories from a feed
newsblur stories river --feed 42

# Search stories
newsblur stories search "machine learning"

# Save a story
newsblur save <story-hash>

# Mark stories as read
newsblur read <story-hash>
```

## Commands

| Command | Description |
|---------|-------------|
| `newsblur auth login` | Log in via OAuth |
| `newsblur auth logout` | Log out and remove credentials |
| `newsblur auth status` | Show authentication status |
| `newsblur briefing` | Daily briefing of top stories |
| `newsblur stories river` | Read stories from feeds or folders |
| `newsblur stories search` | Search across stories |
| `newsblur feeds list` | List subscribed feeds |
| `newsblur feeds add` | Subscribe to a new feed |
| `newsblur feeds remove` | Unsubscribe from a feed |
| `newsblur train show` | View intelligence classifiers |
| `newsblur train set` | Train a classifier |
| `newsblur discover` | Find new feeds by topic |
| `newsblur account` | Show account info |
| `newsblur save` | Save a story |
| `newsblur read` | Mark a story as read |

## Self-Hosted

For self-hosted NewsBlur instances, pass `--server`:

```bash
newsblur auth login --server https://nb.example.com
```

The server URL is persisted to `~/.config/newsblur/config.json`.

## Output Formats

```bash
# Rich terminal output (default)
newsblur feeds list

# JSON output (for scripting)
newsblur --json feeds list

# Raw text output
newsblur --raw feeds list
```

## MCP Server

This package also includes an MCP (Model Context Protocol) server for AI assistants. See [NewsBlur MCP Server](https://newsblur.com/features/mcp) for details.

## Requirements

- Python 3.11+
- A NewsBlur account (premium required for most features)

## Links

- [NewsBlur](https://newsblur.com)
- [GitHub](https://github.com/samuelclay/NewsBlur)
- [MCP Server](https://newsblur.com/features/mcp)
- [CLI Tool](https://newsblur.com/features/cli)
