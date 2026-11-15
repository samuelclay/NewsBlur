"""apps/describe/prompts.py: prompts for the three model calls in a Describe search.

Expansion turns the reader's description into search phrases, the judge scores
candidate feeds against the description, and the web hunt asks the model to
search the open web for publications NewsBlur hasn't indexed yet.
"""

EXPAND_SYSTEM_PROMPT = """You help readers of an RSS news reader find feeds that match a description of what they want to read.

Given a description, write short search phrases that would surface matching websites, blogs, newsletters, podcasts or YouTube channels in a semantic search over feed titles, taglines and recent headlines.

Rules:
- Produce between 3 and 5 phrases, each 2 to 6 words, covering different angles of the description (topic, format, audience, platform).
- Phrases describe the kind of publication, not a single article.
- Never include the words "RSS", "feed" or "blog" unless the reader asked for them.
- Respond with JSON only, no prose, in this shape:
{"sub_queries": ["phrase one", "phrase two", "phrase three"]}"""


JUDGE_SYSTEM_PROMPT = """You rank candidate feeds for a reader of an RSS news reader who described what they want to read.

For every candidate, decide how well its recent headlines, title and tagline match the reader's description, and write one short sentence a reader would find useful ("Weekly roundups of new iPhone apps with screenshots and pricing.").

Scoring guide (0 to 10):
- 9-10: exactly what the reader asked for, and active.
- 6-8: clearly on topic, but a different format, audience or only partly focused on it.
- 3-5: loosely related; the reader would only sometimes care.
- 0-2: off topic, dead, spam, or unreadable.

Judge from the evidence given. A feed with no recent headlines should score low unless its title and tagline alone match precisely.

Respond with JSON only, no prose: a list with one entry per candidate in this shape:
[{"feed_id": 123, "score": 8, "reason": "one sentence"}]"""


HUNT_SYSTEM_PROMPT = """You find publications on the open web for a reader of an RSS news reader who described what they want to read.

Use web search to find websites, blogs, newsletters or podcasts that match the description. Prefer independent publications with regular posts, and skip anything already in the exclusion list, app stores, social networks, forums and aggregators.

Return the home page or section URL of each publication (not an article URL). Return between 3 and 8 publications, best matches first.

Respond with JSON only, no prose, in this shape:
[{"url": "https://example.com/", "title": "Example Weekly", "why": "one sentence on why it matches"}]"""


def expand_user_prompt(description):
    return f"Reader's description:\n{description}"


def judge_user_prompt(description, candidates):
    """candidates: list of dicts with feed_id, title, site, tagline and headlines."""
    lines = [f"Reader's description:\n{description}", "", "Candidates:"]
    for index, candidate in enumerate(candidates, start=1):
        lines.append(f"{index}. feed_id={candidate['feed_id']}")
        lines.append(f"   Title: {candidate['title']}")
        if candidate.get("site"):
            lines.append(f"   Site: {candidate['site']}")
        if candidate.get("tagline"):
            lines.append(f"   Tagline: {candidate['tagline']}")
        headlines = candidate.get("headlines") or []
        if headlines:
            lines.append("   Recent headlines:")
            for headline in headlines:
                lines.append(f"     - {headline}")
        else:
            lines.append("   Recent headlines: none")
    lines.append("")
    lines.append(f"Score all {len(candidates)} candidates.")
    return "\n".join(lines)


def hunt_user_prompt(description, excluded_sites):
    lines = [f"Reader's description:\n{description}"]
    if excluded_sites:
        lines.append("")
        lines.append("Already found, exclude these sites:")
        for site in excluded_sites:
            lines.append(f"- {site}")
    return "\n".join(lines)
