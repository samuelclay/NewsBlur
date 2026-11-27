"""Tests for apps/reorganize/derive.py, which turns a model's reorganization answer into a proposal."""

import unittest

from apps.reorganize.derive import build_proposal, model_view
from apps.reorganize.plan import FolderTree, apply_plan
from apps.reorganize.test_plan import (
    ABF,
    ABF_SCIENCE,
    BLOGLETS,
    BLOGS,
    BOSTON,
    MOBILITY,
    NEW_YORK,
    NO_LOCKS,
    PATHS,
    PEOPLE,
    SCIENCE,
    TECH,
    TREE,
    WOOD,
    folder_items,
    folder_paths,
    locks,
)

EMPTY_PROPOSAL = {"folders": {}, "ops": [], "moves": [], "dead": []}


def target(target_id, name, parent=None, continues=(), reason="These belong together"):
    return {"id": target_id, "name": name, "parent": parent, "continues": list(continues), "reason": reason}


def assign(feed_id, folder, reason="Fits this folder"):
    return {"feed_id": feed_id, "folder": folder, "reason": reason}


def dead_site(feed_id, suggest="mute"):
    return {"feed_id": feed_id, "reason": "No stories in a year", "suggest": suggest}


def moves_of(proposal):
    return [(entry["feed_id"], entry["from"], entry["to"]) for entry in proposal["moves"]]


def ops_of(proposal, op_type):
    return [entry for entry in proposal["ops"] if entry["type"] == op_type]


def homes(folders, feed_id):
    """Every folder path that holds the site, with the top level as []."""
    tree = FolderTree.from_list(folders)
    paths = [[]] + list(tree.folder_keys().values())
    return [path for path in paths if feed_id in tree.feeds_in(path)]


def apply_cleanly(test, proposal, guarded=NO_LOCKS, decisions=None):
    result = apply_plan(TREE, proposal, decisions or {}, guarded)
    test.assertEqual(result.skipped, [])
    return result


class Test_ModelView(unittest.TestCase):
    def test_locked_folders_are_hidden_and_sites_show_only_open_placements(self):
        guarded = locks(keep=[["Blogs"], ["Bloglets"]], skip=[["Tech"]])

        view = model_view(TREE, guarded)

        self.assertEqual(
            view["folders"],
            [
                {"key": ABF, "path": PATHS[ABF], "sites": 4},
                {"key": ABF_SCIENCE, "path": PATHS[ABF_SCIENCE], "sites": 2},
                {"key": SCIENCE, "path": PATHS[SCIENCE], "sites": 2},
                {"key": MOBILITY, "path": PATHS[MOBILITY], "sites": 1},
                {"key": WOOD, "path": PATHS[WOOD], "sites": 0},
                {"key": NEW_YORK, "path": PATHS[NEW_YORK], "sites": 1},
                {"key": BOSTON, "path": PATHS[BOSTON], "sites": 1},
            ],
        )
        sites = view["sites"]
        self.assertEqual(sites[1], {"folders": ["root"], "copy_only": False})
        self.assertEqual(sites[21], {"folders": [ABF_SCIENCE, SCIENCE], "copy_only": False})
        self.assertEqual(sites[30], {"folders": [ABF], "copy_only": False})
        self.assertEqual(sites[50], {"folders": [], "copy_only": True})
        self.assertEqual(sites[60], {"folders": [], "copy_only": True})
        for feed_id in (31, 32, 33):
            self.assertNotIn(feed_id, sites)


class Test_Assignments(unittest.TestCase):
    def test_site_assigned_to_its_own_folder_gets_no_move(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [target("t1", "Tech", continues=[TECH])],
            [assign(31, "t1"), assign(32, TECH), assign(1, "root"), assign(70, "t1")],
            [],
        )

        self.assertEqual(moves_of(proposal), [(70, MOBILITY, TECH)])

    def test_site_already_in_the_destination_through_another_placement_gets_no_move(self):
        proposal = build_proposal(TREE, NO_LOCKS, [], [assign(30, TECH), assign(21, SCIENCE)], [])

        self.assertEqual(proposal["moves"], [])

    def test_assignments_to_unknown_folders_or_sites_are_dropped(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [target("t1", "Apple")],
            [assign(31, "t9"), assign(32, "e99"), assign(999, "t1"), assign(33, "t1")],
            [dead_site(999)],
        )

        self.assertEqual(moves_of(proposal), [(33, TECH, "n0")])
        self.assertEqual(proposal["dead"], [])

    def test_first_usable_assignment_for_a_site_wins(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [target("t1", "Apple")],
            [assign(31, "t9"), assign(31, "t1"), assign(31, "root")],
            [],
        )

        self.assertEqual(moves_of(proposal), [(31, TECH, "n0")])

    def test_site_only_in_a_keep_folder_is_offered_as_a_copy(self):
        keep = locks(keep=[["Bloglets"]])
        proposal = build_proposal(TREE, keep, [target("t1", "Reading")], [assign(60, "t1")], [])

        self.assertEqual(moves_of(proposal), [(60, BLOGLETS, "n0")])
        untouched = apply_cleanly(self, proposal, keep)
        self.assertEqual(homes(untouched.folders, 60), [["Bloglets"]])
        accepted = {"moves": {proposal["moves"][0]["id"]: {"arrive": True}}}
        copied = apply_cleanly(self, proposal, keep, accepted)
        self.assertEqual(homes(copied.folders, 60), [["Bloglets"], ["Reading"]])

    def test_site_in_a_keep_folder_and_an_open_folder_moves_from_the_open_one(self):
        keep = locks(keep=[["Any Broken Feeds"]])
        proposal = build_proposal(TREE, keep, [target("t1", "Reading")], [assign(30, "t1")], [])

        self.assertEqual(moves_of(proposal), [(30, TECH, "n0")])
        result = apply_cleanly(self, proposal, keep)
        self.assertEqual(homes(result.folders, 30), [["Any Broken Feeds"], ["Reading"]])
        self.assertEqual(
            folder_items(result.folders, "Any Broken Feeds"), folder_items(TREE, "Any Broken Feeds")
        )

    def test_site_only_in_a_skip_folder_gets_nothing(self):
        skip = locks(skip=[["Tech"]])
        proposal = build_proposal(
            TREE,
            skip,
            [target("t1", "Reading")],
            [assign(31, "t1"), assign(30, "root")],
            [dead_site(31, "unsubscribe")],
        )

        self.assertEqual(moves_of(proposal), [(30, ABF, "root")])
        self.assertEqual(proposal["dead"], [])
        self.assertEqual(ops_of(proposal, "create"), [])

    def test_tidy_level_files_sites_into_existing_folders_only(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [
                target("t1", "Bikes", continues=[MOBILITY]),
                target("t2", "Blogs", continues=[BLOGS, BLOGLETS]),
                target("t3", "Apple"),
            ],
            [assign(70, TECH), assign(31, "root"), assign(32, "t3"), assign(60, "t2")],
            [],
            allow_folder_changes=False,
        )

        self.assertEqual(proposal["ops"], [])
        self.assertCountEqual(moves_of(proposal), [(70, MOBILITY, TECH), (31, TECH, "root")])


class Test_FolderTargets(unittest.TestCase):
    def test_target_continuing_one_folder_renames_it_and_takes_its_sites(self):
        reason = "  Bikes, trains and buses " + "x" * 300
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [target("t1", "Bikes & Transit", continues=[MOBILITY], reason=reason)],
            [assign(1, "t1", reason="A cycling blog")],
            [],
        )

        renames = ops_of(proposal, "rename")
        self.assertEqual([(op["folder"], op["name"]) for op in renames], [(MOBILITY, "Bikes & Transit")])
        self.assertEqual(renames[0]["reason"], reason.strip()[:200])
        self.assertEqual(ops_of(proposal, "create"), [])
        self.assertEqual(moves_of(proposal), [(1, "root", MOBILITY)])
        self.assertEqual(proposal["moves"][0]["reason"], "A cycling blog")
        result = apply_cleanly(self, proposal)
        self.assertEqual(folder_items(result.folders, "Bikes & Transit"), [70, 1])

    def test_target_continuing_two_folders_merges_them_and_moves_the_sites_across(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [
                target("t1", "Blogs", continues=[BLOGS, BLOGLETS], reason="Same kind of writing"),
                target("t2", "Tech", continues=[TECH]),
            ],
            [assign(61, "t2"), assign(1, BLOGLETS)],
            [],
        )

        merges = ops_of(proposal, "merge")
        self.assertEqual(
            [(op["folder"], op["into"], op["reason"]) for op in merges],
            [(BLOGLETS, BLOGS, "Same kind of writing")],
        )
        self.assertCountEqual(
            moves_of(proposal), [(61, BLOGLETS, TECH), (1, "root", BLOGS), (60, BLOGLETS, BLOGS)]
        )
        reasons = {entry["feed_id"]: entry["reason"] for entry in proposal["moves"]}
        self.assertEqual(reasons, {61: "Fits this folder", 1: "Fits this folder", 60: ""})
        self.assertEqual([op["folder"] for op in ops_of(proposal, "remove")], [WOOD])
        result = apply_cleanly(self, proposal)
        self.assertNotIn(("Bloglets",), folder_paths(result.folders))
        self.assertEqual(folder_items(result.folders, "Blogs"), [40, 41, 42, {"People": [50, 51]}, 1, 60])
        self.assertEqual(folder_items(result.folders, "Tech"), [30, 31, 32, 33, 61])

    def test_unusable_continues_become_new_folders_or_lose_the_claim(self):
        keep = locks(keep=[["Bloglets"]])
        proposal = build_proposal(
            TREE,
            keep,
            [
                target("t1", "Apple", continues=["e99", None, 5, [TECH]]),
                target("t2", "Tech", continues=[TECH, TECH]),
                target("t3", "Gadgets", continues=[TECH]),
                target("t4", "Short Reads", continues=[BLOGLETS, MOBILITY]),
            ],
            [assign(31, "t1"), assign(32, "t3"), assign(33, "t4"), assign(1, "t2")],
            [],
        )

        created = [proposal["folders"][op["folder"]]["name"] for op in ops_of(proposal, "create")]
        self.assertEqual(created, ["Apple", "Gadgets"])
        self.assertEqual(ops_of(proposal, "merge"), [])
        self.assertEqual(
            [(op["folder"], op["name"]) for op in ops_of(proposal, "rename")], [(MOBILITY, "Short Reads")]
        )
        result = apply_cleanly(self, proposal, keep)
        self.assertEqual(folder_items(result.folders, "Apple"), [31])
        self.assertEqual(folder_items(result.folders, "Gadgets"), [32])
        self.assertEqual(folder_items(result.folders, "Short Reads"), [70, 33])
        self.assertEqual(folder_items(result.folders, "Tech"), [30, 1])
        self.assertEqual(folder_items(result.folders, "Bloglets"), [60, 61])

    def test_folders_left_empty_get_a_remove(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [],
            [assign(70, TECH), assign(60, TECH)]
            + [assign(feed_id, "root") for feed_id in (40, 41, 42, 50, 51)],
            [],
        )

        removes = ops_of(proposal, "remove")
        self.assertCountEqual([op["folder"] for op in removes], [MOBILITY, WOOD, BLOGS, PEOPLE])
        self.assertEqual({op["reason"] for op in removes}, {""})
        result = apply_cleanly(self, proposal)
        self.assertCountEqual(result.removed, [["mobility"], ["Wood"], ["Blogs"], ["Blogs", "People"]])
        self.assertEqual(folder_items(result.folders, "Bloglets"), [61])

    def test_new_folders_nest_inside_new_folders_and_hold_existing_ones(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [
                target("t1", "Places"),
                target("t2", "New York", parent="t1", continues=[NEW_YORK]),
                target("t3", "Boston", parent="t1", continues=[BOSTON]),
                target("t4", "Apple"),
                target("t5", "Mac", parent="t4"),
            ],
            [assign(31, "t5")],
            [],
        )

        result = apply_cleanly(self, proposal)
        self.assertEqual(folder_items(result.folders, "Places"), [{"New York": [80]}, {"Boston": [81]}])
        self.assertEqual(folder_items(result.folders, "Apple"), [{"Mac": [31]}])
        self.assertNotIn(("New York",), folder_paths(result.folders))

    def test_folder_can_move_inside_its_own_former_subfolder(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [
                target("t1", "Blogs", parent="t2", continues=[BLOGS]),
                target("t2", "People", continues=[PEOPLE]),
            ],
            [],
            [],
        )

        result = apply_cleanly(self, proposal)
        self.assertEqual(folder_items(result.folders, "People"), [50, 51, {"Blogs": [40, 41, 42]}])

    def test_parent_cycles_put_the_folder_that_closes_them_at_the_top_level(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [
                target("t1", "Alpha", parent="t2"),
                target("t2", "Beta", parent="t1"),
                target("t3", "Gamma", parent="t3"),
                target("t4", "New York", parent="t5", continues=[NEW_YORK]),
                target("t5", "Boston", parent="t4", continues=[BOSTON]),
            ],
            [assign(31, "t1"), assign(32, "t2"), assign(33, "t3")],
            [],
        )

        result = apply_cleanly(self, proposal)
        self.assertEqual(folder_items(result.folders, "Beta"), [{"Alpha": [31]}, 32])
        self.assertEqual(folder_items(result.folders, "Gamma"), [33])
        self.assertEqual(folder_items(result.folders, "Boston"), [81, {"New York": [80]}])


class Test_FolderNames(unittest.TestCase):
    def test_folder_keeps_its_name_when_the_answer_renames_it_and_reuses_the_name(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [target("t1", "Gadgets", continues=[TECH]), target("t2", "Tech")],
            [assign(31, "t1"), assign(32, "t1"), assign(33, "t1"), assign(1, "t2"), assign(70, "t2")],
            [],
        )

        self.assertEqual(ops_of(proposal, "rename"), [])
        result = apply_cleanly(self, proposal)
        self.assertEqual(folder_items(result.folders, "Gadgets"), [31, 32, 33])
        self.assertEqual(folder_items(result.folders, "Tech"), [30, 1, 70])

    def test_nested_target_loses_an_existing_name_to_the_top_level_target_of_that_name(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [
                target("t1", "Computers"),
                target("t2", "Tech", parent="t1", continues=[TECH]),
                target("t3", "Tech"),
            ],
            [assign(31, "t2"), assign(32, "t2"), assign(1, "t3")],
            [],
        )

        result = apply_cleanly(self, proposal)
        self.assertEqual(folder_items(result.folders, "Computers"), [{"Tech": [31, 32]}])
        self.assertEqual(folder_items(result.folders, "Tech"), [30, 33, 1])

    def test_new_target_named_like_an_existing_folder_files_into_it(self):
        proposal = build_proposal(TREE, NO_LOCKS, [target("t1", "tech")], [assign(1, "t1")], [])

        self.assertEqual(ops_of(proposal, "create") + ops_of(proposal, "rename"), [])
        self.assertEqual(moves_of(proposal), [(1, "root", TECH)])
        result = apply_cleanly(self, proposal)
        self.assertEqual(folder_items(result.folders, "Tech"), [30, 31, 32, 33, 1])

    def test_subfolder_keeps_its_name_ahead_of_a_top_level_target_continuing_it(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [
                target("t1", "Friends", continues=[PEOPLE]),
                target("t2", "Blogs"),
                target("t3", "People", parent="t2"),
            ],
            [assign(50, "t1"), assign(51, "t3"), assign(1, "t3")],
            [],
        )

        result = apply_cleanly(self, proposal)
        self.assertEqual(folder_items(result.folders, "Friends"), [50])
        self.assertEqual(folder_items(result.folders, "Blogs", "People"), [51, 1])


class Test_DeadSites(unittest.TestCase):
    def test_site_filed_alone_and_suggested_for_unsubscribe_applies_without_skips(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [target("t1", "Places", continues=[NEW_YORK, MOBILITY]), target("t2", "Transit")],
            [assign(70, "t2")],
            [dead_site(70, "unsubscribe")],
        )

        self.assertEqual(
            [(entry["feed_id"], entry["suggest"]) for entry in proposal["dead"]], [(70, "unsubscribe")]
        )
        apply_cleanly(self, proposal)


# A model answer over TREE (apps/reorganize/test_plan.py) that renames mobility, merges Bloglets into
# Blogs, creates Apple, nests New York and Boston under a new Places and files a dozen sites.
END_TO_END_TARGETS = [
    target("t1", "Bikes & Transit", continues=[MOBILITY]),
    target("t2", "Blogs", continues=[BLOGS, BLOGLETS]),
    target("t3", "Apple"),
    target("t4", "Places"),
    target("t5", "New York", parent="t4", continues=[NEW_YORK]),
    target("t6", "Boston", parent="t4", continues=[BOSTON]),
    target("t7", "Tech", continues=[TECH]),
    target("t8", "People", parent="t2", continues=[PEOPLE]),
    target("t9", "Any Broken Feeds", continues=[ABF]),
    target("t10", "Science", parent="t9", continues=[ABF_SCIENCE]),
    target("t11", "Science", continues=[SCIENCE]),
]
END_TO_END_ASSIGNMENTS = [
    assign(31, "t3"),
    assign(32, "t3"),
    assign(1, "t1"),
    assign(2, "t7"),
    assign(61, "t8"),
    assign(10, "t7"),
    assign(11, "t7"),
    assign(12, "t7"),
    assign(33, "t3"),
    assign(80, "t5"),
    assign(22, "root"),
    assign(42, "t3"),
]


class Test_EndToEnd(unittest.TestCase):
    def test_model_answer_applies_to_exactly_the_tree_it_describes(self):
        proposal = build_proposal(TREE, NO_LOCKS, END_TO_END_TARGETS, END_TO_END_ASSIGNMENTS, [])

        self.assertEqual(
            [op["type"] for op in proposal["ops"]],
            ["create", "create", "rename", "nest", "nest", "merge", "remove"],
        )
        result = apply_cleanly(self, proposal)
        self.assertEqual(
            result.folders,
            [
                {"Any Broken Feeds": [30, {"Science": [20, 21]}]},
                {"Blogs": [40, 41, {"People": [50, 51, 61]}, 60]},
                {"Tech": [30, 2, 10, 11, 12]},
                {"Science": [21]},
                {"Bikes & Transit": [70, 1]},
                {"Apple": [31, 32, 33, 42]},
                {"Places": [{"New York": [80]}, {"Boston": [81]}]},
                22,
            ],
        )

    def test_ids_are_unique_across_the_whole_proposal(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [target("t1", "Nothing Here Yet"), target("t2", "Bikes", continues=[MOBILITY])],
            [assign(1, "t2")],
            [dead_site(41), dead_site(81, "unsubscribe")],
        )

        self.assertEqual([op["type"] for op in proposal["ops"]], ["rename", "remove"])
        ids = [entry["id"] for section in ("ops", "moves", "dead") for entry in proposal[section]]
        self.assertEqual(len(ids), len(set(ids)))
        apply_cleanly(self, proposal)


class Test_MalformedAnswers(unittest.TestCase):
    def test_answer_with_nothing_usable_gives_an_empty_proposal(self):
        self.assertEqual(model_view(None, None), {"folders": [], "sites": {}})
        self.assertEqual(build_proposal(None, None, None, None, None), EMPTY_PROPOSAL)
        self.assertEqual(build_proposal(TREE, NO_LOCKS, "t1", "31", {"feed_id": 31}), EMPTY_PROPOSAL)
        self.assertEqual(
            build_proposal(
                TREE,
                "everything",
                [
                    None,
                    5,
                    "t1",
                    {"id": 7, "name": "Apple"},
                    {"id": "t1", "name": None, "continues": MOBILITY},
                    {"id": "root", "name": "Top"},
                ],
                [
                    None,
                    {"feed_id": "31", "folder": "root"},
                    {"feed_id": True, "folder": "root"},
                    {"feed_id": 31},
                    {"feed_id": 31, "folder": ["root"]},
                    {"folder": "root"},
                ],
                [None, {"feed_id": "30"}, {"suggest": "mute"}],
            ),
            EMPTY_PROPOSAL,
        )

    def test_usable_entries_survive_beside_malformed_ones(self):
        proposal = build_proposal(
            TREE,
            NO_LOCKS,
            [
                {
                    "id": "t1",
                    "name": "Bikes",
                    "continues": [None, 3, MOBILITY],
                    "parent": 12,
                    "reason": ["why"],
                },
                {"name": "No id"},
            ],
            [{"feed_id": "31", "folder": "t1"}, {"feed_id": 1, "folder": "t1", "reason": None}],
            [{"feed_id": 70, "suggest": "archive"}, {"feed_id": "33", "suggest": "mute"}],
        )

        self.assertEqual(
            [(op["type"], op["folder"]) for op in proposal["ops"]], [("rename", MOBILITY), ("remove", WOOD)]
        )
        self.assertEqual(moves_of(proposal), [(1, "root", MOBILITY)])
        self.assertEqual([(entry["feed_id"], entry["suggest"]) for entry in proposal["dead"]], [(70, "mute")])
        apply_cleanly(self, proposal)


if __name__ == "__main__":
    unittest.main()
