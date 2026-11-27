"""Tests for apps/reorganize/apply.py, which applies a stored proposal to an account and undoes it."""

import datetime
import json
from unittest.mock import patch
from xml.etree import ElementTree

from django.contrib.auth.models import User
from django.core import mail
from django.db import DatabaseError
from django.test import TestCase

from apps.analyzer.models import MClassifierTitle
from apps.profile.models import MSentEmail, Profile
from apps.reader.models import MFolderIcon, UserSubscription, UserSubscriptionFolders
from apps.reorganize.apply import apply_proposal, undo_proposal
from apps.reorganize.models import MReorganizeLocks, MReorganizeProposal
from apps.reorganize.plan import FolderTree, PlanError
from apps.rss_feeds.models import DuplicateFeed, Feed
from apps.social.models import MActivity

# Keys a proposal made on the tree setUp() stores uses for its existing folders.
TECH, BLOGS, PEOPLE, OLD = "e0", "e1", "e2", "e3"


def move(move_id, feed_id, source, destination):
    return {"id": move_id, "feed_id": feed_id, "from": source, "to": destination, "reason": "fits better"}


def op(op_id, op_type, folder, **fields):
    return {"id": op_id, "type": op_type, "folder": folder, "reason": "tidier", **fields}


def dead_site(dead_id, feed_id, suggest):
    return {"id": dead_id, "feed_id": feed_id, "reason": "no stories in a year", "suggest": suggest}


class Test_ApplyProposal(TestCase):
    def setUp(self):
        self.user = self.make_user("reorganizer")
        self.home = self.subscribe(self.user, "home")
        self.gadgets = self.subscribe(self.user, "gadgets")
        self.phones = self.subscribe(self.user, "phones")
        self.essays = self.subscribe(self.user, "essays")
        self.diary = self.subscribe(self.user, "diary")
        self.silent = self.subscribe(self.user, "silent")
        self.set_tree(
            self.user,
            [
                self.home,
                {"Tech": [self.gadgets, self.phones]},
                {"Blogs": [self.essays, {"People": [self.diary]}]},
                {"Old": [self.silent]},
            ],
        )

    def make_user(self, username, archive=True, pro=False):
        user = User.objects.create_user(username=username, email=username + "@example.com", password="test")
        for model, field in (
            (MReorganizeProposal, "user_id"),
            (MReorganizeLocks, "user_id"),
            (MFolderIcon, "user_id"),
            (MClassifierTitle, "user_id"),
            (MActivity, "user_id"),
            (MSentEmail, "receiver_user_id"),
        ):
            model.objects(**{field: user.pk}).delete()
            self.addCleanup(model.objects(**{field: user.pk}).delete)
        return self.set_plan(user, archive=archive, pro=pro)

    def set_plan(self, user, archive, pro):
        """The user, fetched again, on Premium with the given Archive and Pro flags."""
        Profile.objects.filter(user=user).update(is_premium=True, is_archive=archive, is_pro=pro)
        return User.objects.get(pk=user.pk)

    def subscribe(self, user, name):
        feed = Feed.objects.create(
            feed_address="https://%s.example.com/rss" % name,
            feed_link="https://%s.example.com" % name,
            feed_title=name.title(),
        )
        UserSubscription.objects.create(user=user, feed=feed, active=True)
        return feed.pk

    def set_tree(self, user, folders):
        UserSubscriptionFolders.objects.update_or_create(user=user, defaults={"folders": json.dumps(folders)})

    def tree(self, user):
        return json.loads(UserSubscriptionFolders.objects.get(user=user).folders)

    def propose(self, user, ops=(), moves=(), dead=(), new_folders=None, decisions=None, status="ready"):
        """A stored proposal made on the user's tree as it is now."""
        paths = FolderTree.from_list(self.tree(user)).folder_keys()
        folders = {key: {"path": path} for key, path in paths.items()}
        folders.update(new_folders or {})
        return MReorganizeProposal.objects.create(
            user_id=user.pk,
            request_id="request-%s" % user.pk,
            status=status,
            level="reorganize",
            locks=MReorganizeLocks.for_user(user.pk),
            proposal={"folders": folders, "ops": list(ops), "moves": list(moves), "dead": list(dead)},
            decisions=decisions or {},
        )

    def stored(self, proposal):
        return MReorganizeProposal.objects.get(id=proposal.id)

    def is_active(self, feed_id):
        return UserSubscription.objects.get(user=self.user, feed_id=feed_id).active

    def mute(self, feed_id):
        UserSubscription.objects.filter(user=self.user, feed_id=feed_id).update(active=False)

    def skips(self, response):
        return {item["id"]: item["reason"] for item in response["result"]["skipped"]}

    def test_applying_saves_the_new_tree_and_keeps_the_tree_before(self):
        before = self.tree(self.user)
        proposal = self.propose(
            self.user,
            ops=[op("op1", "create", "n0")],
            moves=[move("m1", self.gadgets, TECH, "n0"), move("m2", self.home, "root", BLOGS)],
            new_folders={"n0": {"name": "Gadgets", "parent": "root"}},
        )

        response = apply_proposal(self.user, proposal)

        self.assertEqual(response["code"], "applied")
        self.assertEqual(
            self.tree(self.user),
            [
                {"Tech": [self.phones]},
                {"Blogs": [self.essays, {"People": [self.diary]}, self.home]},
                {"Old": [self.silent]},
                {"Gadgets": [self.gadgets]},
            ],
        )
        stored = self.stored(proposal)
        self.assertEqual(stored.status, "applied")
        self.assertIsNotNone(stored.applied_date)
        self.assertEqual(json.loads(stored.undo["folders"]), before)
        self.assertEqual(stored.result["skipped"], [])

    def test_a_plan_error_saves_nothing(self):
        icon = MFolderIcon.objects.create(user_id=self.user.pk, folder_title="Tech", icon_type="emoji")
        before = self.tree(self.user)
        proposal = self.propose(self.user, ops=[op("op1", "rename", TECH, name="Gadgets")])

        with patch("apps.reorganize.apply.apply_plan", side_effect=PlanError("Feed set changed")):
            with self.assertRaises(PlanError):
                apply_proposal(self.user, proposal)

        self.assertEqual(self.tree(self.user), before)
        self.assertEqual(MFolderIcon.objects.get(id=icon.id).folder_title, "Tech")
        stored = self.stored(proposal)
        self.assertEqual(stored.status, "ready")
        self.assertEqual(stored.undo, {})

    def test_items_that_no_longer_fit_are_reported_and_the_rest_applies(self):
        proposal = self.propose(
            self.user,
            ops=[op("op1", "rename", OLD, name="Archive")],
            moves=[move("m1", self.gadgets, TECH, BLOGS), move("m2", self.phones, TECH, BLOGS)],
        )
        # Since the proposal was made, the user moved Gadgets to the top level and renamed Old.
        self.set_tree(
            self.user,
            [
                self.home,
                self.gadgets,
                {"Tech": [self.phones]},
                {"Blogs": [self.essays, {"People": [self.diary]}]},
                {"Dormant": [self.silent]},
            ],
        )

        response = apply_proposal(self.user, proposal)

        self.assertEqual(response["code"], "applied")
        self.assertEqual(self.skips(response), {"m1": "feed_not_in_folder", "op1": "folder_changed"})
        self.assertEqual(self.stored(proposal).result["skipped"], response["result"]["skipped"])
        self.assertEqual(
            self.tree(self.user),
            [
                self.home,
                self.gadgets,
                {"Tech": []},
                {"Blogs": [self.essays, {"People": [self.diary]}, self.phones]},
                {"Dormant": [self.silent]},
            ],
        )

    def test_a_proposal_applies_once(self):
        before = self.tree(self.user)
        proposal = self.propose(self.user, moves=[move("m1", self.gadgets, TECH, BLOGS)])
        apply_proposal(self.user, proposal)
        applied = self.stored(proposal)
        # The user puts Gadgets back where it was, where the same move would apply again.
        self.set_tree(self.user, before)

        response = apply_proposal(self.user, proposal)

        self.assertEqual(response["code"], "already_applied")
        self.assertEqual(self.tree(self.user), before)
        stored = self.stored(proposal)
        self.assertEqual(stored.status, "applied")
        self.assertEqual(stored.undo, applied.undo)
        self.assertEqual(stored.applied_date, applied.applied_date)

        working = self.propose(self.user, moves=[move("m1", self.gadgets, TECH, BLOGS)], status="working")

        self.assertEqual(apply_proposal(self.user, working)["code"], "not_ready")
        self.assertEqual(self.tree(self.user), before)
        self.assertEqual(self.stored(working).status, "working")

    def test_applying_needs_premium_archive_or_pro(self):
        before = self.tree(self.user)
        premium = self.set_plan(self.user, archive=False, pro=False)
        proposal = self.propose(premium, moves=[move("m1", self.gadgets, TECH, BLOGS)])

        response = apply_proposal(premium, proposal)

        self.assertEqual(response["code"], "archive_required")
        self.assertEqual(self.tree(self.user), before)
        self.assertEqual(self.stored(proposal).status, "ready")
        self.assertEqual(mail.outbox, [])

        pro = self.set_plan(self.user, archive=False, pro=True)

        self.assertEqual(apply_proposal(pro, proposal)["code"], "applied")

    def test_another_users_proposal_cannot_be_applied_or_undone(self):
        other = self.make_user("bystander")
        self.set_tree(other, [{"Tech": [self.gadgets]}])
        theirs = self.propose(other, moves=[move("m1", self.gadgets, TECH, "root")])
        mine = self.tree(self.user)

        self.assertEqual(apply_proposal(self.user, theirs)["code"], "not_found")

        self.assertEqual(self.tree(self.user), mine)
        self.assertEqual(self.tree(other), [{"Tech": [self.gadgets]}])
        self.assertEqual(self.stored(theirs).status, "ready")

        self.assertEqual(apply_proposal(other, theirs)["code"], "applied")

        self.assertEqual(undo_proposal(self.user, theirs)["code"], "not_found")

        self.assertEqual(self.tree(self.user), mine)
        self.assertEqual(self.tree(other), [{"Tech": []}, self.gadgets])
        self.assertEqual(self.stored(theirs).status, "applied")

    def test_a_lock_added_after_the_proposal_was_made_is_honored(self):
        before = self.tree(self.user)
        proposal = self.propose(
            self.user,
            ops=[op("op1", "rename", TECH, name="Gadgets")],
            moves=[move("m1", self.essays, BLOGS, TECH)],
        )
        MReorganizeLocks.save_locks(self.user.pk, keep=[["Tech"]], skip=[])

        response = apply_proposal(self.user, proposal)

        self.assertEqual(self.skips(response), {"op1": "locked", "m1": "locked"})
        self.assertEqual(self.tree(self.user), before)

    def test_muting_records_only_the_sites_it_muted_and_undo_unmutes_only_those(self):
        self.mute(self.phones)
        proposal = self.propose(
            self.user, dead=[dead_site("d1", self.gadgets, "mute"), dead_site("d2", self.phones, "mute")]
        )

        apply_proposal(self.user, proposal)

        self.assertFalse(self.is_active(self.gadgets))
        self.assertFalse(self.is_active(self.phones))
        self.assertEqual(self.stored(proposal).undo["muted_feed_ids"], [self.gadgets])

        # Since then the user muted another site themselves.
        self.mute(self.essays)

        self.assertEqual(undo_proposal(self.user, proposal)["code"], "undone")

        self.assertTrue(self.is_active(self.gadgets))
        self.assertFalse(self.is_active(self.phones))
        self.assertFalse(self.is_active(self.essays))

    def test_unsubscribing_removes_the_subscription_and_undo_leaves_it_removed(self):
        proposal = self.propose(
            self.user,
            dead=[dead_site("d1", self.silent, "mute")],
            decisions={"dead": {"d1": "unsubscribe"}},
        )

        apply_proposal(self.user, proposal)

        self.assertFalse(UserSubscription.objects.filter(user=self.user, feed_id=self.silent).exists())
        self.assertNotIn(self.silent, FolderTree.from_list(self.tree(self.user)).feed_ids())

        self.assertEqual(undo_proposal(self.user, proposal)["code"], "undone")

        self.assertFalse(UserSubscription.objects.filter(user=self.user, feed_id=self.silent).exists())
        self.assertEqual(
            self.tree(self.user),
            [
                self.home,
                {"Tech": [self.gadgets, self.phones]},
                {"Blogs": [self.essays, {"People": [self.diary]}]},
                {"Old": []},
            ],
        )

    def test_unsubscribing_a_merged_site_removes_the_subscription_it_merged_into(self):
        # Old still lists the id of a feed that has since merged into Silent's feed.
        retired = Feed.objects.create(feed_address="https://retired.example.com/rss", feed_title="Retired")
        DuplicateFeed.objects.create(
            duplicate_address=retired.feed_address, duplicate_feed_id=str(retired.pk), feed_id=self.silent
        )
        self.set_tree(self.user, [self.home, {"Old": [retired.pk]}])
        proposal = self.propose(
            self.user,
            dead=[dead_site("d1", retired.pk, "mute")],
            decisions={"dead": {"d1": "unsubscribe"}},
        )

        response = apply_proposal(self.user, proposal)

        self.assertEqual(response["result"]["unsubscribed"], 1)
        self.assertFalse(UserSubscription.objects.filter(user=self.user, feed_id=self.silent).exists())
        self.assertEqual(self.tree(self.user), [self.home, {"Old": []}])

    def test_a_rename_carries_folder_settings_and_undo_puts_them_back(self):
        # The web names a folder icon by the folder's own name and a folder rule by its full path.
        icon = MFolderIcon.objects.create(user_id=self.user.pk, folder_title="Blogs", icon_type="emoji")
        rule = MClassifierTitle.objects.create(
            user_id=self.user.pk,
            feed_id=0,
            social_user_id=0,
            scope="folder",
            folder_name="Blogs - People",
            score=1,
            title="diary",
        )

        def keys():
            return (
                MFolderIcon.objects.get(id=icon.id).folder_title,
                MClassifierTitle.objects.get(id=rule.id).folder_name,
            )

        proposal = self.propose(self.user, ops=[op("op1", "rename", BLOGS, name="Weblogs")])

        apply_proposal(self.user, proposal)

        self.assertEqual(keys(), ("Weblogs", "Weblogs - People"))

        undo_proposal(self.user, proposal)

        self.assertEqual(keys(), ("Blogs", "Blogs - People"))

    def test_undo_restores_the_tree_and_marks_the_proposal_undone(self):
        before = self.tree(self.user)
        proposal = self.propose(
            self.user,
            ops=[
                op("op1", "rename", TECH, name="Gadgets"),
                op("op2", "nest", PEOPLE, parent="root"),
                op("op3", "create", "n0"),
            ],
            moves=[move("m1", self.essays, BLOGS, "n0"), move("m2", self.home, "root", OLD)],
            new_folders={"n0": {"name": "Reading", "parent": "root"}},
        )
        apply_proposal(self.user, proposal)
        self.assertNotEqual(self.tree(self.user), before)

        response = undo_proposal(self.user, proposal)

        self.assertEqual(response["code"], "undone")
        self.assertEqual(self.tree(self.user), before)
        stored = self.stored(proposal)
        self.assertEqual(stored.status, "undone")
        self.assertIsNotNone(stored.undone_date)

    def test_undo_keeps_sites_subscribed_since(self):
        proposal = self.propose(self.user, ops=[op("op1", "rename", TECH, name="Gadgets")])
        apply_proposal(self.user, proposal)
        # Since then the user subscribed to one site in Blogs, which the tree before had, and one in
        # Gadgets, which it did not.
        novel = self.subscribe(self.user, "novel")
        podcast = self.subscribe(self.user, "podcast")
        self.set_tree(
            self.user,
            [
                self.home,
                {"Gadgets": [self.gadgets, self.phones, podcast]},
                {"Blogs": [self.essays, {"People": [self.diary]}, novel]},
                {"Old": [self.silent]},
            ],
        )

        undo_proposal(self.user, proposal)

        self.assertEqual(
            self.tree(self.user),
            [
                self.home,
                {"Tech": [self.gadgets, self.phones]},
                {"Blogs": [self.essays, {"People": [self.diary]}, novel]},
                {"Old": [self.silent]},
                podcast,
            ],
        )

    def test_undo_is_refused_for_a_proposal_never_applied(self):
        before = self.tree(self.user)
        proposal = self.propose(self.user, ops=[op("op1", "rename", TECH, name="Gadgets")])

        self.assertEqual(undo_proposal(self.user, proposal)["code"], "not_applied")

        self.assertEqual(self.tree(self.user), before)
        self.assertEqual(self.stored(proposal).status, "ready")

    def test_undo_is_refused_more_than_30_days_after_applying(self):
        proposal = self.propose(self.user, ops=[op("op1", "rename", TECH, name="Gadgets")])
        apply_proposal(self.user, proposal)
        applied = self.tree(self.user)
        MReorganizeProposal.objects(id=proposal.id).update_one(
            set__applied_date=datetime.datetime.now() - datetime.timedelta(days=31)
        )

        self.assertEqual(undo_proposal(self.user, self.stored(proposal))["code"], "expired")

        self.assertEqual(self.tree(self.user), applied)
        self.assertEqual(self.stored(proposal).status, "applied")

    def test_undo_is_refused_once_a_later_proposal_is_applied(self):
        before = self.tree(self.user)
        first = self.propose(self.user, ops=[op("op1", "rename", TECH, name="Gadgets")])
        apply_proposal(self.user, first)
        second = self.propose(self.user, ops=[op("op1", "rename", OLD, name="Dormant")])
        apply_proposal(self.user, second)
        after_second = self.tree(self.user)

        self.assertEqual(undo_proposal(self.user, first)["code"], "superseded")

        self.assertEqual(self.tree(self.user), after_second)
        self.assertEqual(self.stored(first).status, "applied")

        # Once the later one is undone, the first can be undone too.
        self.assertEqual(undo_proposal(self.user, second)["code"], "undone")
        self.assertEqual(undo_proposal(self.user, first)["code"], "undone")
        self.assertEqual(self.tree(self.user), before)

    def test_a_proposal_left_applying_can_be_undone(self):
        icon = MFolderIcon.objects.create(user_id=self.user.pk, folder_title="Tech", icon_type="emoji")
        before = self.tree(self.user)
        proposal = self.propose(
            self.user,
            ops=[op("op1", "rename", TECH, name="Gadgets")],
            dead=[dead_site("d1", self.silent, "mute")],
        )

        # The apply fails once the tree is saved and the folder icon has followed the rename.
        with patch.object(UserSubscription, "save", side_effect=DatabaseError("connection lost")):
            with self.assertRaises(DatabaseError):
                apply_proposal(self.user, proposal)

        self.assertEqual(self.stored(proposal).status, "applying")
        self.assertEqual(MFolderIcon.objects.get(id=icon.id).folder_title, "Gadgets")

        self.assertEqual(undo_proposal(self.user, self.stored(proposal))["code"], "undone")

        self.assertEqual(self.tree(self.user), before)
        self.assertEqual(MFolderIcon.objects.get(id=icon.id).folder_title, "Tech")
        self.assertEqual(self.stored(proposal).status, "undone")

    def test_the_backup_email_holds_the_tree_before(self):
        proposal = self.propose(self.user, ops=[op("op1", "rename", TECH, name="Gadgets")])

        apply_proposal(self.user, proposal)

        self.assertEqual(len(mail.outbox), 1)
        _, opml, _ = mail.outbox[0].attachments[0]
        folder_titles = {
            outline.get("title")
            for outline in ElementTree.fromstring(opml).iter("outline")
            if outline.get("xmlUrl") is None
        }
        self.assertEqual(folder_titles, {"Tech", "Blogs", "People", "Old"})
