"""Tests for apps/reorganize/state.py, which carries a user's folder settings through a reorganization."""

import json

from django.contrib.auth.models import User
from django.test import TestCase

from apps.analyzer.models import (
    MClassifierAuthor,
    MClassifierPrompt,
    MClassifierTag,
    MClassifierText,
    MClassifierTitle,
    MClassifierUrl,
)
from apps.briefing.models import MBriefingPreferences
from apps.notifications.models import MUserClassifierNotification
from apps.profile.models import MDashboardRiver, Profile
from apps.reader.models import MFolderAutoMarkRead, MFolderIcon
from apps.reorganize.plan import apply_plan
from apps.reorganize.state import carry_folder_state, revert_folder_state
from apps.rss_feeds.models import MSavedSearch

BEFORE = [
    1,
    {"Tech": [2]},
    {"Hardware": [3]},
    {"Blogs": [4, {"People": [5]}]},
    {"Science": [6]},
    {"Any Broken Feeds": [7, {"Science": [8]}]},
    {"Travel": [9, {"Places": [10]}]},
    {"Empty": []},
]

# The field that names the folder on each kind of document.
KEY_FIELDS = {
    MFolderIcon: "folder_title",
    MFolderAutoMarkRead: "folder_title",
    MSavedSearch: "feed_id",
    MDashboardRiver: "river_id",
    MClassifierTitle: "folder_name",
    MClassifierText: "folder_name",
    MClassifierUrl: "folder_name",
    MClassifierAuthor: "folder_name",
    MClassifierTag: "folder_name",
    MClassifierPrompt: "folder_id",
    MUserClassifierNotification: "folder_name",
}
RULE_FIELDS = {
    MClassifierTitle: "title",
    MClassifierText: "text",
    MClassifierUrl: "url",
    MClassifierAuthor: "author",
}

# Entries keyed by the folder's own name, with what each store puts in front of it. Every other
# entry attach() makes is keyed by the folder's full path.
LEAF_PREFIXES = {
    "folder_icon": "",
    "auto_mark_read": "",
    "view_settings": "river:",
    "saved_search": "river:",
    "dashboard_river": "river:",
}


def placed(found, leaf, path):
    """Where every entry in `found` belongs for a folder named `leaf` whose full path is `path`."""
    return {name: LEAF_PREFIXES[name] + leaf if name in LEAF_PREFIXES else path for name in found}


class Test_FolderState(TestCase):
    def setUp(self):
        self.user = self.make_user("reorganizer")
        self.other = self.make_user("bystander")

    def make_user(self, username):
        user = User.objects.create_user(username=username, password="test")
        for model in [*KEY_FIELDS, MBriefingPreferences]:
            model.objects(user_id=user.pk).delete()
            self.addCleanup(model.objects(user_id=user.pk).delete)
        return user

    def reorganize(self, user, *ops, folders=BEFORE):
        """Apply ("rename", path, name) and ("nest", path, parent path) ops to `folders` with
        apps/reorganize/plan.py, then carry the user's folder state the way the result says."""
        keys = {}

        def key_for(path):
            return keys.setdefault(tuple(path), "e%d" % len(keys)) if path else "root"

        proposal_ops = []
        for index, (op_type, path, value) in enumerate(ops):
            op = {"id": "o%d" % index, "type": op_type, "folder": key_for(path)}
            if op_type == "rename":
                op["name"] = value
            else:
                op["parent"] = key_for(value)
            proposal_ops.append(op)
        proposal = {"folders": {key: {"path": list(path)} for path, key in keys.items()}, "ops": proposal_ops}

        result = apply_plan(folders, proposal, {}, {})
        self.assertEqual(result.skipped, [])
        return carry_folder_state(user, result.path_changes, folders, result.folders)

    def attach(self, user, path, rule=None, leaf=True):
        """Give the folder at `path` an entry in every store, keyed the way the clients save them.

        The web keys icons, auto mark read, view settings, saved searches and dashboard rivers by
        the folder's own name, and mobile keys icons and auto mark read by the full path.
        `leaf=False` leaves out the entries keyed by the folder's own name. Returns {entry name:
        document, or the marker stored in its view setting} for where() to find again.
        """
        leaf_name, full_path = path[-1], " - ".join(path)
        rule = rule or full_path
        found = {}
        if leaf:
            found["folder_icon"] = MFolderIcon.objects.create(
                user_id=user.pk, folder_title=leaf_name, icon_type="emoji", icon_data=full_path
            )
            found["auto_mark_read"] = MFolderAutoMarkRead.objects.create(
                user_id=user.pk, folder_title=leaf_name, auto_mark_read_days=7
            )
            found["saved_search"] = MSavedSearch.objects.create(
                user_id=user.pk, feed_id="river:" + leaf_name, query=rule
            )
            found["dashboard_river"] = MDashboardRiver.objects.create(
                user_id=user.pk,
                river_id="river:" + leaf_name,
                river_side="left",
                river_order=MDashboardRiver.objects(user_id=user.pk).count(),
            )
            self.add_view_settings(user, {"river:" + leaf_name: {"v": full_path}})
            found["view_settings"] = full_path
        if len(path) > 1:
            found["folder_icon_path"] = MFolderIcon.objects.create(
                user_id=user.pk, folder_title=full_path, icon_type="emoji", icon_data=full_path
            )
            found["auto_mark_read_path"] = MFolderAutoMarkRead.objects.create(
                user_id=user.pk, folder_title=full_path, auto_mark_read_days=14
            )
        for model, field in RULE_FIELDS.items():
            found[model.__name__] = model.objects.create(
                user_id=user.pk,
                feed_id=0,
                social_user_id=0,
                scope="folder",
                folder_name=full_path,
                score=1,
                **{field: rule},
            )
        # A tag rule is unique per user whatever its folder (the classifier_tag index in
        # apps/analyzer/models.py), so every folder gets its own tag.
        found["MClassifierTag"] = MClassifierTag.objects.create(
            user_id=user.pk,
            feed_id=0,
            social_user_id=0,
            scope="folder",
            folder_name=full_path,
            score=1,
            tag=full_path,
        )
        found["MClassifierPrompt"] = MClassifierPrompt.objects.create(
            user_id=user.pk, feed_id=0, folder_id=full_path, prompt=rule, classifier_type="focus"
        )
        found["MUserClassifierNotification"] = MUserClassifierNotification.objects.create(
            user_id=user.pk,
            classifier_type="title",
            classifier_value=rule,
            scope="folder",
            folder_name=full_path,
            is_web=True,
        )
        return found

    def where(self, user, found):
        """The key each entry in `found` sits under now, or None once it is gone."""
        view_settings = json.loads(Profile.objects.get(user=user).view_settings)
        keys = {}
        for name, entry in found.items():
            if name == "view_settings":
                keys[name] = next(
                    (key for key, value in view_settings.items() if value == {"v": entry}), None
                )
            else:
                document = type(entry).objects(id=entry.pk).first()
                keys[name] = getattr(document, KEY_FIELDS[type(entry)]) if document else None
        return keys

    def snapshot(self, user):
        """Every document and profile field the stores keep for `user`."""
        profile = Profile.objects.get(user=user)
        state = {
            "view_settings": json.loads(profile.view_settings),
            "collapsed_folders": json.loads(profile.collapsed_folders),
        }
        for model in [*KEY_FIELDS, MBriefingPreferences]:
            documents = [document.to_mongo().to_dict() for document in model.objects(user_id=user.pk)]
            state[model.__name__] = sorted(documents, key=lambda document: str(document["_id"]))
        return state

    def add_view_settings(self, user, view_settings):
        profile = Profile.objects.get(user=user)
        profile.view_settings = json.dumps({**json.loads(profile.view_settings), **view_settings})
        profile.save(update_fields=["view_settings"])

    def set_collapsed(self, user, names):
        Profile.objects.filter(user=user).update(collapsed_folders=json.dumps(names))

    def collapsed(self, user):
        return json.loads(Profile.objects.get(user=user).collapsed_folders)

    def story_sources(self, user):
        return MBriefingPreferences.objects.get(user_id=user.pk).story_sources

    def test_renaming_a_top_level_folder_carries_every_entry(self):
        found = self.attach(self.user, ["Tech"])
        self.set_collapsed(self.user, ["Tech"])
        MBriefingPreferences.objects.create(user_id=self.user.pk, story_sources="folder:Tech")

        self.reorganize(self.user, ("rename", ["Tech"], "Gadgets"))

        self.assertEqual(self.where(self.user, found), placed(found, "Gadgets", "Gadgets"))
        self.assertEqual(self.collapsed(self.user), ["Gadgets"])
        self.assertEqual(self.story_sources(self.user), "folder:Gadgets")

    def test_a_shared_name_keeps_its_entries_while_full_paths_follow(self):
        science = self.attach(self.user, ["Science"])
        broken_science = self.attach(self.user, ["Any Broken Feeds", "Science"], leaf=False)
        tech = self.attach(self.user, ["Tech"])

        # Two folders were named Science before, and two are named People after, with Blogs > People.
        self.reorganize(
            self.user,
            ("rename", ["Any Broken Feeds", "Science"], "Biology"),
            ("rename", ["Tech"], "People"),
        )

        self.assertEqual(self.where(self.user, science), placed(science, "Science", "Science"))
        self.assertEqual(
            self.where(self.user, broken_science),
            placed(broken_science, None, "Any Broken Feeds - Biology"),
        )
        self.assertEqual(self.where(self.user, tech), placed(tech, "Tech", "People"))

    def test_an_entry_never_lands_where_one_already_is(self):
        tech = self.attach(self.user, ["Tech"])
        # A deleted folder's leftovers, under the name Tech takes, holding the same rules as Tech.
        leftover = self.attach(self.user, ["Gadgets"], rule="Tech")
        self.set_collapsed(self.user, ["Tech", "Gadgets"])

        carried = self.reorganize(self.user, ("rename", ["Tech"], "Gadgets"))

        self.assertEqual(self.where(self.user, leftover), placed(leftover, "Gadgets", "Gadgets"))
        # Tech's tag rule is the one rule the leftovers have no copy of, so it alone moves.
        self.assertEqual(
            self.where(self.user, tech), dict(placed(tech, "Tech", "Tech"), MClassifierTag="Gadgets")
        )
        self.assertEqual(self.collapsed(self.user), ["Tech", "Gadgets"])
        self.assertEqual([entry["store"] for entry in carried], ["classifier_tag"])

    def test_another_users_entries_stay(self):
        mine = self.attach(self.user, ["Tech"])
        theirs = self.attach(self.other, ["Tech"])
        self.set_collapsed(self.other, ["Tech"])
        MBriefingPreferences.objects.create(user_id=self.other.pk, story_sources="folder:Tech")

        self.reorganize(self.user, ("rename", ["Tech"], "Gadgets"))

        self.assertEqual(self.where(self.user, mine), placed(mine, "Gadgets", "Gadgets"))
        self.assertEqual(self.where(self.other, theirs), placed(theirs, "Tech", "Tech"))
        self.assertEqual(self.collapsed(self.other), ["Tech"])
        self.assertEqual(self.story_sources(self.other), "folder:Tech")

    def test_revert_restores_every_store(self):
        for path in (
            ["Tech"],
            ["Hardware"],
            ["Blogs"],
            ["Blogs", "People"],
            ["Science"],
            ["Travel", "Places"],
        ):
            self.attach(self.user, path)
        self.attach(self.user, ["Any Broken Feeds", "Science"], leaf=False)
        self.add_view_settings(self.user, {"1": {"v": "page"}, "river:": {"v": "feed"}})
        self.set_collapsed(self.user, ["starred", "Tech", "Hardware", "Blogs", "People", "Places", "Science"])
        MBriefingPreferences.objects.create(user_id=self.user.pk, story_sources="folder:Places")
        before = self.snapshot(self.user)

        carried = self.reorganize(
            self.user,
            ("rename", ["Tech"], "Tech News"),
            ("rename", ["Hardware"], "Tech"),
            ("rename", ["Blogs"], "Weblogs"),
            ("rename", ["Blogs", "People"], "Places"),
            ("rename", ["Travel", "Places"], "People"),
            ("rename", ["Any Broken Feeds", "Science"], "Biology"),
        )
        self.assertNotEqual(self.snapshot(self.user), before)

        # The undo snapshot stores `carried` as JSON.
        revert_folder_state(self.user, json.loads(json.dumps(carried)))

        self.assertEqual(self.snapshot(self.user), before)

    def test_revert_skips_what_the_user_changed_since(self):
        found = self.attach(self.user, ["Tech"])
        self.set_collapsed(self.user, ["Tech"])
        MBriefingPreferences.objects.create(user_id=self.user.pk, story_sources="folder:Tech")
        carried = self.reorganize(self.user, ("rename", ["Tech"], "Gadgets"))

        # Since then the user removed some of what moved, and saved new entries under the old name.
        MFolderIcon.objects(id=found["folder_icon"].pk).delete()
        MSavedSearch.objects(id=found["saved_search"].pk).delete()
        self.set_collapsed(self.user, [])
        MBriefingPreferences.objects(user_id=self.user.pk).update_one(set__story_sources="all")
        MFolderAutoMarkRead.objects.create(user_id=self.user.pk, folder_title="Tech", auto_mark_read_days=9)
        self.add_view_settings(self.user, {"river:Tech": {"v": "later"}})
        MClassifierTitle.objects.create(
            user_id=self.user.pk,
            feed_id=0,
            social_user_id=0,
            scope="folder",
            folder_name="Tech",
            score=-1,
            title="Tech",
        )

        revert_folder_state(self.user, json.loads(json.dumps(carried)))

        self.assertEqual(
            self.where(self.user, found),
            dict(
                placed(found, "Tech", "Tech"),
                folder_icon=None,
                saved_search=None,
                auto_mark_read="Gadgets",
                view_settings="river:Gadgets",
                MClassifierTitle="Gadgets",
            ),
        )
        self.assertEqual(
            MFolderAutoMarkRead.objects.get(user_id=self.user.pk, folder_title="Tech").auto_mark_read_days, 9
        )
        self.assertEqual(
            json.loads(Profile.objects.get(user=self.user).view_settings)["river:Tech"], {"v": "later"}
        )
        self.assertEqual(
            list(MClassifierTitle.objects(user_id=self.user.pk, folder_name="Tech").scalar("score")), [-1]
        )
        self.assertEqual(self.collapsed(self.user), [])
        self.assertEqual(self.story_sources(self.user), "all")

    def test_a_chain_and_a_swap_keep_every_entry_with_its_folder(self):
        tech = self.attach(self.user, ["Tech"])
        hardware = self.attach(self.user, ["Hardware"])
        people = self.attach(self.user, ["Blogs", "People"])
        places = self.attach(self.user, ["Travel", "Places"])
        self.set_collapsed(self.user, ["Tech", "Hardware", "People", "Places"])

        self.reorganize(
            self.user,
            ("rename", ["Tech"], "Tech News"),
            ("rename", ["Hardware"], "Tech"),
            ("rename", ["Blogs", "People"], "Places"),
            ("rename", ["Travel", "Places"], "People"),
        )

        self.assertEqual(self.where(self.user, tech), placed(tech, "Tech News", "Tech News"))
        self.assertEqual(self.where(self.user, hardware), placed(hardware, "Tech", "Tech"))
        self.assertEqual(self.where(self.user, people), placed(people, "Places", "Blogs - Places"))
        self.assertEqual(self.where(self.user, places), placed(places, "People", "Travel - People"))
        self.assertEqual(self.collapsed(self.user), ["Tech News", "Tech", "Places", "People"])

    def test_names_the_web_reserves_keep_their_settings(self):
        # Folders really named after the global shared stories river and the saved stories section.
        global_folder = self.attach(self.user, ["global"])
        starred_folder = self.attach(self.user, ["starred"])
        self.set_collapsed(self.user, ["starred", "global"])

        carried = self.reorganize(
            self.user,
            ("rename", ["global"], "World"),
            ("rename", ["starred"], "Favorites"),
            folders=[{"global": [1]}, {"starred": [2]}],
        )

        # A full path names only the folder, so the entries keyed by it still follow.
        self.assertEqual(self.where(self.user, global_folder), placed(global_folder, "global", "World"))
        self.assertEqual(
            self.where(self.user, starred_folder), placed(starred_folder, "starred", "Favorites")
        )
        self.assertEqual(self.collapsed(self.user), ["starred", "global"])
        self.assertTrue(all(entry["store"].startswith("classifier_") for entry in carried))

        # apps/reorganize/plan.py never proposes a reserved name, so this rename comes straight in.
        renamer = self.make_user("renamer")
        world = self.attach(renamer, ["World"])
        self.set_collapsed(renamer, ["World"])

        carry_folder_state(
            renamer, [{"old": ["World"], "new": ["global"]}], [{"World": [1]}], [{"global": [1]}]
        )

        self.assertEqual(self.where(renamer, world), placed(world, "World", "global"))
        self.assertEqual(self.collapsed(renamer), ["World"])

    def test_a_folder_with_nothing_attached_records_nothing(self):
        self.attach(self.user, ["Tech"])
        before = self.snapshot(self.user)

        carried = self.reorganize(self.user, ("rename", ["Empty"], "Vacant"))

        self.assertEqual(carried, [])
        self.assertEqual(self.snapshot(self.user), before)
