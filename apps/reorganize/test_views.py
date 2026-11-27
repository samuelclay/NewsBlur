"""Tests for apps/reorganize/views.py, the endpoints the Organize sites dialog calls, and for the
revisions apps/reorganize/tasks.py makes through them.

Every test drives the endpoints with Django's test client. As in apps/reorganize/test_tasks.py, the
model is replaced at call_model() in apps/reorganize/generate.py and queued runs are run in this
process, so the real generate_proposal(), apply and undo run behind every response.
"""

import datetime
import json
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase, override_settings

from apps.monitor.models import MLLMCost
from apps.profile.models import Profile
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.reorganize import generate, usage
from apps.reorganize.models import MReorganizeLocks, MReorganizeProposal
from apps.reorganize.tasks import GenerateReorganizeProposal
from apps.reorganize.test_derive import assign, target
from apps.reorganize.test_generate import FakeModel, answer, declined
from apps.rss_feeds.models import Feed

# The dev server shares this Redis and MongoDB, so test sites take ids far above any local feed and
# apart from the ids other test modules use.
FIRST_FEED_ID = 2_000_300_000

NO_DECISIONS = {"ops": {}, "moves": {}, "dead": {}}

# The keys of the model's raw answer and of a proposal's undo snapshot.
PRIVATE_KEYS = {"answer", "targets", "assignments", "undo", "carried", "muted_feed_ids"}


def move_id(summary, feed_id):
    return next(entry["id"] for entry in summary["proposal"]["moves"] if entry["feed_id"] == feed_id)


def op_id(summary, op_type):
    return next(entry["id"] for entry in summary["proposal"]["ops"] if entry["type"] == op_type)


def all_keys(value):
    """Every dict key anywhere inside a decoded JSON value."""
    if isinstance(value, dict):
        return set(value).union(*(all_keys(item) for item in value.values()))
    if isinstance(value, list):
        return set().union(*(all_keys(item) for item in value))
    return set()


def earlier_design(call):
    """{target id: entry} for the earlier design a revision's design call was sent."""
    block = call["content"].split("<earlier_design>\n", 1)[1].split("\n</earlier_design>", 1)[0]
    return {entry["id"]: entry for entry in map(json.loads, block.splitlines())}


@override_settings(ANTHROPIC_API_KEY="sk-ant-test-" + "k" * 24)
class ViewsTestCase(TestCase):
    def setUp(self):
        self.user = self.make_user("reorganize_views_test")
        self.set_plan(self.user, archive=True)
        self.client.force_login(self.user)
        # Sessions live in the Redis the dev server shares, and logging out deletes this one.
        self.addCleanup(self.client.logout)

        self.next_feed_id = FIRST_FEED_ID
        self.gadgets = self.add_site("Gadget Blog")
        self.phones = self.add_site("Phones Weekly")
        self.laptops = self.add_site("Laptop News")
        self.notes = self.add_site("Field Notes")
        self.set_tree([{"Tech": [self.gadgets, self.phones, self.laptops]}, {"Sorted": [self.notes]}])

        # Gadget Blog moves to Sorted, and Phones Weekly to a new Handsets folder.
        self.targets = [
            target("t1", "Tech", continues=["e0"]),
            target("t2", "Sorted", continues=["e1"]),
            target("t3", "Handsets"),
        ]
        self.assignments = [assign(self.gadgets, "t2"), assign(self.phones, "t3")]
        self.model = FakeModel(
            design=lambda: answer({"targets": self.targets}),
            assign=lambda feed_ids: answer(
                {"assignments": [entry for entry in self.assignments if entry["feed_id"] in feed_ids]}
            ),
        )
        model_call = patch.object(generate, "call_model", self.model)
        model_call.start()
        self.addCleanup(model_call.stop)

        # Queued runs wait here until the test runs them in this process.
        self.queued = []
        queue = patch.object(
            GenerateReorganizeProposal,
            "apply_async",
            side_effect=lambda kwargs=None, **options: self.queued.append(kwargs),
        )
        queue.start()
        self.addCleanup(queue.stop)

        # Cost records land in the shared analytics database, so each test removes the ones it made.
        # The per-day cost counters in Redis are shared with the dev server and are left alone.
        counters = patch("apps.statistics.rllm_costs.RLLMCosts.record")
        counters.start()
        self.addCleanup(counters.stop)
        self.costs_before = set(self.cost_records().scalar("id"))
        self.addCleanup(self.delete_new_cost_records)

    def make_user(self, username):
        user = User.objects.create_user(username=username, password="test")
        for model in (MReorganizeProposal, MReorganizeLocks):
            model.objects(user_id=user.pk).delete()
            self.addCleanup(model.objects(user_id=user.pk).delete)
        return user

    def set_plan(self, user, archive):
        Profile.objects.filter(user=user).update(
            is_premium=archive, is_archive=archive, is_pro=False, timezone="America/New_York"
        )
        if user.pk == self.user.pk:
            self.user = User.objects.get(pk=user.pk)

    def cost_records(self):
        return MLLMCost.objects(user_id=self.user.pk, feature="reorganize")

    def delete_new_cost_records(self):
        for record in self.cost_records():
            if record.id not in self.costs_before:
                record.delete()

    def add_site(self, title):
        feed_id = self.next_feed_id
        self.next_feed_id += 1
        feed = Feed.objects.create(
            pk=feed_id,
            feed_address="https://site-%s.example.com/rss" % feed_id,
            feed_link="https://site-%s.example.com/" % feed_id,
            feed_title=title,
        )
        UserSubscription.objects.create(user=self.user, feed=feed, active=True)
        return feed_id

    def set_tree(self, folders):
        UserSubscriptionFolders.objects.update_or_create(
            user=self.user, defaults={"folders": json.dumps(folders)}
        )

    def tree(self):
        return json.loads(UserSubscriptionFolders.objects.get(user=self.user).folders)

    def at(self, moment):
        """Run the limits at `moment`, a naive UTC time."""
        return patch.object(usage, "clock", lambda: moment)

    def status(self):
        return self.client.get("/reorganize/status").json()

    def post(self, endpoint, **data):
        return self.client.post("/reorganize/%s" % endpoint, data).json()

    def decide(self, proposal_id, changes):
        return self.post("decisions", proposal_id=proposal_id, decisions=json.dumps(changes))

    def run_queued(self):
        """Run every queued run in this process, oldest first."""
        while self.queued:
            GenerateReorganizeProposal.apply(kwargs=self.queued.pop(0), throw=True)

    def propose_ready(self, level="reorganize"):
        """Start a proposal, run it, and return the summary status gives for it."""
        started = self.post("propose", level=level)
        self.assertEqual(started["code"], 1, started)
        self.run_queued()
        current = self.status()["proposal"]
        self.assertEqual((current["id"], current["status"]), (started["proposal"]["id"], "ready"))
        return current

    def revise_ready(self, proposal_id, request):
        """Revise a proposal, run the revision, and return the summary status gives for it."""
        started = self.post("revise", proposal_id=proposal_id, request=request)
        self.assertEqual(started["code"], 1, started)
        self.run_queued()
        current = self.status()["proposal"]
        self.assertEqual(
            (current["id"], current["status"], current["revises"]),
            (started["proposal"]["id"], "ready", proposal_id),
        )
        return current

    def stored(self, summary):
        return MReorganizeProposal.objects.get(id=summary["id"])

    def proposal_count(self, user=None):
        return MReorganizeProposal.objects(user_id=(user or self.user).pk).count()


class Test_SignedOut(ViewsTestCase):
    def test_every_endpoint_refuses_a_signed_out_request_and_changes_nothing(self):
        proposal = self.propose_ready()
        tree = self.tree()
        changes = json.dumps({"moves": {move_id(proposal, self.gadgets): {"arrive": False}}})
        self.client.logout()

        for method, endpoint, data in (
            ("get", "status", {}),
            ("post", "locks", {"keep": '[["Tech"]]', "skip": "[]"}),
            ("post", "propose", {"level": "fresh"}),
            ("post", "decisions", {"proposal_id": proposal["id"], "decisions": changes}),
            ("post", "revise", {"proposal_id": proposal["id"], "request": "Fewer folders."}),
            ("post", "apply", {"proposal_id": proposal["id"]}),
            ("post", "undo", {"proposal_id": proposal["id"]}),
        ):
            response = getattr(self.client, method)("/reorganize/%s" % endpoint, data)
            self.assertEqual(response.status_code, 403, endpoint)

        self.assertEqual((self.queued, self.proposal_count()), ([], 1))
        stored = self.stored(proposal)
        self.assertEqual((stored.status, stored.decisions), ("ready", {}))
        self.assertEqual(MReorganizeLocks.objects(user_id=self.user.pk).count(), 0)
        self.assertEqual(self.tree(), tree)


class Test_Status(ViewsTestCase):
    def test_a_new_user_has_no_proposal_empty_locks_and_their_limits(self):
        self.set_plan(self.user, archive=False)

        status = self.status()

        self.assertEqual(status["code"], 1)
        self.assertIsNone(status["proposal"])
        self.assertEqual(status["locks"], {"keep": [], "skip": []})
        limits = status["limits"]
        self.assertFalse(limits["can_apply"])
        self.assertFalse(limits["running"])
        self.assertEqual(limits["remaining"], limits["limit"])
        self.assertGreater(limits["remaining"], 0)


class Test_Propose(ViewsTestCase):
    def test_a_run_shows_its_progress_while_it_works_and_its_proposal_once_ready(self):
        seen_while_working = []

        def design():
            seen_while_working.append(self.status()["proposal"])
            return answer({"targets": self.targets})

        self.model.design = design

        started = self.client.post(
            "/reorganize/propose",
            {"level": "reorganize", "find_dead": "false", "instructions": "Keep it short"},
            HTTP_ACCEPT_LANGUAGE="de",
        ).json()

        self.assertEqual((started["code"], started["proposal"]["status"]), (1, "working"))
        self.assertTrue(started["limits"]["running"])
        self.assertEqual(self.status()["proposal"]["id"], started["proposal"]["id"])

        self.run_queued()

        working = seen_while_working[0]
        self.assertEqual((working["id"], working["status"]), (started["proposal"]["id"], "working"))
        self.assertGreaterEqual(working["progress"]["done"], 1)
        self.assertLess(working["progress"]["done"], working["progress"]["total"])
        current = self.status()["proposal"]
        self.assertEqual((current["id"], current["status"]), (started["proposal"]["id"], "ready"))
        self.assertEqual(current["decisions"], NO_DECISIONS)
        self.assertEqual(
            sorted(entry["feed_id"] for entry in current["proposal"]["moves"]),
            sorted([self.gadgets, self.phones]),
        )
        self.assertEqual(current["sites"], 4)
        self.assertEqual(self.stored(current).language, "de")

    def test_a_second_start_while_one_works_is_refused_with_the_limits(self):
        self.assertEqual(self.post("propose", level="reorganize")["code"], 1)

        refused = self.post("propose", level="fresh")

        self.assertEqual((refused["code"], refused["reason"]), (-1, "already_running"))
        self.assertTrue(refused["limits"]["running"])
        self.assertEqual((self.proposal_count(), len(self.queued)), (1, 1))


class Test_Locks(ViewsTestCase):
    def test_locks_are_saved_and_paths_that_name_no_folder_are_dropped(self):
        saved = self.post("locks", keep='[["Tech"]]', skip='[["Sorted"], ["Nowhere"], ["Tech", "Nested"]]')

        expected = {"keep": [["Tech"]], "skip": [["Sorted"]]}
        self.assertEqual((saved["code"], saved["locks"]), (1, expected))
        self.assertEqual(self.status()["locks"], expected)

    def test_a_malformed_path_is_refused_and_nothing_is_saved(self):
        self.post("locks", keep='[["Tech"]]', skip="[]")

        for malformed in ('[["Tech", ""]]', '[["Tech", 3]]', '["Tech"]', "[[]]", '{"Tech": []}', "not json"):
            refused = self.post("locks", keep="[]", skip=malformed)
            self.assertEqual((refused["code"], refused["reason"]), (-1, "invalid_locks"), malformed)

        self.assertEqual(self.status()["locks"], {"keep": [["Tech"]], "skip": []})


class Test_Decisions(ViewsTestCase):
    def test_partial_updates_accumulate_null_clears_and_unusable_changes_are_dropped(self):
        proposal = self.propose_ready()
        gadgets_move, phones_move = move_id(proposal, self.gadgets), move_id(proposal, self.phones)
        create = op_id(proposal, "create")

        self.decide(proposal["id"], {"moves": {gadgets_move: {"arrive": True}}})
        second = self.decide(
            proposal["id"], {"moves": {gadgets_move: {"leave": False}, phones_move: {"arrive": False}}}
        )
        self.assertEqual(
            second["decisions"]["moves"],
            {gadgets_move: {"arrive": True, "leave": False}, phones_move: {"arrive": False}},
        )

        third = self.decide(
            proposal["id"],
            {
                "moves": {
                    gadgets_move: {"arrive": None},
                    "m99": {"arrive": False},
                    phones_move: {"leave": "no"},
                },
                "ops": {create: False},
                "dead": {"d1": "mute"},
            },
        )

        expected = {
            "ops": {create: False},
            "moves": {gadgets_move: {"leave": False}, phones_move: {"arrive": False}},
            "dead": {},
        }
        self.assertEqual((third["code"], third["decisions"]), (1, expected))
        self.assertEqual(self.status()["proposal"]["decisions"], expected)

    def test_a_decision_saved_while_another_request_saves_one_is_kept(self):
        proposal = self.propose_ready()
        gadgets_move, phones_move = move_id(proposal, self.gadgets), move_id(proposal, self.phones)
        save = MReorganizeProposal.change_decisions
        racing = [True]

        def another_request_saves_first(*args):
            if racing:
                racing.clear()
                self.decide(proposal["id"], {"moves": {phones_move: {"arrive": False}}})
            return save(*args)

        with patch.object(MReorganizeProposal, "change_decisions", side_effect=another_request_saves_first):
            saved = self.decide(proposal["id"], {"moves": {gadgets_move: {"leave": False}}})

        expected = {gadgets_move: {"leave": False}, phones_move: {"arrive": False}}
        self.assertEqual(saved["decisions"]["moves"], expected)
        self.assertEqual(self.status()["proposal"]["decisions"]["moves"], expected)

    def test_decisions_are_refused_while_the_proposal_is_working(self):
        started = self.post("propose", level="reorganize")["proposal"]

        refused = self.decide(started["id"], {"ops": {"op1": False}})

        self.assertEqual((refused["code"], refused["reason"]), (-1, "not_ready"))
        self.run_queued()
        self.assertEqual(self.status()["proposal"]["decisions"], NO_DECISIONS)


class Test_ApplyAndUndo(ViewsTestCase):
    def test_applying_changes_the_folders_as_the_decisions_say(self):
        proposal = self.propose_ready()
        self.decide(proposal["id"], {"moves": {move_id(proposal, self.phones): {"arrive": False}}})

        applied = self.post("apply", proposal_id=proposal["id"])

        self.assertEqual(applied["code"], 1)
        after = [{"Tech": [self.phones, self.laptops]}, {"Sorted": [self.notes, self.gadgets]}]
        self.assertEqual(self.tree(), after)
        self.assertEqual(applied["folders"], after)
        summary = applied["proposal"]
        self.assertEqual(
            (summary["status"], summary["result"]["moved"], summary["can_undo"]), ("applied", 1, True)
        )
        self.assertTrue(applied["limits"]["can_apply"])
        self.assertEqual(self.status()["proposal"]["status"], "applied")

    def test_applying_needs_premium_archive_and_leaves_the_folders(self):
        self.set_plan(self.user, archive=False)
        proposal = self.propose_ready()
        tree = self.tree()

        refused = self.post("apply", proposal_id=proposal["id"])

        self.assertEqual((refused["code"], refused["reason"]), (-1, "archive_required"))
        self.assertEqual(self.tree(), tree)
        self.assertEqual(self.status()["proposal"]["status"], "ready")

    def test_undo_puts_the_folders_back(self):
        before = self.tree()
        proposal = self.propose_ready()
        self.post("apply", proposal_id=proposal["id"])
        self.assertNotEqual(self.tree(), before)

        undone = self.post("undo", proposal_id=proposal["id"])

        self.assertEqual(undone["code"], 1)
        self.assertEqual(self.tree(), before)
        self.assertEqual((undone["proposal"]["status"], undone["proposal"]["can_undo"]), ("undone", False))


class Test_OtherUsers(ViewsTestCase):
    def test_another_users_proposal_a_malformed_id_and_a_missing_id_are_all_not_found(self):
        applied = self.propose_ready()
        self.post("apply", proposal_id=applied["id"])
        self.assignments = [assign(self.laptops, "t2")]
        ready = self.propose_ready()
        tree = self.tree()

        intruder = self.make_user("reorganize_views_other")
        self.set_plan(intruder, archive=True)
        self.client.force_login(intruder)
        changes = json.dumps({"moves": {move_id(ready, self.laptops): {"arrive": False}}})
        for endpoint, proposal_id, data in (
            ("decisions", ready["id"], {"decisions": changes}),
            ("revise", ready["id"], {"request": "Fewer folders."}),
            ("apply", ready["id"], {}),
            ("undo", applied["id"], {}),
        ):
            for given in (
                {"proposal_id": proposal_id},
                {"proposal_id": "not-an-id"},
                {"proposal_id": ""},
                {},
            ):
                refused = self.post(endpoint, **given, **data)
                self.assertEqual((refused["code"], refused["reason"]), (-1, "not_found"), (endpoint, given))

        self.client.force_login(self.user)
        self.assertEqual((self.proposal_count(), self.proposal_count(intruder), self.queued), (2, 0, []))
        self.assertEqual((self.stored(applied).status, self.stored(ready).status), ("applied", "ready"))
        self.assertEqual(self.status()["proposal"]["decisions"], NO_DECISIONS)
        self.assertEqual(self.tree(), tree)


class Test_Summary(ViewsTestCase):
    def test_the_summary_never_carries_the_undo_snapshot_or_the_models_answer(self):
        proposal = self.propose_ready()
        self.assertFalse(PRIVATE_KEYS & all_keys(self.status()))

        applied = self.post("apply", proposal_id=proposal["id"])

        self.assertTrue(self.stored(proposal).undo["folders"])
        self.assertTrue(self.stored(proposal).answer["targets"])
        self.assertFalse(PRIVATE_KEYS & all_keys(applied))
        self.assertFalse(PRIVATE_KEYS & all_keys(self.status()))


class Test_Revise(ViewsTestCase):
    def test_a_finished_revision_replaces_the_proposal_and_carries_the_decisions_it_still_has(self):
        original = self.propose_ready()
        self.decide(
            original["id"],
            {
                "moves": {
                    move_id(original, self.gadgets): {"arrive": False},
                    move_id(original, self.phones): {"leave": False},
                }
            },
        )
        self.assignments = [assign(self.gadgets, "t2")]

        started = self.post("revise", proposal_id=original["id"], request="Leave the phone blogs in Tech.")

        self.assertEqual((started["code"], started["proposal"]["status"]), (1, "working"))
        self.run_queued()
        current = self.status()["proposal"]
        self.assertEqual(
            (current["id"], current["status"], current["revises"]),
            (started["proposal"]["id"], "ready", original["id"]),
        )
        self.assertEqual([entry["feed_id"] for entry in current["proposal"]["moves"]], [self.gadgets])
        self.assertEqual(
            current["decisions"],
            {"ops": {}, "moves": {move_id(current, self.gadgets): {"arrive": False}}, "dead": {}},
        )
        self.assertEqual(self.stored(original).status, "replaced")

    def test_a_failed_revision_leaves_the_proposal_current_and_ready_with_its_decisions(self):
        original = self.propose_ready()
        decisions = self.decide(
            original["id"], {"moves": {move_id(original, self.gadgets): {"arrive": False}}}
        )
        self.model.design = lambda: declined()

        started = self.post("revise", proposal_id=original["id"], request="Fewer folders.")
        self.run_queued()

        self.assertEqual(self.stored(started["proposal"]).status, "failed")
        current = self.status()["proposal"]
        self.assertEqual((current["id"], current["status"]), (original["id"], "ready"))
        self.assertEqual(current["decisions"], decisions["decisions"])

    def test_a_proposal_applied_while_its_revision_works_stays_applied_and_current(self):
        original = self.propose_ready()
        started = self.post("revise", proposal_id=original["id"], request="Fewer folders.")
        self.assertEqual(self.post("apply", proposal_id=original["id"])["code"], 1)

        self.run_queued()

        revision = self.stored(started["proposal"])
        self.assertEqual((revision.status, revision.error), ("failed", "already_applied"))
        current = self.status()["proposal"]
        self.assertEqual(
            (current["id"], current["status"], current["can_undo"]), (original["id"], "applied", True)
        )

    def test_a_revision_needs_a_request(self):
        original = self.propose_ready()

        refused = self.post("revise", proposal_id=original["id"], request="   ")

        self.assertEqual((refused["code"], refused["reason"]), (-1, "empty_request"))
        self.assertEqual((self.proposal_count(), self.queued), (1, []))

    def test_a_replaced_proposal_refuses_decisions_revise_and_apply(self):
        original = self.propose_ready()
        gadgets_move = move_id(original, self.gadgets)
        self.decide(original["id"], {"moves": {gadgets_move: {"arrive": False}}})
        self.revise_ready(original["id"], "Fewer folders.")
        tree = self.tree()

        for endpoint, data in (
            ("decisions", {"decisions": json.dumps({"moves": {gadgets_move: {"arrive": True}}})}),
            ("revise", {"request": "Fewer still."}),
            ("apply", {}),
        ):
            refused = self.post(endpoint, proposal_id=original["id"], **data)
            self.assertEqual((refused["code"], refused["reason"]), (-1, "replaced"), endpoint)

        stored = self.stored(original)
        self.assertEqual(
            (stored.status, stored.decisions["moves"]), ("replaced", {gadgets_move: {"arrive": False}})
        )
        self.assertEqual((self.proposal_count(), self.queued), (2, []))
        self.assertEqual(self.tree(), tree)

    def test_the_earlier_design_and_the_request_reach_the_design_call(self):
        original = self.propose_ready()
        # A folder added since moves every key along, so Tech is e1 and Sorted is e2 now.
        self.set_tree(
            [{"Inbox": []}, {"Tech": [self.gadgets, self.phones, self.laptops]}, {"Sorted": [self.notes]}]
        )
        self.targets = [
            target("t1", "Tech", continues=["e1"]),
            target("t2", "Sorted", continues=["e2"]),
            target("t3", "Handsets"),
        ]
        calls_before = len(self.model.calls)

        self.revise_ready(original["id"], "Split News by country.")

        design_calls = [call for call in self.model.calls[calls_before:] if call["designs"]]
        self.assertEqual(len(design_calls), 1)
        self.assertIn("Split News by country.", design_calls[0]["text"])
        design = earlier_design(design_calls[0])
        self.assertEqual(
            {target_id: (entry["name"], entry["continues"]) for target_id, entry in design.items()},
            {"t1": ("Tech", ["e1"]), "t2": ("Sorted", ["e2"]), "t3": ("Handsets", [])},
        )

    def test_the_request_reaches_every_assign_call_of_a_revision(self):
        original = self.propose_ready(level="reorganize")
        calls_before = len(self.model.calls)

        self.revise_ready(original["id"], "Keep the gadget blog in Sorted.")

        assign_calls = [call for call in self.model.calls[calls_before:] if not call["designs"]]
        self.assertTrue(assign_calls)
        for call in assign_calls:
            self.assertIn("Keep the gadget blog in Sorted.", call["text"])

    def test_a_tidy_revision_passes_the_request_to_the_assign_calls(self):
        self.assignments = [assign(self.gadgets, "e1")]
        original = self.propose_ready(level="tidy")
        calls_before = len(self.model.calls)

        self.revise_ready(original["id"], "Keep the gadget blog in Tech.")

        revision_calls = self.model.calls[calls_before:]
        self.assertTrue(revision_calls)
        for call in revision_calls:
            self.assertFalse(call["designs"])
            self.assertIn("Keep the gadget blog in Tech.", call["text"])


class Test_RevisionLimits(ViewsTestCase):
    def test_without_archive_a_used_proposal_can_be_revised_twice_without_using_next_months(self):
        self.set_plan(self.user, archive=False)
        with self.at(datetime.datetime(2026, 11, 10, 12, 0)):
            original = self.propose_ready()
            self.assertEqual(self.post("propose", level="reorganize")["reason"], "monthly_limit")
        with self.at(datetime.datetime(2026, 11, 20, 12, 0)):
            first = self.revise_ready(original["id"], "Fewer folders.")
        with self.at(datetime.datetime(2026, 12, 2, 12, 0)):
            second = self.revise_ready(first["id"], "Now split Tech.")
            refused = self.post("revise", proposal_id=second["id"], request="One more.")
            december = self.post("propose", level="reorganize")

        self.assertEqual(
            (original["revisions_left"], first["revisions_left"], second["revisions_left"]), (2, 1, 0)
        )
        self.assertEqual((refused["code"], refused["reason"]), (-1, "revision_limit"))
        self.assertEqual(december["code"], 1)

    def test_with_archive_a_revision_counts_toward_the_24_hour_cap(self):
        with self.at(datetime.datetime(2026, 11, 10, 12, 0)), patch.object(usage, "DAILY_RUNS", 2):
            original = self.propose_ready()
            self.assertEqual(self.status()["limits"]["remaining"], 1)
            revision = self.revise_ready(original["id"], "Fewer folders.")
            self.assertEqual(self.status()["limits"]["remaining"], 0)

            refused = self.post("revise", proposal_id=revision["id"], request="Fewer still.")

        self.assertEqual((refused["code"], refused["reason"]), (-1, "daily_cap"))
        self.assertEqual(revision["revisions_left"], 4)
