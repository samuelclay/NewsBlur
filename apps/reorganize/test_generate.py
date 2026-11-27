"""Tests for apps/reorganize/generate.py, which asks the model for a reorganization of a user's sites.

Every test drives generate_proposal() with a stand-in for the model and real database rows.
"""

import datetime
import json
from unittest.mock import patch

import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase, override_settings

from apps.monitor.models import MLLMCost
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.reorganize import generate, sites
from apps.reorganize.generate import generate_proposal
from apps.reorganize.plan import apply_plan
from apps.reorganize.test_derive import assign, moves_of, target
from apps.rss_feeds.models import Feed, MStory

NO_LOCKS = {"keep": [], "skip": []}

# The dev server shares this Redis and MongoDB, so test sites take ids far above any local feed and
# apart from the ids other test modules use.
FIRST_FEED_ID = 2_000_100_000


def answer(data, stop_reason="end_turn"):
    return {"data": data, "stop_reason": stop_reason, "input_tokens": 100, "output_tokens": 10}


def declined(stop_reason="refusal"):
    return answer(None, stop_reason)


def days_ago(days):
    return datetime.datetime.utcnow() - datetime.timedelta(days=days)


def month_of(date):
    return date.strftime("%Y-%m")


class FakeModel:
    """Stands in for the model. The design call gets design(), each assign call gets assign(feed_ids)
    for the ids of the sites in its batch, and every call is recorded."""

    def __init__(self, design=None, assign=None):
        self.design = design or (lambda: answer({"targets": []}))
        self.assign = assign or (lambda feed_ids: answer({"assignments": []}))
        self.calls = []

    def __call__(self, system, content, schema, effort):
        designs = "targets" in schema["properties"]
        text = "\n".join(block["text"] for block in system) + "\n" + content
        self.calls.append({"designs": designs, "text": text, "content": content})
        if designs:
            return self.design()
        return self.assign([digest["id"] for digest in digests_in(content)])

    def assign_calls(self):
        return [call for call in self.calls if not call["designs"]]

    def digests(self):
        """{feed id: digest} for every site an assign call was sent."""
        return {
            digest["id"]: digest for call in self.assign_calls() for digest in digests_in(call["content"])
        }


def digests_in(content):
    return [json.loads(line) for line in content.splitlines() if line.startswith("{")]


@override_settings(ANTHROPIC_API_KEY="sk-ant-test-" + "k" * 24)
class GenerateTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="organizer", password="test")
        self.next_feed_id = FIRST_FEED_ID
        self.redis = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

        # Cost records land in the shared analytics database, so each test removes the ones it made.
        # The per-day cost counters in Redis are shared with the dev server and are left alone.
        counters = patch("apps.statistics.rllm_costs.RLLMCosts.record")
        counters.start()
        self.addCleanup(counters.stop)
        self.costs_before = set(self.cost_records().scalar("id"))
        self.addCleanup(self.delete_new_cost_records)

    def cost_records(self):
        return MLLMCost.objects(user_id=self.user.pk, feature="reorganize")

    def new_cost_records(self):
        return [record for record in self.cost_records() if record.id not in self.costs_before]

    def delete_new_cost_records(self):
        for record in self.new_cost_records():
            record.delete()

    def add_site(
        self,
        title,
        user_title=None,
        domain=None,
        tagline=None,
        tags=(),
        failing=False,
        active=True,
        created=None,
        stories_last_month=0,
        last_story_date=None,
    ):
        feed_id = self.next_feed_id
        self.next_feed_id += 1
        domain = domain or "site-%s.example.com" % feed_id
        self.addCleanup(self.redis.delete, "F:%s" % feed_id, "zF:%s" % feed_id)
        self.addCleanup(MStory.objects(story_feed_id=feed_id).delete)
        feed = Feed.objects.create(
            pk=feed_id,
            feed_address="https://%s/rss" % domain,
            feed_link="https://%s/" % domain,
            feed_title=title,
            has_feed_exception=failing,
            stories_last_month=stories_last_month,
            last_story_date=last_story_date,
        )
        if created:
            Feed.objects.filter(pk=feed_id).update(creation=created)
        if tagline or tags:
            feed.data.feed_tagline = tagline
            feed.data.popular_tags = json.dumps([list(tag) for tag in tags])
            feed.data.save()
        UserSubscription.objects.create(user=self.user, feed=feed, active=active, user_title=user_title)
        return feed_id

    def add_sites(self, count):
        """`count` plain subscribed sites, made in bulk."""
        feed_ids = list(range(self.next_feed_id, self.next_feed_id + count))
        self.next_feed_id += count
        now = datetime.datetime.utcnow()
        feeds = []
        for feed_id in feed_ids:
            address = "https://bulk-%s.example.com/rss" % feed_id
            link = "https://bulk-%s.example.com/" % feed_id
            feeds.append(
                Feed(
                    pk=feed_id,
                    feed_address=address,
                    feed_link=link,
                    feed_title="Bulk Site %s" % feed_id,
                    hash_address_and_link=Feed.generate_hash_address_and_link(address, link),
                    last_update=now,
                    next_scheduled_update=now,
                )
            )
        Feed.objects.bulk_create(feeds)
        UserSubscription.objects.bulk_create(
            [UserSubscription(user=self.user, feed_id=feed_id, active=True) for feed_id in feed_ids]
        )
        return feed_ids

    def add_story(self, feed_id, title, days):
        MStory(
            story_feed_id=feed_id,
            story_date=days_ago(days),
            story_title=title,
            story_guid="%s-%s" % (feed_id, title),
            story_permalink="https://example.com/%s/%s" % (feed_id, days),
        ).save()

    def set_tree(self, folders):
        UserSubscriptionFolders.objects.update_or_create(
            user=self.user, defaults={"folders": json.dumps(folders)}
        )

    def tree(self):
        return json.loads(UserSubscriptionFolders.objects.get(user=self.user).folders)

    def generate(self, level, model, find_dead=False, instructions="", locks=NO_LOCKS, progress=None):
        return generate_proposal(
            self.user,
            level,
            find_dead,
            instructions,
            locks,
            language="en",
            progress=progress,
            model_call=model,
        )

    def apply_cleanly(self, proposal, locks=NO_LOCKS):
        result = apply_plan(self.tree(), proposal, {}, locks)
        self.assertEqual(result.skipped, [])
        return result


class Test_WhatTheModelSees(GenerateTestCase):
    def test_digest_carries_the_users_title_address_tagline_tags_and_latest_headlines(self):
        site = self.add_site(
            "The Feed's Own Title",
            user_title="My Name For It",
            domain="digest-site.example.com",
            tagline="A tagline that goes on " * 40,
            tags=[("python", 30), ("django", 20), ("web", 9), ("css", 8), ("js", 7), ("rss", 6), ("go", 5)],
        )
        for days, title in ((40, "Oldest story"), (30, "Third newest"), (20, "Second newest")):
            self.add_story(site, title, days)
        self.add_story(site, "Newest " + "word " * 80, 10)
        untitled = self.add_site("A feed title that runs on " * 20)
        self.set_tree([{"Tech": [site, untitled]}])

        model = FakeModel()
        self.generate("tidy", model)

        digests = model.digests()
        digest = digests[site]
        self.assertEqual(digest["title"], "My Name For It")
        self.assertIn("digest-site.example.com", digest["address"])
        self.assertTrue(digest["tagline"].startswith("A tagline that goes on"))
        self.assertLessEqual(len(digest["tagline"]), sites.TAGLINE_LIMIT)
        self.assertEqual(digest["tags"][:2], ["python", "django"])
        self.assertLessEqual(len(digest["tags"]), sites.TAGS_PER_SITE)
        self.assertEqual(digest["headlines"][1:], ["Second newest", "Third newest"])
        self.assertTrue(digest["headlines"][0].startswith("Newest word"))
        self.assertLessEqual(len(digest["headlines"][0]), sites.HEADLINE_LIMIT)
        self.assertEqual(digest["folders"], ["Tech"])

        self.assertTrue(digests[untitled]["title"].startswith("A feed title that runs on"))
        self.assertLessEqual(len(digests[untitled]["title"]), sites.TITLE_LIMIT)
        self.assertFalse(digests[untitled].get("headlines"))

    def test_site_only_in_a_skip_folder_never_reaches_the_model(self):
        hidden = self.add_site("Hidden Diary", domain="hidden-diary.example.com", failing=True)
        self.add_story(hidden, "Hidden headline", 900)
        kept = self.add_site("Kept Journal")
        shown = self.add_site("Shown Blog")
        self.set_tree([{"Secret Stash": [hidden]}, {"Locked Shelf": [kept]}, {"Blogs": [shown]}])
        guarded = {"keep": [["Locked Shelf"]], "skip": [["Secret Stash"]]}
        model = FakeModel(design=lambda: answer({"targets": [target("t1", "Blogs", continues=["e2"])]}))

        result = self.generate("reorganize", model, find_dead=True, locks=guarded)

        self.assertEqual(result["code"], generate.READY)
        everything = "\n".join(call["text"] for call in model.calls)
        for trace in (str(hidden), "Hidden Diary", "hidden-diary", "Hidden headline", "Secret Stash"):
            self.assertNotIn(trace, everything)
        self.assertNotIn("Locked Shelf", everything)
        digests = model.digests()
        self.assertEqual(digests[kept]["folders"], [])
        self.assertEqual(digests[shown]["folders"], ["Blogs"])


class Test_DeadSites(GenerateTestCase):
    def setUp(self):
        super().setUp()
        self.failing_old = self.add_site("Failing Old", failing=True)
        self.add_story(self.failing_old, "Last words", 400)
        # The stored last story date can be stale; the story itself is recent.
        self.failing_recent = self.add_site("Failing Recent", failing=True, last_story_date=days_ago(800))
        self.add_story(self.failing_recent, "Still posting", 30)
        self.failing_ancient = self.add_site("Failing Ancient", failing=True)
        self.add_story(self.failing_ancient, "Long gone", 1000)
        # stories_last_month is only recounted when new stories arrive, so it can be stale too.
        self.quiet = self.add_site("Quiet", stories_last_month=4, last_story_date=days_ago(900))
        self.add_story(self.quiet, "Long ago", 900)
        self.muted = self.add_site("Muted", active=False)
        self.add_story(self.muted, "Muted and old", 900)
        # A feed with no stories gets the current time as its last story date.
        self.never = self.add_site("Never Posted", created=days_ago(1000).date(), last_story_date=days_ago(0))
        self.young = self.add_site("Brand New", created=days_ago(100).date(), last_story_date=days_ago(0))
        self.lively = self.add_site("Lively")
        self.add_story(self.lively, "Fresh enough", 100)
        # Only recent stories stay in Redis, so this site's only evidence is its stored story.
        self.redis.delete("F:%s" % self.lively, "zF:%s" % self.lively)
        self.set_tree(
            [
                {
                    "Everything": [
                        self.failing_old,
                        self.failing_recent,
                        self.failing_ancient,
                        self.quiet,
                        self.muted,
                        self.never,
                        self.young,
                        self.lively,
                    ]
                }
            ]
        )

    def test_dead_sites_are_flagged_by_rule(self):
        result = self.generate("tidy", FakeModel(), find_dead=True)

        flagged = {
            entry["feed_id"]: (entry["cause"], entry["since"], entry["suggest"])
            for entry in result["proposal"]["dead"]
        }
        self.assertEqual(
            flagged,
            {
                self.failing_old: ("failing", month_of(days_ago(400)), "mute"),
                self.failing_ancient: ("failing", month_of(days_ago(1000)), "unsubscribe"),
                self.quiet: ("quiet", month_of(days_ago(900)), "mute"),
                self.never: ("quiet", None, "mute"),
            },
        )
        self.apply_cleanly(result["proposal"])

    def test_nothing_is_flagged_unless_asked(self):
        result = self.generate("tidy", FakeModel(), find_dead=False)

        self.assertEqual(result["proposal"]["dead"], [])


class Test_Levels(GenerateTestCase):
    def test_tidy_files_sites_into_existing_folders_without_a_design_call(self):
        phones = self.add_site("Phones Weekly")
        pasta = self.add_site("Pasta Daily")
        laptops = self.add_site("Laptop News")
        self.set_tree([{"Tech": [phones, pasta]}, {"Cooking": [laptops]}])
        model = FakeModel(
            design=lambda: self.fail("tidy asks for no folder design"),
            assign=lambda feed_ids: answer(
                {"assignments": [assign(pasta, "e1"), assign(laptops, "e0"), assign(phones, "t1")]}
            ),
        )

        result = self.generate("tidy", model)

        self.assertEqual(result["code"], generate.READY)
        proposal = result["proposal"]
        self.assertEqual(proposal["ops"], [])
        self.assertEqual(sorted(moves_of(proposal)), sorted([(pasta, "e0", "e1"), (laptops, "e1", "e0")]))
        self.assertEqual(
            self.apply_cleanly(proposal).folders, [{"Tech": [phones, laptops]}, {"Cooking": [pasta]}]
        )

    def test_reorganize_answer_applies_to_the_tree_it_describes(self):
        laptops = self.add_site("Laptop News")
        phones = self.add_site("Phones Weekly")
        pasta = self.add_site("Pasta Daily")
        apple = self.add_site("Apple Rumors")
        bread = self.add_site("Bread Baking")
        self.set_tree([{"Tech": [laptops, phones]}, {"Food": [pasta]}, {"Misc": [apple, bread]}])
        targets = [
            target("t1", "Technology", continues=["e0"]),
            target("t2", "Cooking", continues=["e1"]),
            target("t3", "Apple", parent="t1"),
        ]
        model = FakeModel(
            design=lambda: answer({"targets": targets}),
            assign=lambda feed_ids: answer(
                {"assignments": [assign(apple, "t3"), assign(phones, "t3"), assign(bread, "t2")]}
            ),
        )

        result = self.generate("reorganize", model)

        self.assertEqual(result["code"], generate.READY)
        self.assertEqual(
            self.apply_cleanly(result["proposal"]).folders,
            [{"Technology": [laptops, {"Apple": [apple, phones]}]}, {"Cooking": [pasta, bread]}],
        )

    def test_no_site_is_moved_to_the_top_level_but_top_level_sites_are_filed(self):
        loose = self.add_site("Loose Site")
        gadgets = self.add_site("Gadget Blog")
        self.set_tree([loose, {"Tech": [gadgets]}])
        for level, folder in (("tidy", "e0"), ("reorganize", "t1"), ("fresh", "t1")):
            model = FakeModel(
                design=lambda: answer({"targets": [target("t1", "Tech", continues=["e0"])]}),
                assign=lambda feed_ids: answer(
                    {"assignments": [assign(gadgets, "root"), assign(loose, folder)]}
                ),
            )

            result = self.generate(level, model)

            self.assertEqual(moves_of(result["proposal"]), [(loose, "root", "e0")])
            self.assertEqual(self.apply_cleanly(result["proposal"]).folders, [{"Tech": [gadgets, loose]}])

    def test_newsletters_folder_is_never_renamed_nested_or_merged_away(self):
        letter = self.add_site("A Newsletter")
        other_letter = self.add_site("Another Newsletter")
        gadgets = self.add_site("Gadget Blog")
        self.set_tree([{"Newsletters": [letter, other_letter]}, {"Tech": [gadgets]}])
        model = FakeModel(
            design=lambda: answer(
                {
                    "targets": [
                        target("t1", "Reading"),
                        target("t2", "Inbox", parent="t1", continues=["e0"]),
                        target("t3", "Tech", continues=["e1", "e0"]),
                    ]
                }
            ),
            assign=lambda feed_ids: answer({"assignments": [assign(letter, "t3")]}),
        )

        result = self.generate("reorganize", model)

        self.assertEqual(result["code"], generate.READY)
        self.assertIn((letter, "e0", "e1"), moves_of(result["proposal"]))
        self.assertEqual(
            self.apply_cleanly(result["proposal"]).folders,
            [{"Newsletters": [other_letter]}, {"Tech": [gadgets, letter]}],
        )


class Test_Batches(GenerateTestCase):
    def setUp(self):
        super().setUp()
        # Five batches: four full ones and one of ten.
        self.site_ids = self.add_sites(4 * generate.ASSIGN_BATCH_SIZE + 10)
        self.set_tree([{"Inbox": self.site_ids}, {"Sorted": []}])

    def answer_batches(self, declines):
        """An assign handler that gives the stop reasons in `declines` to the first batches, in the
        order they are sent, and files every site of every other batch into Sorted."""
        self.sent_batches = []

        def handler(feed_ids):
            self.sent_batches.append(feed_ids)
            if len(self.sent_batches) <= len(declines):
                return declined(declines[len(self.sent_batches) - 1])
            return answer({"assignments": [assign(feed_id, "e1") for feed_id in feed_ids]})

        return handler

    def test_each_site_is_sent_in_exactly_one_batch(self):
        model = FakeModel(assign=self.answer_batches([]))

        self.generate("tidy", model)

        self.assertGreater(len(self.sent_batches), 1)
        sent = [feed_id for batch in self.sent_batches for feed_id in batch]
        self.assertEqual(sorted(sent), sorted(self.site_ids))

    def test_declined_or_cut_off_batches_are_skipped_and_counted(self):
        model = FakeModel(assign=self.answer_batches(["refusal", "max_tokens"]))

        result = self.generate("tidy", model)

        self.assertEqual(result["code"], generate.READY)
        self.assertEqual(result["stats"]["skipped_batches"], 2)
        skipped = set(self.sent_batches[0] + self.sent_batches[1])
        moved = {feed_id for feed_id, _, _ in moves_of(result["proposal"])}
        self.assertEqual(moved, set(self.site_ids) - skipped)

    def test_run_fails_when_more_than_half_the_batches_are_declined(self):
        model = FakeModel(assign=self.answer_batches(["refusal", "refusal", "max_tokens"]))

        result = self.generate("tidy", model)

        self.assertEqual(result, {"code": generate.MODEL_DECLINED})

    def test_one_cost_record_holds_the_tokens_of_every_call(self):
        model = FakeModel(assign=self.answer_batches(["refusal"]))

        self.generate("reorganize", model)

        records = self.new_cost_records()
        self.assertEqual(len(records), 1)
        self.assertEqual((records[0].input_tokens, records[0].output_tokens), (600, 60))
        self.assertEqual(records[0].provider, "anthropic")

    def test_progress_never_goes_backwards_and_ends_at_its_total(self):
        reports = []

        self.generate(
            "reorganize",
            FakeModel(assign=self.answer_batches([])),
            progress=lambda step, done, total: reports.append((done, total)),
        )

        dones = [done for done, _ in reports]
        totals = {total for _, total in reports}
        self.assertEqual(len(totals), 1)
        self.assertEqual(dones, sorted(dones))
        self.assertEqual(dones[-1], totals.pop())
        self.assertGreater(len(reports), 2)


class Test_DesignFailures(GenerateTestCase):
    def setUp(self):
        super().setUp()
        self.gadgets = self.add_site("Gadget Blog")
        self.set_tree([{"Tech": [self.gadgets]}])

    def test_declined_design_fails_the_run(self):
        for stop_reason in ("refusal", "max_tokens"):
            model = FakeModel(design=lambda: declined(stop_reason))

            result = self.generate("reorganize", model)

            self.assertEqual(result, {"code": generate.MODEL_DECLINED})
            self.assertEqual(model.assign_calls(), [])

    def test_failed_design_call_fails_the_run(self):
        model = FakeModel(design=lambda: answer(None, "error"))

        self.assertEqual(self.generate("fresh", model), {"code": generate.MODEL_FAILED})


class Test_MalformedAnswers(GenerateTestCase):
    def setUp(self):
        super().setUp()
        self.gadgets = self.add_site("Gadget Blog")
        self.phones = self.add_site("Phones Weekly")
        self.set_tree([{"Tech": [self.gadgets]}, {"Sorted": [self.phones]}])

    def test_unusable_entries_are_dropped_and_the_rest_applies(self):
        targets = [
            None,
            "t1",
            {"id": 5, "name": "Numbered"},
            {
                "id": "t1",
                "name": "Sorted Stuff",
                "parent": "nowhere",
                "continues": ["e9", None, "e1"],
                "reason": 7,
            },
            {"id": "t1", "name": "Second t1"},
            {"name": "No id"},
        ]
        assignments = [
            None,
            "assign everything",
            {"feed_id": str(self.gadgets), "folder": "t1"},
            {"feed_id": 999_999_999, "folder": "t1"},
            {"feed_id": self.gadgets, "folder": "nowhere"},
            {"feed_id": self.gadgets, "folder": "t1", "reason": ["not", "text"]},
        ]
        model = FakeModel(
            design=lambda: answer({"targets": targets}),
            assign=lambda feed_ids: answer({"assignments": assignments}),
        )

        result = self.generate("reorganize", model)

        self.assertEqual(result["code"], generate.READY)
        self.assertEqual(
            self.apply_cleanly(result["proposal"]).folders, [{"Sorted Stuff": [self.phones, self.gadgets]}]
        )

    def test_answers_of_the_wrong_shape_fail_without_raising(self):
        for data in ({"targets": "everything"}, ["t1"], None, {"folders": []}):
            model = FakeModel(design=lambda: answer(data))
            self.assertEqual(self.generate("reorganize", model), {"code": generate.MODEL_FAILED})

        for data in ({"assignments": {"feed_id": self.gadgets}}, [], None):
            model = FakeModel(assign=lambda feed_ids: answer(data))
            self.assertEqual(self.generate("tidy", model), {"code": generate.MODEL_FAILED})


class Test_NothingToAsk(GenerateTestCase):
    @override_settings(ANTHROPIC_API_KEY="")
    def test_without_an_api_key_the_model_is_never_called(self):
        self.set_tree([{"Tech": [self.add_site("Gadget Blog")]}])
        model = FakeModel()

        self.assertEqual(self.generate("reorganize", model), {"code": generate.NO_API_KEY})
        self.assertEqual(model.calls, [])
        self.assertEqual(self.new_cost_records(), [])

    def test_an_account_with_no_sites_is_not_sent_to_the_model(self):
        self.set_tree([{"Empty": []}])
        model = FakeModel()

        self.assertEqual(self.generate("reorganize", model), {"code": generate.NOTHING_TO_ORGANIZE})
        self.assertEqual(model.calls, [])
