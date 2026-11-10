"""apps/describe/pipeline.py: the Describe feed search pipeline.

Each phase streams to the browser over Redis pubsub (node/describe.coffee
relays the events to the socket) and is persisted on the MDescribeSearch
document, so a page that missed the events, or a mobile app polling for
status, sees the same state:

1. expand  - Claude Haiku turns the description into 3 to 5 search phrases.
2. search  - each phrase is embedded and run against the feed vector index
             (apps/search/models.py SearchFeed); candidates stream in per phrase.
3. judge   - Haiku scores every candidate against the description in batches,
             streaming a 0 to 10 score and a one-line reason per feed.
4. hunt    - Haiku searches the open web for publications NewsBlur hasn't
             indexed; each site's feed is read in memory and judged. Nothing is
             saved until someone subscribes (apps/describe/web_preview.py).
5. finish  - weak matches are pruned, the list is capped at MAX_RESULTS.
"""

import json
import re
import time
from urllib.parse import urlparse

import anthropic
from celery.exceptions import SoftTimeLimitExceeded
from django.conf import settings
from django.utils.translation import gettext
from openai import OpenAI, OpenAIError

from apps.describe.models import (
    MAX_RESULTS,
    SOURCE_INDEX,
    SOURCE_WEB,
    hydrate_results,
    make_result_row,
    make_unsaved_row,
    sort_results,
)
from apps.describe.prompts import (
    EXPAND_SYSTEM_PROMPT,
    HUNT_SYSTEM_PROMPT,
    JUDGE_SYSTEM_PROMPT,
    expand_user_prompt,
    hunt_user_prompt,
    judge_user_prompt,
)
from apps.describe.web_preview import preview_site
from apps.rss_feeds.models import Feed
from apps.search.models import SearchFeed
from utils import log as logging
from utils.llm_costs import LLMCostTracker
from utils.llm_models import ANTHROPIC_MODEL

EMBEDDING_MODEL = "text-embedding-3-small"
FEATURE = "describe_feeds"

# apps/describe/pipeline.py: anthropic.APIError is the base of the SDK's
# connection, timeout and status errors.
MODEL_ERRORS = (anthropic.APIError,)


def parse_json(text):
    """Pull the JSON object or list out of a model reply, tolerating code fences and prose."""
    if not text:
        return None
    cleaned = text.strip()
    cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    try:
        return json.loads(cleaned)
    except ValueError:
        pass
    for opener, closer in (("[", "]"), ("{", "}")):
        start = cleaned.find(opener)
        end = cleaned.rfind(closer)
        if start != -1 and end > start:
            try:
                return json.loads(cleaned[start : end + 1])
            except ValueError:
                continue
    return None


def site_host(url):
    """The bare hostname of a URL, without www, for comparing sites."""
    try:
        host = (urlparse(url).hostname or "").lower()
    except ValueError:
        return ""
    return host[4:] if host.startswith("www.") else host


def chunks(items, size):
    for start in range(0, len(items), size):
        yield items[start : start + size]


class DescribeFeedSearch:
    SUB_QUERY_LIMIT = 5
    CANDIDATES_PER_QUERY = 12
    CANDIDATE_POOL = 40
    JUDGE_BATCH_SIZE = 12
    MIN_SCORE = 3
    WEB_SITE_LIMIT = 6
    WEB_SEARCH_USES = 4
    WEB_HUNT_BUDGET_SECONDS = 90
    WEB_SEARCH_TOOL = {"type": "web_search_20250305", "name": "web_search", "max_uses": WEB_SEARCH_USES}

    def __init__(self, search, user, publish=None):
        self.search = search
        self.user = user
        self.publish = publish or (lambda event_type, extra=None: None)
        self.results = []
        self.rows_by_feed_id = {}
        self.headlines = {}
        self.taglines = {}
        self.unsaved_count = 0
        self.started = time.time()
        self.stats = {
            "llm_calls": 0,
            "embeddings": 0,
            "web_searches": 0,
            "web_sites_tried": 0,
            "web_feeds_added": 0,
            "web_errors": 0,
            "candidates_considered": 0,
            "model_errors": 0,
        }

    # Orchestration ------------------------------------------------------------

    def run(self):
        self.search.mark_running()
        self.publish("start", {"prompt": self.search.prompt})
        sub_queries = self.expand_prompt()
        self.search_index(sub_queries)
        self.judge_unjudged()
        self.prune()
        try:
            self.hunt_web()
        except SoftTimeLimitExceeded:
            raise
        except Exception as e:
            # apps/describe/pipeline.py: the hunt is a bonus on top of the index results, which are
            # already judged and stored. Whatever goes wrong out on the web, those still get delivered.
            self.stats["hunt_error"] = str(e)[:200]
            logging.user(self.user, f"~FBDescribe: ~FR~SBweb hunt failed~SN, keeping index results: {e}")
        self.finish()
        return self.search

    def set_phase(self, phase, message):
        self.search.mark_phase(phase, message)
        self.publish("phase", {"phase": phase, "message": message})

    def persist_results(self):
        self.search.results = list(self.results)
        self.search.touch()

    def current_order(self):
        return [row["feed_id"] for row in self.results]

    # Phase 1: expand ---------------------------------------------------------

    def expand_prompt(self):
        self.set_phase("expanding", gettext("Reading your description"))
        prompt = self.search.prompt
        text = self.call_model(
            EXPAND_SYSTEM_PROMPT, expand_user_prompt(prompt), max_tokens=400, step="expand"
        )
        parsed = parse_json(text)
        queries = []
        if isinstance(parsed, dict):
            for query in parsed.get("sub_queries") or []:
                if isinstance(query, str) and query.strip():
                    queries.append(query.strip())
        unique_queries = []
        for query in queries:
            if query.lower() not in [q.lower() for q in unique_queries]:
                unique_queries.append(query)
        unique_queries = unique_queries[: self.SUB_QUERY_LIMIT]
        if not unique_queries:
            # The model failed or returned nothing usable: the description itself still searches well.
            unique_queries = [prompt[:200]]
        self.search.sub_queries = unique_queries
        self.search.touch()
        self.publish("queries", {"sub_queries": unique_queries})
        return unique_queries

    # Phase 2: search the feed index -----------------------------------------

    def search_index(self, queries):
        self.set_phase("searching", gettext("Searching NewsBlur's feeds"))
        prompt = self.search.prompt
        texts = [prompt] + [query for query in queries if query.lower() != prompt.lower()]
        for text in texts:
            vector = self.embed(text)
            if not vector:
                continue
            exclude = list(self.rows_by_feed_id.keys()) or None
            hits = SearchFeed.vector_query(
                vector, max_results=self.CANDIDATES_PER_QUERY, feed_ids_to_exclude=exclude
            )
            self.add_candidates_from_hits(hits, matched_query=text)
            if len(self.rows_by_feed_id) >= self.CANDIDATE_POOL:
                break

    def add_candidates_from_hits(self, hits, matched_query):
        scored = []
        for hit in hits or []:
            source = hit.get("_source") or {}
            try:
                feed_id = int(source.get("feed_id"))
            except (TypeError, ValueError):
                continue
            if feed_id in self.rows_by_feed_id:
                continue
            # The ES script adds 1.0 to the cosine similarity to keep scores positive.
            similarity = max(0.0, min(1.0, float(hit.get("_score", 1.0)) - 1.0))
            scored.append((feed_id, similarity))
        if not scored:
            return []

        feeds = {feed.pk: feed for feed in Feed.objects.filter(pk__in=[feed_id for feed_id, _ in scored])}
        new_rows = []
        for feed_id, similarity in scored:
            feed = feeds.get(feed_id)
            if not feed or feed.branch_from_feed_id:
                continue
            new_rows.append(self.add_candidate(feed, SOURCE_INDEX, matched_query, similarity))

        if new_rows:
            self.stats["candidates_considered"] += len(new_rows)
            self.persist_results()
            self.publish("candidates", {"results": hydrate_results(new_rows), "order": self.current_order()})
        return new_rows

    def add_candidate(self, feed, source, matched_query, similarity):
        stories = feed.get_stories(limit=5) or []
        row = make_result_row(
            feed, source, matched_query=matched_query, similarity=similarity, stories=stories
        )
        self.headlines[feed.pk] = [story.get("story_title") for story in stories if story.get("story_title")][
            :5
        ]
        feed_data = getattr(feed, "data", None)
        self.taglines[feed.pk] = (getattr(feed_data, "feed_tagline", "") or "")[:200]
        self.results.append(row)
        self.rows_by_feed_id[feed.pk] = row
        return row

    # Phase 3: judge ---------------------------------------------------------

    def judge_unjudged(self):
        unjudged = [row for row in self.results if not row.get("judged")]
        if not unjudged:
            return
        self.set_phase(
            "judging",
            gettext("Judging %(count)s feeds against your description") % {"count": len(unjudged)},
        )
        for batch in chunks(unjudged, self.JUDGE_BATCH_SIZE):
            verdicts = self.judge_batch(batch)
            if verdicts is None:
                continue
            applied = []
            for row in batch:
                verdict = verdicts.get(row["feed_id"])
                if not verdict:
                    continue
                row["score"] = verdict["score"]
                row["reason"] = verdict["reason"]
                row["judged"] = True
                applied.append({"feed_id": row["feed_id"], "score": row["score"], "reason": row["reason"]})
            self.results = sort_results(self.results)
            self.persist_results()
            self.publish("verdicts", {"verdicts": applied, "order": self.current_order()})

    def judge_batch(self, rows):
        candidates = [
            {
                "feed_id": row["feed_id"],
                "title": row["feed_title"] or "",
                "site": row["feed_link"] or "",
                "tagline": self.taglines.get(row["feed_id"], ""),
                "headlines": self.headlines.get(row["feed_id"], []),
            }
            for row in rows
        ]
        text = self.call_model(
            JUDGE_SYSTEM_PROMPT,
            judge_user_prompt(self.search.prompt, candidates),
            max_tokens=1500,
            step="judge",
        )
        parsed = parse_json(text)
        if not isinstance(parsed, list):
            return None
        verdicts = {}
        for item in parsed:
            if not isinstance(item, dict):
                continue
            try:
                feed_id = int(item.get("feed_id"))
                score = int(round(float(item.get("score"))))
            except (TypeError, ValueError):
                continue
            verdicts[feed_id] = {
                "score": max(0, min(10, score)),
                "reason": str(item.get("reason") or "").strip()[:300],
            }
        return verdicts

    def prune(self):
        """Drop judged feeds below MIN_SCORE and anything past MAX_RESULTS."""
        keep = []
        removed = []
        for row in sort_results(self.results):
            score = row.get("score")
            if row.get("judged") and score is not None and score < self.MIN_SCORE:
                removed.append(row["feed_id"])
            elif len(keep) >= MAX_RESULTS:
                removed.append(row["feed_id"])
            else:
                keep.append(row)
        self.results = keep
        self.rows_by_feed_id = {row["feed_id"]: row for row in keep}
        if removed:
            self.persist_results()
            self.publish("remove", {"feed_ids": removed, "order": self.current_order()})
        return removed

    # Phase 4: hunt the web ----------------------------------------------------

    def hunt_web(self):
        self.set_phase("hunting", gettext("Searching the web for feeds NewsBlur hasn't seen"))
        excluded_hosts = []
        for row in self.results:
            host = site_host(row.get("feed_link") or row.get("feed_address") or "")
            if host and host not in excluded_hosts:
                excluded_hosts.append(host)

        text = self.call_model(
            HUNT_SYSTEM_PROMPT,
            hunt_user_prompt(self.search.prompt, excluded_hosts),
            max_tokens=2500,
            step="hunt",
            tools=[self.WEB_SEARCH_TOOL],
        )
        sites = self.parse_sites(text)
        if not sites:
            return []

        hunt_started = time.time()
        known_hosts = set(excluded_hosts)
        known_addresses = {row.get("feed_address") for row in self.results}
        new_rows = []
        for site in sites[: self.WEB_SITE_LIMIT]:
            if time.time() - hunt_started > self.WEB_HUNT_BUDGET_SECONDS:
                logging.user(self.user, "~FBDescribe: web hunt out of time, stopping")
                break
            host = site_host(site["url"])
            if not host or host in known_hosts:
                continue
            self.stats["web_sites_tried"] += 1
            self.set_phase("hunting", gettext("Checking %(site)s for a feed") % {"site": host})
            preview = self.resolve_site(site["url"])
            if not preview:
                continue
            feed = preview.get("feed")
            if feed and feed.pk in self.rows_by_feed_id:
                continue
            if not feed and preview["feed_address"] in known_addresses:
                continue
            known_hosts.add(host)
            if feed:
                row = self.add_candidate(feed, SOURCE_WEB, matched_query=site.get("why", ""), similarity=None)
            else:
                row = self.add_unsaved_candidate(preview, matched_query=site.get("why", ""))
            known_addresses.add(row["feed_address"])
            self.stats["web_feeds_added"] += 1
            new_rows.append(row)
            self.persist_results()
            self.publish("candidates", {"results": hydrate_results([row]), "order": self.current_order()})

        if new_rows:
            self.judge_unjudged()
            self.prune()
        return new_rows

    def parse_sites(self, text):
        parsed = parse_json(text)
        if not isinstance(parsed, list):
            return []
        sites = []
        for item in parsed:
            if not isinstance(item, dict):
                continue
            url = str(item.get("url") or "").strip()
            if not url.startswith(("http://", "https://")):
                continue
            sites.append(
                {
                    "url": url,
                    "title": str(item.get("title") or "").strip()[:200],
                    "why": str(item.get("why") or "").strip()[:300],
                }
            )
        return sites

    def resolve_site(self, url):
        """Preview a site from the web hunt (apps/describe/web_preview.py), or None.

        Nothing is saved: the preview is either a Feed NewsBlur already has or
        a snapshot read from the site. These are arbitrary sites picked by a
        model, parsed by feed discovery and feedparser, so any failure at all
        is logged and the site skipped. One bad link never ends the search.
        """
        try:
            return preview_site(url)
        except SoftTimeLimitExceeded:
            raise
        except Exception as e:
            self.stats["web_errors"] += 1
            logging.user(self.user, f"~FBDescribe: ~FRcould not preview ~SB{url}~SN: {e}")
            return None

    def add_unsaved_candidate(self, preview, matched_query):
        """Add a web find NewsBlur has no Feed for, keyed by a negative row number."""
        self.unsaved_count += 1
        row = make_unsaved_row(-self.unsaved_count, preview, matched_query=matched_query)
        self.headlines[row["feed_id"]] = [
            story["story_title"] for story in preview.get("stories") or [] if story.get("story_title")
        ][:5]
        self.taglines[row["feed_id"]] = row["tagline"]
        self.results.append(row)
        self.rows_by_feed_id[row["feed_id"]] = row
        return row

    # Phase 5: finish ----------------------------------------------------------

    def finish(self, note=None):
        self.results = sort_results(self.results)[:MAX_RESULTS]
        self.persist_results()
        self.stats["duration_seconds"] = round(time.time() - self.started, 1)
        if note:
            self.stats["note"] = note
        self.search.mark_complete(stats=self.stats)
        self.publish(
            "complete",
            {"order": self.current_order(), "result_count": len(self.results), "stats": self.stats},
        )

    # Model calls ------------------------------------------------------------

    def call_model(self, system, user_text, max_tokens, step, tools=None):
        """One Claude Haiku call. Returns the reply text, or None when the API fails."""
        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY, timeout=120.0, max_retries=1)
        kwargs = {
            "model": ANTHROPIC_MODEL,
            "max_tokens": max_tokens,
            "system": system,
            "messages": [{"role": "user", "content": user_text}],
        }
        if tools:
            kwargs["tools"] = tools
        try:
            response = client.messages.create(**kwargs)
        except MODEL_ERRORS as e:
            self.stats["model_errors"] += 1
            logging.user(self.user, f"~FBDescribe: ~FR{step} call failed~SN: {e}")
            return None
        self.stats["llm_calls"] += 1
        self.record_model_usage(response, step)
        return "".join(
            getattr(block, "text", "") for block in response.content if getattr(block, "type", "") == "text"
        )

    def record_model_usage(self, response, step):
        usage = getattr(response, "usage", None)
        if not usage:
            return
        server_tool_use = getattr(usage, "server_tool_use", None)
        web_searches = getattr(server_tool_use, "web_search_requests", 0) or 0
        self.stats["web_searches"] += web_searches
        LLMCostTracker.record_usage(
            provider="anthropic",
            model=ANTHROPIC_MODEL,
            feature=FEATURE,
            input_tokens=getattr(usage, "input_tokens", 0) or 0,
            output_tokens=getattr(usage, "output_tokens", 0) or 0,
            user_id=self.user.pk,
            request_id=self.search.request_id,
            metadata={"step": step, "search_id": str(self.search.id), "web_search_requests": web_searches},
        )

    def embed(self, text):
        """Embed a search phrase with the same model that indexed the feeds."""
        client = OpenAI(api_key=settings.OPENAI_API_KEY, timeout=20.0, max_retries=1)
        try:
            response = client.embeddings.create(model=EMBEDDING_MODEL, input=text.lower()[:2000])
        except OpenAIError as e:
            self.stats["model_errors"] += 1
            logging.user(self.user, f"~FBDescribe: ~FRembedding failed~SN for {text[:60]!r}: {e}")
            return None
        self.stats["embeddings"] += 1
        LLMCostTracker.record_embedding(
            model=EMBEDDING_MODEL,
            input_tokens=response.usage.total_tokens,
            feature="describe_query_embedding",
            user_id=self.user.pk,
            request_id=self.search.request_id,
            metadata={"query": text[:100], "search_id": str(self.search.id)},
        )
        return response.data[0].embedding
