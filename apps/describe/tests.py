"""apps/describe/tests.py: Describe feed search with the LLM, embeddings, ES and web hunt mocked."""

import datetime
import re
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase

from apps.describe.models import (
    HISTORY_LIMIT,
    MAX_RESULTS,
    SOURCE_INDEX,
    SOURCE_WEB,
    STALE_AFTER_SECONDS,
    STATUS_COMPLETE,
    STATUS_ERROR,
    MDescribeSearch,
    MDescribeUsage,
    hydrate_results,
    sort_results,
)
from apps.describe.pipeline import DescribeFeedSearch, parse_json, site_host
from apps.describe.usage import (
    TIER_ARCHIVE,
    TIER_FREE,
    TIER_PREMIUM,
    TIER_PRO,
    DescribeUsageTracker,
)
from apps.rss_feeds.models import Feed
from utils import json_functions as json


def make_user(username, premium=False, archive=False, pro=False):
    user = User.objects.create_user(username=username, email=f"{username}@example.com", password="pw")
    profile = user.profile
    profile.is_premium = premium or archive or pro
    profile.is_archive = archive or pro
    profile.is_pro = pro
    profile.save()
    return user


def make_feed(index, title=None, link=None):
    return Feed.objects.create(
        feed_address=f"https://site{index}.example.com/rss.xml",
        feed_link=link or f"https://site{index}.example.com/",
        feed_title=title or f"Site {index}",
        num_subscribers=5,
    )


def es_hit(feed, similarity):
    return {"_source": {"feed_id": feed.pk}, "_score": 1.0 + similarity}


class DescribeMongoTestCase(TestCase):
    def setUp(self):
        MDescribeSearch.objects.delete()
        MDescribeUsage.objects.delete()

    def tearDown(self):
        MDescribeSearch.objects.delete()
        MDescribeUsage.objects.delete()


class Test_DescribeUsageTracker(DescribeMongoTestCase):
    def test_free_users_are_denied_with_an_upgrade_message(self):
        tracker = DescribeUsageTracker(make_user("free_user"))
        allowed, message = tracker.can_use()
        self.assertFalse(allowed)
        self.assertIn("premium", message.lower())
        self.assertEqual(tracker.plan_tier, TIER_FREE)
        self.assertEqual(tracker.snapshot()["limit"], 0)

    def test_premium_users_get_ten_searches_a_day(self):
        tracker = DescribeUsageTracker(make_user("premium_user", premium=True))
        self.assertEqual(tracker.plan_tier, TIER_PREMIUM)
        for _ in range(10):
            self.assertTrue(tracker.can_use()[0])
            tracker.record_usage(search_id="abc", request_id="req")
        allowed, message = tracker.can_use()
        self.assertFalse(allowed)
        self.assertIn("10", message)
        self.assertEqual(tracker.snapshot()["remaining"], 0)

    def test_denied_attempts_do_not_count_against_the_quota(self):
        tracker = DescribeUsageTracker(make_user("premium_denied", premium=True))
        tracker.record_denied(search_id="abc", request_id="req")
        self.assertEqual(tracker.daily_count(), 0)

    def test_archive_and_pro_tiers(self):
        archive = DescribeUsageTracker(make_user("archive_user", archive=True))
        self.assertEqual(archive.plan_tier, TIER_ARCHIVE)
        self.assertEqual(archive.daily_limit, 30)
        pro = DescribeUsageTracker(make_user("pro_user", pro=True))
        self.assertEqual(pro.plan_tier, TIER_PRO)
        self.assertEqual(pro.daily_limit, 100)
        self.assertTrue(pro.can_use()[0])
        self.assertEqual(pro.snapshot()["remaining"], 100)

    def test_pro_users_stop_at_the_sanity_limit(self):
        tracker = DescribeUsageTracker(make_user("pro_heavy", pro=True))
        for index in range(100):
            tracker.record_usage(search_id=str(index), request_id=f"req-{index}")
        allowed, message = tracker.can_use()
        self.assertFalse(allowed)
        self.assertIn("100", message)

    def test_usage_message_only_when_running_low(self):
        tracker = DescribeUsageTracker(make_user("premium_low", premium=True))
        self.assertIsNone(tracker.get_usage_message())
        for _ in range(8):
            tracker.record_usage()
        self.assertIn("2", tracker.get_usage_message())


class Test_DescribeSearchHistory(DescribeMongoTestCase):
    def test_history_is_capped_at_the_limit(self):
        user = make_user("history_user", premium=True)
        for index in range(HISTORY_LIMIT + 5):
            MDescribeSearch.start(user.pk, f"prompt {index}", f"request-{index:03d}")
        self.assertEqual(MDescribeSearch.objects(user_id=user.pk).count(), HISTORY_LIMIT)
        prompts = [search["prompt"] for search in MDescribeSearch.history_for_user(user.pk)]
        self.assertEqual(prompts[0], f"prompt {HISTORY_LIMIT + 4}")
        self.assertNotIn("prompt 0", prompts)

    def test_rerun_replaces_the_entry_in_place(self):
        user = make_user("rerun_user", premium=True)
        first = MDescribeSearch.start(user.pk, "ios app reviews", "request-0001")
        first.results = [{"feed_id": 1, "judged": True, "score": 9}]
        first.mark_complete()
        MDescribeSearch.start(user.pk, "other prompt", "request-0002")

        rerun = MDescribeSearch.start(user.pk, "ios app reviews", "request-0003", search_id=str(first.id))
        self.assertEqual(rerun.id, first.id)
        self.assertEqual(rerun.results, [])
        self.assertEqual(rerun.status, "queued")
        self.assertEqual(MDescribeSearch.objects(user_id=user.pk).count(), 2)
        self.assertEqual(MDescribeSearch.history_for_user(user.pk)[0]["id"], str(first.id))

    def test_for_user_rejects_other_users_and_bad_ids(self):
        owner = make_user("owner_user", premium=True)
        other = make_user("other_user", premium=True)
        search = MDescribeSearch.start(owner.pk, "prompt", "request-0001")
        self.assertIsNone(MDescribeSearch.for_user(other.pk, str(search.id)))
        self.assertIsNone(MDescribeSearch.for_user(owner.pk, "not-an-id"))
        self.assertIsNotNone(MDescribeSearch.for_user(owner.pk, str(search.id)))

    def test_sort_results_puts_judged_feeds_first_by_score(self):
        rows = [
            {"feed_id": 1, "judged": False, "score": None, "similarity": 0.9},
            {"feed_id": 2, "judged": True, "score": 6, "similarity": 0.2},
            {"feed_id": 3, "judged": True, "score": 9, "similarity": 0.1},
            {"feed_id": 4, "judged": False, "score": None, "similarity": 0.5},
        ]
        self.assertEqual([row["feed_id"] for row in sort_results(rows)], [3, 2, 1, 4])


class Test_DescribeViews(DescribeMongoTestCase):
    def setUp(self):
        super().setUp()
        self.user = make_user("views_user", premium=True)
        self.client.login(username="views_user", password="pw")

    @patch("apps.describe.views.DescribeFeedsSearch.apply_async")
    def test_start_creates_a_search_and_queues_the_task(self, apply_async):
        response = self.client.post("/discover/describe/start", {"prompt": "  reviews of   iOS apps "})
        payload = json.decode(response.content)
        self.assertEqual(payload["code"], 1)
        self.assertEqual(payload["search"]["prompt"], "reviews of iOS apps")
        self.assertEqual(payload["search"]["status"], "queued")
        self.assertEqual(payload["usage"]["remaining"], 9)
        apply_async.assert_called_once()
        self.assertEqual(apply_async.call_args.kwargs["queue"], "work_queue")
        self.assertEqual(apply_async.call_args.kwargs["kwargs"]["search_id"], payload["search"]["id"])

    @patch("apps.describe.views.DescribeFeedsSearch.apply_async")
    def test_start_rejects_short_and_long_prompts(self, apply_async):
        short = json.decode(self.client.post("/discover/describe/start", {"prompt": "io"}).content)
        self.assertEqual(short["code"], -1)
        long = json.decode(self.client.post("/discover/describe/start", {"prompt": "x" * 501}).content)
        self.assertEqual(long["code"], -1)
        apply_async.assert_not_called()

    @patch("apps.describe.views.DescribeFeedsSearch.apply_async")
    def test_free_users_are_told_to_upgrade(self, apply_async):
        self.client.logout()
        make_user("free_views_user")
        self.client.login(username="free_views_user", password="pw")
        payload = json.decode(
            self.client.post("/discover/describe/start", {"prompt": "ios app reviews"}).content
        )
        self.assertEqual(payload["code"], -1)
        self.assertTrue(payload["upgrade"])
        apply_async.assert_not_called()

    @patch("apps.describe.views.DescribeFeedsSearch.apply_async")
    def test_status_history_and_delete(self, apply_async):
        started = json.decode(
            self.client.post("/discover/describe/start", {"prompt": "ios app reviews"}).content
        )
        search_id = started["search"]["id"]

        status = json.decode(self.client.get("/discover/describe/status", {"search_id": search_id}).content)
        self.assertEqual(status["code"], 1)
        self.assertEqual(status["search"]["id"], search_id)
        self.assertEqual(status["search"]["results"], [])

        history = json.decode(self.client.get("/discover/describe/history").content)
        self.assertEqual([search["id"] for search in history["searches"]], [search_id])
        self.assertEqual(history["usage"]["tier"], TIER_PREMIUM)

        deleted = json.decode(self.client.post("/discover/describe/delete", {"search_id": search_id}).content)
        self.assertEqual(deleted["code"], 1)
        self.assertEqual(deleted["searches"], [])
        missing = json.decode(self.client.get("/discover/describe/status", {"search_id": search_id}).content)
        self.assertEqual(missing["code"], -1)

    @patch("apps.describe.views.DescribeFeedsSearch.apply_async")
    def test_rerun_keeps_one_history_entry(self, apply_async):
        started = json.decode(
            self.client.post("/discover/describe/start", {"prompt": "ios app reviews"}).content
        )
        search_id = started["search"]["id"]
        MDescribeSearch.for_user(self.user.pk, search_id).mark_complete()
        rerun = json.decode(
            self.client.post(
                "/discover/describe/start", {"prompt": "ios app reviews", "search_id": search_id}
            ).content
        )
        self.assertEqual(rerun["search"]["id"], search_id)
        history = json.decode(self.client.get("/discover/describe/history").content)
        self.assertEqual(len(history["searches"]), 1)
        self.assertEqual(apply_async.call_count, 2)

    @patch("apps.describe.views.DescribeFeedsSearch.apply_async")
    def test_rerun_is_refused_while_the_search_is_running(self, apply_async):
        started = json.decode(
            self.client.post("/discover/describe/start", {"prompt": "ios app reviews"}).content
        )
        search_id = started["search"]["id"]
        rerun = json.decode(
            self.client.post(
                "/discover/describe/start", {"prompt": "ios app reviews", "search_id": search_id}
            ).content
        )
        self.assertEqual(rerun["code"], -1)
        self.assertIn("still running", rerun["message"])
        self.assertEqual(apply_async.call_count, 1)

        MDescribeSearch.for_user(self.user.pk, search_id).mark_complete()
        rerun = json.decode(
            self.client.post(
                "/discover/describe/start", {"prompt": "ios app reviews", "search_id": search_id}
            ).content
        )
        self.assertEqual(rerun["code"], 1)
        self.assertEqual(apply_async.call_count, 2)

    def test_deleted_search_is_not_resurrected_by_a_running_pipeline(self):
        search = MDescribeSearch.start(self.user.pk, "ios app reviews", "request-0001")
        search.delete()
        search.mark_phase("judging", "Judging 3 feeds")
        self.assertIsNone(MDescribeSearch.for_user(self.user.pk, str(search.id)))

    def test_other_users_searches_are_invisible(self):
        other = make_user("other_views_user", premium=True)
        search = MDescribeSearch.start(other.pk, "their prompt", "request-0001")
        status = json.decode(
            self.client.get("/discover/describe/status", {"search_id": str(search.id)}).content
        )
        self.assertEqual(status["code"], -1)
        deleted = json.decode(
            self.client.post("/discover/describe/delete", {"search_id": str(search.id)}).content
        )
        self.assertEqual(deleted["code"], -1)
        self.assertEqual(MDescribeSearch.objects(user_id=other.pk).count(), 1)


class Test_DescribePipeline(DescribeMongoTestCase):
    """The pipeline with every external call replaced: Claude, embeddings, ES and the web hunt."""

    def setUp(self):
        super().setUp()
        self.user = make_user("pipeline_user", premium=True)
        self.feeds = [make_feed(index) for index in range(1, 5)]
        self.web_feed = make_feed(9, title="Web Found Weekly", link="https://webfound.example.com/")
        self.search = MDescribeSearch.start(
            self.user.pk, "reviews of iOS apps with screenshots", "request-0001"
        )
        self.events = []
        self.pipeline = DescribeFeedSearch(self.search, self.user, publish=self.capture)
        self.stories_patch = patch.object(
            Feed,
            "get_stories",
            lambda feed, limit=25, **kwargs: [
                {
                    "story_title": f"{feed.feed_title} headline",
                    "story_permalink": feed.feed_link,
                    "story_date": datetime.datetime(2026, 11, 1, 9, 0),
                    "story_content": f'<p><img src="{feed.feed_link}shot.png"> {feed.feed_title} <b>body</b> &amp; more</p>',
                    "image_urls": [],
                }
            ],
        )
        self.stories_patch.start()

    def tearDown(self):
        self.stories_patch.stop()
        super().tearDown()

    def capture(self, event_type, extra=None):
        self.events.append((event_type, extra or {}))

    def events_of(self, event_type):
        return [extra for name, extra in self.events if name == event_type]

    def fake_call_model(self, system, user_text, max_tokens, step, tools=None):
        if step == "expand":
            return '{"sub_queries": ["iOS app reviews", "iPhone app roundups", "iOS app reviews"]}'
        if step == "judge":
            verdicts = []
            for feed in self.feeds + [self.web_feed]:
                if f"feed_id={feed.pk}" not in user_text:
                    continue
                score = {1: 9, 2: 7, 3: 1, 4: 5}.get(
                    self.feeds.index(feed) + 1 if feed in self.feeds else 0, 8
                )
                verdicts.append({"feed_id": feed.pk, "score": score, "reason": f"{feed.feed_title} matches"})
            return json.encode(verdicts)
        if step == "hunt":
            self.assertIsNotNone(tools)
            return json.encode(
                [{"url": "https://webfound.example.com/", "title": "Web Found Weekly", "why": "found"}]
            )
        self.fail(f"unexpected step {step}")

    def fake_preview_site(self, url):
        return {"feed": self.web_feed}

    def run_pipeline(self):
        hits_by_query = {
            "reviews of ios apps with screenshots": [es_hit(self.feeds[0], 0.8), es_hit(self.feeds[1], 0.7)],
            "ios app reviews": [es_hit(self.feeds[2], 0.6), es_hit(self.feeds[0], 0.9)],
            "iphone app roundups": [es_hit(self.feeds[3], 0.5)],
        }
        embedded = []

        def fake_embed(text):
            embedded.append(text.lower())
            return [0.1] * 4

        def fake_vector_query(vector, max_results=10, feed_ids_to_exclude=None, offset=0):
            return hits_by_query.get(embedded[-1], [])

        with patch.object(self.pipeline, "call_model", side_effect=self.fake_call_model), patch.object(
            self.pipeline, "embed", side_effect=fake_embed
        ), patch("apps.describe.pipeline.SearchFeed.vector_query", side_effect=fake_vector_query), patch(
            "apps.describe.pipeline.preview_site", side_effect=self.fake_preview_site
        ) as resolve:
            self.pipeline.run()
        return embedded, resolve

    def test_full_run_streams_candidates_verdicts_and_web_finds(self):
        embedded, resolve = self.run_pipeline()

        self.search.reload()
        self.assertEqual(self.search.status, STATUS_COMPLETE)
        self.assertEqual(self.search.sub_queries, ["iOS app reviews", "iPhone app roundups"])
        self.assertEqual(
            embedded, ["reviews of ios apps with screenshots", "ios app reviews", "iphone app roundups"]
        )

        # Feed 3 scored 1 and was pruned; the rest are ordered by judge score, web find included.
        ordered = [(row["feed_id"], row["source"], row["score"]) for row in self.search.results]
        self.assertEqual(
            ordered,
            [
                (self.feeds[0].pk, SOURCE_INDEX, 9),
                (self.web_feed.pk, SOURCE_WEB, 8),
                (self.feeds[1].pk, SOURCE_INDEX, 7),
                (self.feeds[3].pk, SOURCE_INDEX, 5),
            ],
        )
        self.assertTrue(all(row["judged"] for row in self.search.results))
        self.assertEqual(self.search.results[0]["reason"], "Site 1 matches")
        self.assertEqual(self.search.results[0]["stories"][0]["story_title"], "Site 1 headline")
        self.assertEqual(self.search.results[0]["stories"][0]["story_date"], "2026-11-01T09:00:00")
        # The shared Add Site card draws an image, the title and a text preview from these keys.
        story = self.search.results[0]["stories"][0]
        self.assertEqual(story["image_urls"], ["https://site1.example.com/shot.png"])
        self.assertEqual(story["story_content"], "Site 1 body &amp; more")

        resolve.assert_called_once()
        self.assertEqual(resolve.call_args.args[0], "https://webfound.example.com/")
        self.assertEqual(self.search.stats["web_feeds_added"], 1)
        self.assertEqual(self.search.stats["candidates_considered"], 4)

        phases = [extra["phase"] for extra in self.events_of("phase")]
        self.assertEqual(phases[:4], ["expanding", "searching", "judging", "hunting"])
        self.assertEqual(
            self.events_of("queries")[0]["sub_queries"], ["iOS app reviews", "iPhone app roundups"]
        )

        # Candidates stream per query, deduped: 2 from the prompt, 1 new from each sub-query, 1 from the web.
        candidate_batches = [
            [row["feed_id"] for row in extra["results"]] for extra in self.events_of("candidates")
        ]
        self.assertEqual(
            candidate_batches,
            [
                [self.feeds[0].pk, self.feeds[1].pk],
                [self.feeds[2].pk],
                [self.feeds[3].pk],
                [self.web_feed.pk],
            ],
        )
        self.assertEqual(self.events_of("candidates")[0]["results"][0]["feed"]["feed_title"], "Site 1")
        self.assertIn(self.feeds[2].pk, self.events_of("remove")[0]["feed_ids"])
        complete = self.events_of("complete")[0]
        self.assertEqual(complete["result_count"], 4)
        self.assertEqual(complete["order"][0], self.feeds[0].pk)

    def test_model_failures_fall_back_without_ending_the_search(self):
        with patch.object(self.pipeline, "call_model", return_value=None), patch.object(
            self.pipeline, "embed", return_value=[0.1] * 4
        ), patch(
            "apps.describe.pipeline.SearchFeed.vector_query", return_value=[es_hit(self.feeds[0], 0.8)]
        ), patch(
            "apps.describe.pipeline.preview_site"
        ) as resolve:
            self.pipeline.run()

        self.search.reload()
        self.assertEqual(self.search.status, STATUS_COMPLETE)
        self.assertEqual(self.search.sub_queries, ["reviews of iOS apps with screenshots"])
        self.assertEqual([row["feed_id"] for row in self.search.results], [self.feeds[0].pk])
        self.assertFalse(self.search.results[0]["judged"])
        resolve.assert_not_called()

    def test_results_are_capped_at_max_results(self):
        many_feeds = [make_feed(100 + index) for index in range(MAX_RESULTS + 6)]
        hits = [es_hit(feed, 0.9 - index * 0.01) for index, feed in enumerate(many_feeds)]
        self.pipeline.CANDIDATES_PER_QUERY = len(hits)

        def judge_everything(system, user_text, max_tokens, step, tools=None):
            if step == "expand":
                return '{"sub_queries": []}'
            if step == "judge":
                return json.encode(
                    [
                        {"feed_id": feed.pk, "score": 8, "reason": "fine"}
                        for feed in many_feeds
                        if f"feed_id={feed.pk}" in user_text
                    ]
                )
            return "[]"

        with patch.object(self.pipeline, "call_model", side_effect=judge_everything), patch.object(
            self.pipeline, "embed", return_value=[0.1] * 4
        ), patch("apps.describe.pipeline.SearchFeed.vector_query", return_value=hits):
            self.pipeline.run()

        self.search.reload()
        self.assertEqual(len(self.search.results), MAX_RESULTS)
        removed = [feed_id for extra in self.events_of("remove") for feed_id in extra["feed_ids"]]
        self.assertEqual(len(removed), 6)


class Test_DescribeWebHunt(Test_DescribePipeline):
    """The web hunt must never create feeds, and one bad site must never end a search."""

    UNSAVED = {
        "feed": None,
        "feed_address": "https://brandnew.example.com/feed.xml",
        "feed_title": "Brand New Blog",
        "feed_link": "https://brandnew.example.com/",
        "tagline": "Fresh writing",
        "stories": [
            {
                "story_title": "Hello world",
                "story_permalink": "https://brandnew.example.com/hello",
                "story_date": datetime.datetime(2026, 11, 2, 8, 0),
            }
        ],
    }

    def hunt_call_model(self, sites):
        def call_model(system, user_text, max_tokens, step, tools=None):
            if step == "expand":
                return '{"sub_queries": []}'
            if step == "judge":
                ids = [int(found) for found in re.findall(r"feed_id=(-?\d+)", user_text)]
                return json.encode([{"feed_id": feed_id, "score": 8, "reason": "fits"} for feed_id in ids])
            return json.encode([{"url": url, "title": url, "why": "found"} for url in sites])

        return call_model

    def run_hunt(self, sites, preview):
        with patch.object(self.pipeline, "call_model", side_effect=self.hunt_call_model(sites)), patch.object(
            self.pipeline, "embed", return_value=[0.1] * 4
        ), patch(
            "apps.describe.pipeline.SearchFeed.vector_query", return_value=[es_hit(self.feeds[0], 0.8)]
        ), patch(
            "apps.describe.pipeline.preview_site", side_effect=preview
        ):
            self.pipeline.run()
        self.search.reload()

    def test_a_site_newsblur_has_never_seen_is_shown_without_creating_a_feed(self):
        feeds_before = Feed.objects.count()
        self.run_hunt(["https://brandnew.example.com/"], lambda url: dict(self.UNSAVED))

        self.assertEqual(Feed.objects.count(), feeds_before)
        self.assertEqual(self.search.status, STATUS_COMPLETE)
        web_rows = [row for row in self.search.results if row["source"] == SOURCE_WEB]
        self.assertEqual(len(web_rows), 1)
        row = web_rows[0]
        self.assertLess(row["feed_id"], 0)
        self.assertTrue(row["judged"])
        self.assertEqual(row["score"], 8)
        self.assertEqual(row["feed_address"], "https://brandnew.example.com/feed.xml")
        self.assertEqual(row["stories"][0]["story_title"], "Hello world")

        hydrated = [
            item for item in hydrate_results(self.search.results) if item["feed_id"] == row["feed_id"]
        ][0]
        self.assertEqual(hydrated["feed"]["feed_title"], "Brand New Blog")
        self.assertEqual(hydrated["feed"]["feed_address"], "https://brandnew.example.com/feed.xml")
        self.assertNotIn("id", hydrated["feed"])

    def test_an_unsaved_find_picks_up_the_real_feed_once_someone_subscribes(self):
        self.run_hunt(["https://brandnew.example.com/"], lambda url: dict(self.UNSAVED))
        created = Feed.objects.create(
            feed_address="https://brandnew.example.com/feed.xml",
            feed_link="https://brandnew.example.com/",
            feed_title="Brand New Blog",
        )
        row = [item for item in hydrate_results(self.search.results) if item["source"] == SOURCE_WEB][0]
        self.assertLess(row["feed_id"], 0)
        self.assertEqual(row["feed"]["id"], created.pk)

    def test_a_site_that_blows_up_is_skipped_and_the_search_finishes(self):
        def preview(url):
            if "broken" in url:
                raise RuntimeError("feedparser choked on this one")
            return dict(self.UNSAVED)

        self.run_hunt(["https://broken.example.com/", "https://brandnew.example.com/"], preview)

        self.assertEqual(self.search.status, STATUS_COMPLETE)
        self.assertEqual(self.search.stats["web_errors"], 1)
        self.assertEqual(self.search.stats["web_feeds_added"], 1)
        self.assertEqual(len(self.search.results), 2)

    def test_a_failed_hunt_keeps_the_feeds_already_found(self):
        with patch.object(self.pipeline, "call_model", side_effect=self.hunt_call_model([])), patch.object(
            self.pipeline, "embed", return_value=[0.1] * 4
        ), patch(
            "apps.describe.pipeline.SearchFeed.vector_query", return_value=[es_hit(self.feeds[0], 0.8)]
        ), patch.object(
            self.pipeline, "hunt_web", side_effect=RuntimeError("hunt fell over")
        ):
            self.pipeline.run()
        self.search.reload()
        self.assertEqual(self.search.status, STATUS_COMPLETE)
        self.assertEqual([row["feed_id"] for row in self.search.results], [self.feeds[0].pk])


class Test_DescribeWebPreview(TestCase):
    """apps/describe/web_preview.py reads a site once and writes nothing."""

    FEED_XML = b"""<?xml version="1.0"?><rss version="2.0"><channel>
        <title>Brand New Blog</title><link>https://brandnew.example.com/</link>
        <description>Fresh writing</description>
        <item><title>Hello world</title><link>https://brandnew.example.com/hello</link>
        <pubDate>Mon, 02 Nov 2026 08:00:00 GMT</pubDate><description>Hello body</description>
        <enclosure url="https://brandnew.example.com/hello.jpg" type="image/jpeg" length="1"/></item>
        <item><title>Second post</title><link>https://brandnew.example.com/second</link></item>
        </channel></rss>"""

    def preview(self, url, addresses, content=None, status_code=200):
        from apps.describe import web_preview

        response = type("Response", (), {"status_code": status_code, "content": content or self.FEED_XML})()
        with patch.object(web_preview, "validate_public_url"), patch.object(
            web_preview, "find_feed_addresses", return_value=addresses
        ), patch.object(web_preview, "safe_requests_get", return_value=response) as fetch:
            return web_preview.preview_site(url), fetch

    def test_an_unknown_site_is_read_without_creating_a_feed(self):
        feeds_before = Feed.objects.count()
        preview, fetch = self.preview(
            "https://brandnew.example.com/", ["https://brandnew.example.com/feed.xml"]
        )

        self.assertEqual(Feed.objects.count(), feeds_before)
        self.assertIsNone(preview["feed"])
        self.assertEqual(preview["feed_address"], "https://brandnew.example.com/feed.xml")
        self.assertEqual(preview["feed_title"], "Brand New Blog")
        self.assertEqual(preview["tagline"], "Fresh writing")
        self.assertEqual(
            [story["story_title"] for story in preview["stories"]], ["Hello world", "Second post"]
        )
        self.assertEqual(preview["stories"][0]["story_date"], datetime.datetime(2026, 11, 2, 8, 0))
        self.assertIsNone(preview["stories"][1]["story_date"])
        self.assertIn("Hello body", preview["stories"][0]["story_content"])
        self.assertEqual(preview["stories"][0]["image_urls"], ["https://brandnew.example.com/hello.jpg"])

    def test_a_feed_newsblur_already_has_is_returned_without_fetching(self):
        feed = make_feed(50)
        preview, fetch = self.preview("https://site50.example.com/", [feed.feed_address])
        self.assertEqual(preview, {"feed": feed})
        fetch.assert_not_called()

    def test_sites_without_a_readable_feed_are_skipped(self):
        self.assertIsNone(self.preview("https://nofeed.example.com/", [])[0])
        address = ["https://gone.example.com/feed.xml"]
        self.assertIsNone(self.preview("https://gone.example.com/", address, status_code=404)[0])
        self.assertIsNone(
            self.preview("https://gone.example.com/", address, content=b"<html>not a feed</html>")[0]
        )


class Test_DescribeStuckSearches(DescribeMongoTestCase):
    """A search whose task died must not stay running forever."""

    def setUp(self):
        super().setUp()
        self.user = make_user("stuck_user", premium=True)
        self.client.login(username="stuck_user", password="pw")

    def start(self, prompt="ios app reviews", **extra):
        return json.decode(self.client.post("/discover/describe/start", dict(prompt=prompt, **extra)).content)

    def age(self, search_id, seconds):
        MDescribeSearch.objects(id=search_id).update_one(
            set__updated_date=datetime.datetime.now() - datetime.timedelta(seconds=seconds)
        )

    @patch("apps.describe.views.DescribeFeedsSearch.apply_async")
    def test_only_one_search_runs_at_a_time(self, apply_async):
        first = self.start()
        second = self.start(prompt="long essays about cities")
        self.assertEqual(second["code"], -1)
        self.assertIn("already", second["message"])
        self.assertEqual(apply_async.call_count, 1)
        self.assertEqual(DescribeUsageTracker(self.user).daily_count(), 1)

        MDescribeSearch.for_user(self.user.pk, first["search"]["id"]).mark_complete()
        self.assertEqual(self.start(prompt="long essays about cities")["code"], 1)

    @patch("apps.describe.views.DescribeFeedsSearch.apply_async")
    def test_a_search_that_went_quiet_is_marked_failed_and_refunded(self, apply_async):
        search_id = self.start()["search"]["id"]
        self.assertEqual(DescribeUsageTracker(self.user).daily_count(), 1)

        self.age(search_id, STALE_AFTER_SECONDS - 30)
        status = json.decode(self.client.get("/discover/describe/status", {"search_id": search_id}).content)
        self.assertEqual(status["search"]["status"], "queued")

        self.age(search_id, STALE_AFTER_SECONDS + 30)
        status = json.decode(self.client.get("/discover/describe/status", {"search_id": search_id}).content)
        self.assertEqual(status["search"]["status"], STATUS_ERROR)
        self.assertTrue(status["search"]["error"])
        history = json.decode(self.client.get("/discover/describe/history").content)
        self.assertEqual(history["searches"][0]["status"], STATUS_ERROR)
        self.assertEqual(DescribeUsageTracker(self.user).daily_count(), 0)

        rerun = self.start(search_id=search_id)
        self.assertEqual(rerun["code"], 1)
        self.assertEqual(apply_async.call_count, 2)

    @patch("apps.describe.views.DescribeFeedsSearch.apply_async")
    def test_a_stuck_search_does_not_block_a_new_one(self, apply_async):
        search_id = self.start()["search"]["id"]
        self.age(search_id, STALE_AFTER_SECONDS + 30)
        self.assertEqual(self.start(prompt="long essays about cities")["code"], 1)

    @patch("apps.describe.tasks.DescribeFeedSearch")
    def test_a_task_arriving_after_its_search_expired_does_not_run(self, pipeline_class):
        from apps.describe.tasks import DescribeFeedsSearch

        search = MDescribeSearch.start(self.user.pk, "ios app reviews", "request-0001")
        self.age(search.id, STALE_AFTER_SECONDS + 30)
        result = DescribeFeedsSearch(self.user.pk, str(search.id), request_id="request-0001")
        self.assertEqual(result["code"], -1)
        pipeline_class.assert_not_called()

    def test_a_search_that_errors_is_refunded(self):
        tracker = DescribeUsageTracker(self.user)
        search = MDescribeSearch.start(self.user.pk, "ios app reviews", "request-0001")
        tracker.record_usage(search_id=search.id, request_id="request-0001")
        search.mark_error("boom")
        self.assertEqual(tracker.daily_count(), 0)


class Test_DescribeTask(DescribeMongoTestCase):
    @patch("apps.describe.tasks.DescribeFeedSearch")
    def test_stale_task_does_not_run_a_replaced_search(self, pipeline_class):
        from apps.describe.tasks import DescribeFeedsSearch

        user = make_user("task_user", premium=True)
        search = MDescribeSearch.start(user.pk, "ios app reviews", "request-0001")
        MDescribeSearch.start(user.pk, "ios app reviews", "request-0002", search_id=str(search.id))
        result = DescribeFeedsSearch(user.pk, str(search.id), request_id="request-0001")
        self.assertEqual(result["code"], -1)
        pipeline_class.assert_not_called()


class Test_DescribeHelpers(TestCase):
    def test_parse_json_tolerates_fences_and_prose(self):
        self.assertEqual(parse_json('```json\n{"a": 1}\n```'), {"a": 1})
        self.assertEqual(parse_json('Here you go: [{"feed_id": 1}] hope it helps'), [{"feed_id": 1}])
        self.assertIsNone(parse_json("no json here"))
        self.assertIsNone(parse_json(None))

    def test_site_host_strips_www(self):
        self.assertEqual(site_host("https://www.example.com/path"), "example.com")
        self.assertEqual(site_host("https://blog.example.com/"), "blog.example.com")
        self.assertEqual(site_host("not a url"), "")
