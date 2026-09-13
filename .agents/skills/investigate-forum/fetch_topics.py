#!/usr/bin/env python3
"""
fetch_topics.py: List NewsBlur forum topics that are waiting on a reply from Sam.

Used by the investigate-forum skill (.agents/skills/investigate-forum/SKILL.md).
Reads the public Discourse JSON API at forum.newsblur.com, no API key needed.

A topic "needs a reply" when its most recent post was written by someone other
than --me (default: samuelclay) and it had activity inside the window. Topics
already recorded in state.json are hidden unless a newer post arrived since they
were handled, in which case they come back flagged as a follow-up.

Examples:
    python3 fetch_topics.py                      # last 7 days, newest first
    python3 fetch_topics.py --days 14
    python3 fetch_topics.py --since 2026-09-01
    python3 fetch_topics.py --topic 13833        # one topic, ignores window and state
    python3 fetch_topics.py --topic https://forum.newsblur.com/t/wired-newsletters-blocked-as-spam/13833/3
    python3 fetch_topics.py --summary            # headers only, no post bodies
    python3 fetch_topics.py --all                # include topics already in state.json
    python3 fetch_topics.py --json               # machine readable
"""

import argparse
import datetime
import json
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

FORUM_URL = "https://forum.newsblur.com"
USER_AGENT = "NewsBlur forum triage (investigate-forum skill; samuel@newsblur.com)"
SKILL_DIR = pathlib.Path(__file__).resolve().parent
DEFAULT_STATE_PATH = SKILL_DIR / "state.json"
REQUEST_PAUSE_SECONDS = 0.25
MAX_PAGES = 10


def fetch(path, as_json=True):
    """GET a path from the forum, returning parsed JSON or raw text."""
    request = urllib.request.Request(FORUM_URL + path, headers={"User-Agent": USER_AGENT})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read().decode("utf-8")
            time.sleep(REQUEST_PAUSE_SECONDS)
            return json.loads(body) if as_json else body
        except urllib.error.HTTPError as error:
            # Discourse answers 429 when anonymous requests come too fast; back off and retry.
            if error.code == 429 and attempt < 2:
                time.sleep(5 * (attempt + 1))
                continue
            raise
    raise RuntimeError(f"Gave up fetching {path}")


def parse_iso(value):
    """Discourse timestamps look like 2026-09-13T21:18:38.917Z."""
    return datetime.datetime.strptime(value, "%Y-%m-%dT%H:%M:%S.%fZ").replace(tzinfo=datetime.timezone.utc)


def parse_topic_arg(value):
    """Accept a bare id, or any forum URL containing /t/<slug>/<id>."""
    value = value.strip()
    if value.isdigit():
        return int(value)
    match = re.search(r"/t/(?:[^/]+/)?(\d+)", value)
    if match:
        return int(match.group(1))
    raise argparse.ArgumentTypeError(f"Could not find a topic id in {value!r}")


def load_state(path):
    if not path.exists():
        return {"topics": {}}
    with open(path) as handle:
        state = json.load(handle)
    state.setdefault("topics", {})
    return state


def load_categories():
    data = fetch("/categories.json")
    return {category["id"]: category["slug"] for category in data["category_list"]["categories"]}


def iter_recent_topics(cutoff):
    """Walk /latest.json ordered by activity until every topic on a page is older than the cutoff."""
    for page in range(MAX_PAGES):
        data = fetch(f"/latest.json?no_definitions=true&order=activity&page={page}")
        topics = data["topic_list"]["topics"]
        if not topics:
            return
        oldest_on_page = None
        for topic in topics:
            bumped_at = parse_iso(topic["bumped_at"])
            if bumped_at >= cutoff:
                yield topic
            if not topic.get("pinned"):
                oldest_on_page = bumped_at if oldest_on_page is None else min(oldest_on_page, bumped_at)
        if oldest_on_page is not None and oldest_on_page < cutoff:
            return
        if not data["topic_list"].get("more_topics_url"):
            return


def fetch_topic_detail(topic_id):
    detail = fetch(f"/t/{topic_id}.json")
    raw = fetch(f"/raw/{topic_id}", as_json=False)
    return detail, raw


def build_record(topic, detail, raw, categories, state_entry, me):
    posts = detail["post_stream"]["posts"]
    last_post = posts[-1]
    handled_last_posted_at = (state_entry or {}).get("last_posted_at")
    followup = bool(state_entry) and handled_last_posted_at != topic.get("last_posted_at")
    return {
        "id": topic["id"],
        "title": topic["title"],
        "url": f"{FORUM_URL}/t/{topic['slug']}/{topic['id']}",
        "category": categories.get(topic.get("category_id"), str(topic.get("category_id"))),
        "tags": detail.get("tags") or [],
        "created_at": topic["created_at"],
        "last_posted_at": topic.get("last_posted_at"),
        "last_poster": topic.get("last_poster_username") or last_post["username"],
        "posts_count": topic.get("posts_count", len(posts)),
        "op_username": posts[0]["username"],
        "sam_has_posted": any(post["username"].lower() == me.lower() for post in posts),
        "closed": topic.get("closed", False),
        "state": state_entry,
        "followup_since_handled": followup,
        "raw": raw.strip(),
    }


def needs_reply(topic, me):
    if topic.get("closed") or topic.get("archived"):
        return False
    last_poster = (topic.get("last_poster_username") or "").lower()
    return last_poster != me.lower()


def print_human(records, summary_only):
    if not records:
        print("No forum topics are waiting on a reply in this window.")
        return
    print(f"{len(records)} topic(s) waiting on a reply, newest activity first:\n")
    for index, record in enumerate(records, 1):
        flag = ""
        if record["followup_since_handled"]:
            flag = f"  [FOLLOW-UP since handled as {record['state'].get('status')}]"
        elif record["state"]:
            flag = f"  [state: {record['state'].get('status')}]"
        print(
            f"{index}. [{record['id']}] {record['title']}{flag}\n"
            f"   {record['url']}\n"
            f"   category: {record['category']} | posts: {record['posts_count']} | opened by {record['op_username']} "
            f"on {record['created_at'][:10]} | last post {record['last_posted_at'][:16].replace('T', ' ')} "
            f"by {record['last_poster']} | sam has posted: {'yes' if record['sam_has_posted'] else 'no'}"
        )
    if summary_only:
        return
    for record in records:
        print("\n" + "=" * 100)
        print(f"[{record['id']}] {record['title']}")
        print(record["url"])
        if record["state"]:
            print(f"state.json entry: {json.dumps(record['state'], indent=2)}")
        print("=" * 100)
        print(record["raw"])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--days", type=int, default=7, help="Look back this many days of activity (default 7)")
    parser.add_argument("--since", help="Look back to this date (YYYY-MM-DD), overrides --days")
    parser.add_argument("--topic", type=parse_topic_arg, action="append", help="Topic id or URL, repeatable")
    parser.add_argument("--me", default="samuelclay", help="Forum username whose replies count (default samuelclay)")
    parser.add_argument("--state", type=pathlib.Path, default=DEFAULT_STATE_PATH, help="Path to state.json")
    parser.add_argument("--all", action="store_true", help="Include topics already recorded in state.json")
    parser.add_argument("--limit", type=int, default=0, help="Stop after this many topics (0 = no limit)")
    parser.add_argument("--summary", action="store_true", help="Print the header list only")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of text")
    args = parser.parse_args()

    if args.since:
        cutoff = datetime.datetime.strptime(args.since, "%Y-%m-%d").replace(tzinfo=datetime.timezone.utc)
    else:
        cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=args.days)

    state = load_state(args.state)
    categories = load_categories()

    if args.topic:
        candidates = []
        for topic_id in args.topic:
            detail = fetch(f"/t/{topic_id}.json")
            # Shape the detail payload like a /latest.json list entry so the rest of the code is shared.
            posts = detail["post_stream"]["posts"]
            candidates.append(
                {
                    "id": detail["id"],
                    "title": detail["title"],
                    "slug": detail["slug"],
                    "category_id": detail.get("category_id"),
                    "created_at": detail["created_at"],
                    "last_posted_at": detail.get("last_posted_at") or posts[-1]["created_at"],
                    "last_poster_username": posts[-1]["username"],
                    "posts_count": detail.get("posts_count", len(posts)),
                    "closed": detail.get("closed", False),
                    "archived": detail.get("archived", False),
                    "bumped_at": detail.get("last_posted_at") or posts[-1]["created_at"],
                }
            )
        explicit = True
    else:
        candidates = [topic for topic in iter_recent_topics(cutoff) if needs_reply(topic, args.me)]
        explicit = False

    # Newest activity first, per Sam's preference.
    candidates.sort(key=lambda topic: topic["bumped_at"], reverse=True)

    records = []
    for topic in candidates:
        state_entry = state["topics"].get(str(topic["id"]))
        already_handled = bool(state_entry) and state_entry.get("last_posted_at") == topic.get("last_posted_at")
        if already_handled and not (args.all or explicit):
            continue
        detail, raw = fetch_topic_detail(topic["id"])
        records.append(build_record(topic, detail, raw, categories, state_entry, args.me))
        if args.limit and len(records) >= args.limit:
            break

    if args.json:
        json.dump(records, sys.stdout, indent=2)
        print()
    else:
        print_human(records, args.summary)


if __name__ == "__main__":
    main()
