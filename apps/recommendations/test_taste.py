"""test_taste.py: Preference ownership, inference, spending and real ranking effects."""

import datetime
import json
import threading
import time
from types import SimpleNamespace
from unittest.mock import Mock, patch

import requests
from django.contrib.auth.models import User
from django.core.cache import cache
from django.test import Client, TestCase, override_settings
from django.urls import reverse

from apps.recommendations import taste
from apps.recommendations.discovery import Discovery
from apps.recommendations.models import (
    MDiscoveryModelBudget,
    MDiscoveryTaste,
    MRecommendationFeedback,
)


@override_settings(CACHES={"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}})
class Test_DiscoveryTaste(TestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user(username="taste-reader")
        self.other = User.objects.create_user(username="taste-other")
        self.client.force_login(self.user)
        self.profile = taste.profile_for(self.user.pk)
        self.rule = dict(
            id="accountability",
            label="AI accountability",
            criterion="Reporting on actual harms from AI",
            kind="angle",
            direction=1,
            strength=1,
            manual=False,
            removed=False,
            evidence=["1:000001"],
        )
        self.votes = [
            MRecommendationFeedback(
                user_id=self.user.pk,
                story_hash="1:%06d" % i,
                value=1 if i < 3 else -1,
                story_feed_id=1,
                surface="discovery",
                story_title="Rating %s" % i,
                story_excerpt="Article context",
            ).save()
            for i in range(1, 4)
        ]
        self.profile.rules = [self.rule]
        self.profile.fingerprint = taste.vote_fingerprint(taste.current_votes(self.user.pk))
        self.profile.save()

    def tearDown(self):
        MDiscoveryTaste.objects(user_id__in=[self.user.pk, self.other.pk]).delete()
        MRecommendationFeedback.objects(user_id__in=[self.user.pk, self.other.pk]).delete()
        MDiscoveryModelBudget.objects(name="taste-v1").delete()
        cache.clear()

    def edit(self, **kwargs):
        params = dict(
            revision=0,
            id=self.rule["id"],
            action="save",
            label="Practical AI failures",
            criterion="Concrete examples of AI failing in daily use",
            kind="angle",
            direction=-1,
            strength=2,
        )
        params.update(kwargs)
        return self.client.post(reverse("discovery-edit-taste"), params).json()

    def test_manual_edits_are_account_scoped_and_revision_checked(self):
        other = taste.profile_for(self.other.pk)
        other.rules = [self.rule]
        other.save()
        data = self.edit(user_id=self.other.pk)
        self.assertEqual(data["code"], 1)
        self.assertTrue(data["profile"]["rules"][0]["manual"])
        self.assertEqual(taste.profile_for(self.other.pk).revision, 0)
        self.assertEqual(self.edit()["code"], -1)
        self.assertEqual(taste.profile_for(self.user.pk).rules[0]["direction"], -1)

    def test_csrf_and_authentication_are_required_for_mutations(self):
        client = Client(enforce_csrf_checks=True)
        client.force_login(self.user)
        self.assertEqual(client.post(reverse("discovery-edit-taste"), {}).status_code, 403)
        self.client.logout()
        self.assertEqual(self.client.get(reverse("discovery-taste-profile")).status_code, 403)

    def test_invalid_edit_leaves_preferences_unchanged(self):
        for fields in [
            dict(direction=4),
            dict(strength=0),
            dict(label=""),
            dict(criterion=""),
            dict(kind="identity"),
        ]:
            self.assertEqual(self.edit(**fields)["code"], -1)
        self.assertEqual(taste.profile_for(self.user.pk).revision, 0)

    def test_pause_remove_restore_and_new_interest(self):
        self.assertFalse(self.edit(direction=0)["profile"]["rules"][0]["active"])
        self.assertTrue(self.edit(action="remove", revision=1)["profile"]["rules"][0]["removed"])
        restored = self.edit(action="restore", revision=2)["profile"]["rules"][0]
        self.assertFalse(restored["removed"])
        self.assertTrue(restored["manual"])
        added = self.edit(action="add", id="", revision=3)["profile"]["rules"]
        self.assertEqual(len(added), 2)
        self.assertTrue(added[1]["active"])

    def test_deleting_account_cleans_up_taste(self):
        user_id = self.user.pk
        self.user.delete()
        self.assertFalse(MDiscoveryTaste.objects(user_id=user_id))

    def model_response(self, interests):
        return {"choices": [{"message": {"content": json.dumps({"interests": interests})}}]}

    @patch("apps.recommendations.taste.model_request")
    def test_inference_preserves_manual_edits_and_removed_interests(self, request):
        edited = dict(self.rule, manual=True, label="My wording", direction=-1)
        removed = dict(self.rule, id="removed", manual=True, removed=True)
        request.return_value = self.model_response(
            [
                dict(self.rule, label="Overwrite me"),
                dict(self.rule, id="removed"),
                dict(self.rule, id="new", evidence=["1:000003", "other:private"]),
            ]
        )
        rules = taste.infer_rules(self.votes, [edited, removed])
        self.assertEqual(rules[:2], [edited, removed])
        self.assertEqual(rules[2]["evidence"], ["1:000003"])
        self.assertNotEqual(rules[2]["id"], "new")

    @patch("apps.recommendations.taste.model_request")
    def test_inference_rejects_malformed_or_invented_evidence(self, request):
        request.return_value = self.model_response([dict(self.rule, evidence=["not-my-story"])])
        self.assertEqual(taste.infer_rules(self.votes, []), [])
        for proposed in ["invalid", [dict(self.rule, criterion="")], [None]]:
            request.return_value = self.model_response(proposed)
            with self.assertRaises(taste.TasteUnavailable):
                taste.infer_rules(self.votes, [])

    @patch("apps.recommendations.taste.infer_rules")
    def test_unchanged_ratings_do_not_call_model(self, infer):
        taste.refresh_profile(self.user.pk)
        infer.assert_not_called()

    @patch("apps.recommendations.taste.infer_rules")
    def test_concurrent_edit_wins_over_inference_and_lease_is_released(self, infer):
        self.profile.update(set__fingerprint="old")

        def edit_during_call(*args):
            self.edit()
            return [dict(self.rule, label="Stale generated wording")]

        infer.side_effect = edit_during_call
        profile = taste.refresh_profile(self.user.pk)
        self.assertEqual(profile.rules[0]["label"], "Practical AI failures")
        self.assertEqual(profile.refresh_token, "")

    @patch("apps.recommendations.taste.infer_rules")
    def test_changed_ratings_during_generation_discard_stale_result(self, infer):
        self.profile.update(set__fingerprint="old")

        def clear_during_call(*args):
            self.votes[0].update(set__value=0)
            return []

        infer.side_effect = clear_during_call
        profile = taste.refresh_profile(self.user.pk)
        self.assertEqual(profile.rules, [self.rule])
        self.assertEqual(profile.revision, 0)

    @patch("apps.recommendations.taste.infer_rules", side_effect=taste.TasteUnavailable("offline"))
    def test_generation_failure_keeps_preferences_and_backs_off(self, infer):
        self.profile.update(set__fingerprint="old")
        for _ in range(2):
            with self.assertRaises(taste.TasteUnavailable):
                taste.refresh_profile(self.user.pk)
        self.assertEqual(infer.call_count, 1)
        self.assertEqual(taste.profile_for(self.user.pk).rules, [self.rule])

    def test_clearing_or_reversing_evidence_withdraws_automatic_interest(self):
        for value in [0, -1]:
            self.votes[0].update(set__value=value)
            data = taste.serialize_profile(self.profile, taste.current_votes(self.user.pk))
            self.assertFalse(data["rules"][0]["active"])
            self.assertEqual(data["summary"], "")
        self.profile.rules[0]["manual"] = True
        self.assertTrue(taste.serialize_profile(self.profile, [])["rules"][0]["active"])

    @override_settings(OPENROUTER_API_KEY="test-key", DISCOVERY_MODEL_BUDGET_USD=1)
    @patch("apps.recommendations.taste.requests.post")
    def test_budget_reserves_atomically_refunds_known_cost_and_blocks_overage(self, post):
        post.return_value.json.return_value = {"usage": {"cost": 0.1}}
        taste.model_request("alpha/decisions", {}, 0.6)
        self.assertAlmostEqual(MDiscoveryModelBudget.objects.get(name="taste-v1").committed, 0.1)
        with self.assertRaises(taste.TasteUnavailable):
            taste.model_request("alpha/decisions", {}, 0.95)
        self.assertEqual(post.call_count, 1)

    @override_settings(OPENROUTER_API_KEY="test-key", DISCOVERY_MODEL_BUDGET_USD=1)
    @patch("apps.recommendations.taste.requests.post", side_effect=requests.Timeout)
    def test_uncertain_billable_request_retains_reservation(self, post):
        with self.assertRaises(taste.TasteUnavailable):
            taste.model_request("alpha/decisions", {}, 0.6)
        self.assertAlmostEqual(MDiscoveryModelBudget.objects.get(name="taste-v1").committed, 0.6)

    def stories(self):
        return [
            SimpleNamespace(
                story_hash="%s:abcdef" % i,
                story_title="Candidate %s" % i,
                story_content="Text",
                original_text_z=None,
                story_content_z=None,
                story_tags=[],
                story_feed_id=i,
                story_date=datetime.datetime.utcnow(),
            )
            for i in range(1, 16)
        ]

    @patch("apps.recommendations.taste.model_request")
    def test_jev_probabilities_are_cached_across_strength_and_direction_edits(self, request):
        request.return_value = {"answers": {"s0_r0": {"noul": 0.8}}}
        story = self.stories()[0]
        first = taste.story_matches(self.user.pk, [story], [self.rule])
        second = taste.story_matches(self.user.pk, [story], [dict(self.rule, direction=-1, strength=3)])
        self.assertEqual(first, second)
        self.assertEqual(request.call_count, 1)
        taste.story_matches(self.other.pk, [story], [self.rule])
        self.assertEqual(request.call_count, 2)

    @patch("apps.recommendations.taste.model_request")
    def test_invalid_probability_is_not_cached(self, request):
        request.return_value = {"answers": {"s0_r0": {"noul": float("nan")}}}
        for _ in range(2):
            with self.assertRaises(taste.TasteUnavailable):
                taste.story_matches(self.user.pk, self.stories()[:1], [self.rule])
        self.assertEqual(request.call_count, 2)

    def test_slow_provider_returns_fallback_without_waiting_for_workers(self):
        release = threading.Event()

        def slow_request(*args):
            release.wait(2)
            raise taste.TasteUnavailable("Slow provider")

        stories = self.stories()
        baseline = [story.story_hash for story in stories]
        try:
            with patch.object(taste, "MATCH_DEADLINE", 0.03), patch.object(
                taste, "model_request", side_effect=slow_request
            ), patch.object(Discovery, "rank", return_value=baseline):
                started = time.monotonic()
                ranked = taste.rank_with_interests(self.user.pk, stories, [], self.votes)
                self.assertLess(time.monotonic() - started, 0.5)
                self.assertEqual(ranked, baseline)
                self.assertEqual(taste.profile_for(self.user.pk).impact["status"], "fallback")
        finally:
            release.set()

    @patch.object(Discovery, "rank")
    @patch("apps.recommendations.taste.story_matches")
    def test_editing_direction_changes_real_order_and_impact(self, matches, rank):
        stories = self.stories()
        baseline = [s.story_hash for s in stories]
        rank.return_value = baseline
        matches.return_value = {h: {self.rule["id"]: float(i == 13)} for i, h in enumerate(baseline)}
        more = taste.rank_with_interests(self.user.pk, stories, [], self.votes)
        self.assertLess(more.index(baseline[13]), 12)
        self.assertEqual(taste.profile_for(self.user.pk).impact["changed_top12"], 1)
        self.edit()
        less = taste.rank_with_interests(self.user.pk, stories, [], self.votes)
        self.assertGreater(less.index(baseline[13]), 13)

    @patch.object(Discovery, "rank")
    @patch("apps.recommendations.taste.story_matches", side_effect=taste.TasteUnavailable("offline"))
    def test_matching_failure_keeps_reading_rank_and_backs_off(self, matches, rank):
        stories = self.stories()
        rank.return_value = [s.story_hash for s in stories]
        for _ in range(2):
            self.assertEqual(
                taste.rank_with_interests(self.user.pk, stories, [], self.votes), rank.return_value
            )
        self.assertEqual(matches.call_count, 1)
        self.assertEqual(taste.profile_for(self.user.pk).impact["status"], "fallback")

    @patch.object(Discovery, "candidate_hashes", return_value=[])
    @patch.object(Discovery, "eligible_stories")
    @patch.object(Discovery, "unread_stories")
    @patch.object(Discovery, "reading_examples", return_value=[])
    @patch("apps.recommendations.taste.rank_with_interests")
    def test_comparison_filters_read_stories_without_consuming_weekly_preview(
        self, rank, examples, unread, eligible, hashes
    ):
        self.user.profile.is_archive = True
        self.user.profile.save()
        eligible.return_value = self.stories()
        unread.return_value = self.stories()[2:]
        with patch.object(Discovery, "page") as page:
            result = self.client.post(reverse("discovery-preview-taste"))
        self.assertEqual(result.json()["code"], 1)
        self.assertEqual(rank.call_args.args[1], unread.return_value)
        page.assert_not_called()

    def test_changed_votes_hide_obsolete_ranking_explanations(self):
        self.profile.impact = dict(fingerprint=self.profile.fingerprint, changed_top12=2)
        self.assertTrue(
            taste.serialize_profile(self.profile, taste.current_votes(self.user.pk), True)["impact"]
        )
        self.votes[0].update(set__value=0)
        self.assertEqual(
            taste.serialize_profile(self.profile, taste.current_votes(self.user.pk), True)["impact"], {}
        )

    @patch("apps.recommendations.taste.rank_with_interests")
    def test_weekly_accounts_cannot_preview_or_retrieve_extra_candidates(self, rank):
        self.profile.impact = dict(
            fingerprint=self.profile.fingerprint, stories=[dict(title="Extra candidate")]
        )
        self.profile.save()
        self.assertEqual(self.client.post(reverse("discovery-preview-taste")).json()["code"], -1)
        data = self.client.get(reverse("discovery-taste-profile")).json()["profile"]
        self.assertFalse(data["can_compare"])
        self.assertEqual(data["impact"], {})
        rank.assert_not_called()
