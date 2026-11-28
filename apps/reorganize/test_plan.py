"""Tests for apps/reorganize/plan.py, which applies a reviewed reorganization to a folder tree."""

import copy
import random
import unittest

from apps.reorganize.plan import (
    FolderTree,
    apply_plan,
    resolve_decisions,
    restore_folders,
    sanitize_proposal,
)

TREE = [
    1,
    2,
    {"Any Broken Feeds": [10, 11, 12, 30, {"Science": [20, 21]}]},
    {"Blogs": [40, 41, 42, {"People": [50, 51]}]},
    {"Bloglets": [60, 61]},
    {"Tech": [30, 31, 32, 33]},
    {"Science": [21, 22]},
    {"mobility": [70]},
    {"Wood": []},
    {"New York": [80]},
    {"Boston": [81]},
]

# Keys a proposal made on TREE uses for its existing folders, in depth-first document order.
PATHS = {
    "e0": ["Any Broken Feeds"],
    "e1": ["Any Broken Feeds", "Science"],
    "e2": ["Blogs"],
    "e3": ["Blogs", "People"],
    "e4": ["Bloglets"],
    "e5": ["Tech"],
    "e6": ["Science"],
    "e7": ["mobility"],
    "e8": ["Wood"],
    "e9": ["New York"],
    "e10": ["Boston"],
}
ABF, ABF_SCIENCE, BLOGS, PEOPLE, BLOGLETS, TECH, SCIENCE, MOBILITY, WOOD, NEW_YORK, BOSTON = PATHS

NO_LOCKS = {"keep": [], "skip": []}


def make_proposal(ops=(), moves=(), dead=(), new_folders=None):
    folders = {key: {"path": list(path)} for key, path in PATHS.items()}
    folders.update(new_folders or {})
    return {"folders": folders, "ops": list(ops), "moves": list(moves), "dead": list(dead)}


def move(move_id, feed_id, source, destination):
    return {"id": move_id, "feed_id": feed_id, "from": source, "to": destination, "reason": "fits better"}


def op(op_id, op_type, folder, **fields):
    return {"id": op_id, "type": op_type, "folder": folder, "reason": "tidier", **fields}


def new_folder(name, parent="root"):
    return {"name": name, "parent": parent}


def dead_site(dead_id, feed_id, suggest):
    return {"id": dead_id, "feed_id": feed_id, "reason": "no stories in a year", "suggest": suggest}


def locks(keep=(), skip=()):
    return {"keep": [list(path) for path in keep], "skip": [list(path) for path in skip]}


def skips(result):
    return {item["id"]: item["reason"] for item in result.skipped}


def tree_of(result):
    return FolderTree.from_list(result.folders)


def folder_paths(folders):
    return {tuple(path) for path in FolderTree.from_list(folders).folder_keys().values()}


def child_paths(tree, path):
    return [child for child in tree.folder_keys().values() if child[:-1] == list(path)]


def folder_items(folders, *path):
    items = folders
    for name in path:
        items = next(item[name] for item in items if isinstance(item, dict) and name in item)
    return items


class Test_FolderTree(unittest.TestCase):
    def test_same_named_sibling_folders_are_merged_on_load(self):
        stored = [{"News": [1, 2]}, 3, {"News": [2, 4, {"Local": [5]}]}, {"News": [{"Local": [6]}]}]

        self.assertEqual(FolderTree.from_list(stored).to_list(), [{"News": [1, 2, 4, {"Local": [5, 6]}]}, 3])

        proposal = {
            "folders": {"e1": {"path": ["News", "Local"]}},
            "ops": [],
            "moves": [move("m1", 6, "e1", "root")],
            "dead": [],
        }
        result = apply_plan(stored, proposal, {}, NO_LOCKS)
        self.assertEqual(result.folders, [{"News": [1, 2, 4, {"Local": [5]}]}, 3, 6])


class Test_SiteMoves(unittest.TestCase):
    def test_keep_here_copies_only_with_an_explicit_accept(self):
        proposal = make_proposal(moves=[move("m1", 60, BLOGLETS, TECH)])

        copied = apply_plan(TREE, proposal, {"moves": {"m1": {"arrive": True, "leave": False}}}, NO_LOCKS)
        self.assertEqual(tree_of(copied).feeds_in(["Bloglets"]), [60, 61])
        self.assertEqual(tree_of(copied).feeds_in(["Tech"]), [30, 31, 32, 33, 60])
        self.assertEqual(copied.copied, [(60, ["Bloglets"], ["Tech"])])
        self.assertEqual(copied.moved, [])

        kept = apply_plan(TREE, proposal, {"moves": {"m1": {"leave": False}}}, NO_LOCKS)
        self.assertEqual(kept.folders, TREE)
        resolved = resolve_decisions(proposal, {"moves": {"m1": {"leave": False}}}, TREE, NO_LOCKS)
        self.assertEqual(resolved["moves"], {"m1": "ask"})

    def test_moving_into_a_folder_that_holds_the_site_leaves_one_entry(self):
        proposal = make_proposal(moves=[move("m1", 30, ABF, TECH)])

        result = apply_plan(TREE, proposal, {}, NO_LOCKS)

        # Read the stored list itself, since FolderTree.from_list() in apps/reorganize/plan.py drops
        # repeated ids on load.
        self.assertEqual(folder_items(result.folders, "Tech"), [30, 31, 32, 33])
        self.assertEqual(
            folder_items(result.folders, "Any Broken Feeds"), [10, 11, 12, {"Science": [20, 21]}]
        )
        self.assertEqual(result.moved, [(30, ["Any Broken Feeds"], ["Tech"])])


class Test_FolderOps(unittest.TestCase):
    def test_rejected_create_leaves_its_sites_in_place(self):
        proposal = make_proposal(
            new_folders={"n0": new_folder("Apple")},
            ops=[op("op1", "create", "n0")],
            moves=[move("m1", 31, TECH, "n0"), move("m2", 32, TECH, "n0")],
        )
        decisions = {"ops": {"op1": False}, "moves": {"m1": {"arrive": True}}}

        result = apply_plan(TREE, proposal, decisions, NO_LOCKS)

        self.assertEqual(result.folders, TREE)
        self.assertEqual(result.created, [])
        self.assertEqual(result.skipped, [])
        resolved = resolve_decisions(proposal, decisions, TREE, NO_LOCKS)
        self.assertEqual(resolved["moves"], {"m1": "stay", "m2": "stay"})

    def test_merge_with_a_rejected_move_keeps_the_folder_with_that_site(self):
        proposal = make_proposal(
            ops=[op("op1", "merge", ABF, into=BLOGS)],
            moves=[
                move("m1", 10, ABF, BLOGS),
                move("m2", 11, ABF, BLOGS),
                move("m3", 12, ABF, BLOGS),
                move("m4", 30, ABF, BLOGS),
            ],
        )

        result = apply_plan(TREE, proposal, {"moves": {"m3": {"arrive": False}}}, NO_LOCKS)

        self.assertEqual(folder_items(result.folders, "Any Broken Feeds"), [12, {"Science": [20, 21]}])
        self.assertEqual(
            folder_items(result.folders, "Blogs"), [40, 41, 42, {"People": [50, 51]}, 10, 11, 30]
        )
        self.assertEqual(skips(result), {"op1": "not_empty"})
        self.assertEqual(result.merged, [])
        self.assertEqual(result.path_changes, [])

    def test_merge_whose_subfolder_name_is_taken_in_the_target_moves_no_folder(self):
        proposal = make_proposal(
            ops=[op("op1", "rename", SCIENCE, name="SCIENCE"), op("op2", "merge", ABF, into="root")],
            moves=[move("m%d" % feed_id, feed_id, ABF, "root") for feed_id in (10, 11, 12, 30)],
        )

        result = apply_plan(TREE, proposal, {}, NO_LOCKS)

        self.assertEqual(skips(result), {"op2": "name_taken"})
        self.assertEqual(folder_items(result.folders, "Any Broken Feeds"), [{"Science": [20, 21]}])
        self.assertEqual(folder_items(result.folders, "SCIENCE"), [21, 22])
        self.assertEqual(result.merged, [])
        self.assertEqual(tree_of(result).feeds_in([]), [1, 2, 10, 11, 12, 30])

    def test_remove_skips_a_folder_that_still_holds_a_site_or_folder(self):
        proposal = make_proposal(
            ops=[
                op("op1", "remove", WOOD),
                op("op2", "remove", BOSTON),
                op("op3", "remove", BLOGS),
                op("op4", "remove", NEW_YORK),
            ],
            moves=[
                move("m1", 40, BLOGS, TECH),
                move("m2", 41, BLOGS, TECH),
                move("m3", 42, BLOGS, TECH),
                move("m4", 80, NEW_YORK, TECH),
            ],
        )

        result = apply_plan(TREE, proposal, {}, NO_LOCKS)

        self.assertEqual(result.removed, [["Wood"], ["New York"]])
        self.assertEqual(skips(result), {"op2": "not_empty", "op3": "not_empty"})
        self.assertEqual(folder_items(result.folders, "Blogs"), [{"People": [50, 51]}])
        self.assertEqual(folder_items(result.folders, "Boston"), [81])

    def test_removing_a_folder_and_its_only_subfolder_removes_both(self):
        proposal = make_proposal(
            ops=[op("op1", "remove", BLOGS), op("op2", "remove", PEOPLE)],
            moves=[move("m%d" % feed_id, feed_id, BLOGS, TECH) for feed_id in (40, 41, 42)]
            + [move("m%d" % feed_id, feed_id, PEOPLE, TECH) for feed_id in (50, 51)],
        )

        result = apply_plan(TREE, proposal, {}, NO_LOCKS)

        self.assertEqual(result.skipped, [])
        self.assertEqual(result.removed, [["Blogs", "People"], ["Blogs"]])

    def test_name_clashes_and_cycles_are_skipped(self):
        proposal = make_proposal(
            ops=[
                op("op1", "rename", MOBILITY, name="boston"),
                op("op2", "nest", ABF, parent=ABF_SCIENCE),
                op("op3", "nest", ABF_SCIENCE, parent="root"),
                op("op4", "nest", ABF, parent=ABF),
            ]
        )

        result = apply_plan(TREE, proposal, {}, NO_LOCKS)

        self.assertEqual(result.folders, TREE)
        self.assertEqual(
            skips(result),
            {"op1": "name_taken", "op2": "would_cycle", "op3": "name_taken", "op4": "would_cycle"},
        )

    def test_rename_moves_and_nest_of_one_folder_compose(self):
        proposal = make_proposal(
            ops=[op("op1", "rename", BLOGS, name="Weblogs"), op("op2", "nest", BLOGS, parent=TECH)],
            moves=[move("m1", 60, BLOGLETS, BLOGS)],
        )

        result = apply_plan(TREE, proposal, {}, NO_LOCKS)

        self.assertEqual(
            folder_items(result.folders, "Tech"),
            [30, 31, 32, 33, {"Weblogs": [40, 41, 42, {"People": [50, 51]}, 60]}],
        )
        self.assertNotIn(("Blogs",), folder_paths(result.folders))
        self.assertEqual(result.moved, [(60, ["Bloglets"], ["Tech", "Weblogs"])])
        self.assertEqual(
            result.path_changes,
            [
                {"old": ["Blogs"], "new": ["Tech", "Weblogs"]},
                {"old": ["Blogs", "People"], "new": ["Tech", "Weblogs", "People"]},
            ],
        )


class Test_Locks(unittest.TestCase):
    def test_keep_lock_blocks_every_change_but_an_accepted_copy(self):
        proposal = make_proposal(
            new_folders={"n0": new_folder("Drafts", BLOGLETS)},
            ops=[
                op("op1", "rename", BLOGLETS, name="Shorts"),
                op("op2", "nest", BLOGLETS, parent=BLOGS),
                op("op3", "merge", BLOGLETS, into=BLOGS),
                op("op4", "remove", BLOGLETS),
                op("op5", "create", "n0"),
                op("op6", "nest", WOOD, parent=BLOGLETS),
            ],
            moves=[
                move("m1", 60, BLOGLETS, TECH),
                move("m2", 61, BLOGLETS, TECH),
                move("m3", 31, TECH, BLOGLETS),
                move("m4", 32, TECH, "n0"),
            ],
        )
        decisions = {"moves": {"m1": {"leave": True}, "m2": {"arrive": True, "leave": True}}}
        keep = locks(keep=[["Bloglets"]])

        result = apply_plan(TREE, proposal, decisions, keep)

        expected = copy.deepcopy(TREE)
        folder_items(expected, "Tech").append(61)
        self.assertEqual(result.folders, expected)
        self.assertEqual(result.copied, [(61, ["Bloglets"], ["Tech"])])
        self.assertEqual(
            skips(result),
            {
                "m3": "locked",
                "m4": "locked",
                "op1": "locked",
                "op2": "locked",
                "op3": "locked",
                "op4": "locked",
                "op5": "locked",
                "op6": "locked",
            },
        )
        resolved = resolve_decisions(proposal, decisions, TREE, keep)
        self.assertEqual(resolved["moves"]["m1"], "ask")
        self.assertEqual(resolved["moves"]["m2"], "both")

    def test_skip_lock_drops_moves_out_including_copies(self):
        proposal = make_proposal(moves=[move("m1", 60, BLOGLETS, TECH), move("m2", 61, BLOGLETS, TECH)])
        decisions = {"moves": {"m1": {"arrive": True, "leave": False}}}
        skip = locks(skip=[["Bloglets"]])

        result = apply_plan(TREE, proposal, decisions, skip)

        self.assertEqual(result.folders, TREE)
        self.assertEqual(skips(result), {"m1": "locked", "m2": "locked"})
        self.assertEqual(
            resolve_decisions(proposal, decisions, TREE, skip)["moves"], {"m1": "stay", "m2": "stay"}
        )

    def test_top_level_cannot_be_locked(self):
        proposal = make_proposal(moves=[move("m1", 31, TECH, "root"), move("m2", 1, "root", WOOD)])

        result = apply_plan(TREE, proposal, {}, locks(keep=[[]], skip=[[]]))

        self.assertEqual(result.skipped, [])
        self.assertEqual(tree_of(result).feeds_in([]), [2, 31])

    def test_renaming_a_folder_that_holds_a_locked_folder_is_skipped(self):
        proposal = make_proposal(
            ops=[op("op1", "rename", BLOGS, name="Weblogs"), op("op2", "nest", BLOGS, parent=TECH)]
        )

        result = apply_plan(TREE, proposal, {}, locks(keep=[["Blogs", "People"]]))

        self.assertEqual(result.folders, TREE)
        self.assertEqual(skips(result), {"op1": "locked", "op2": "locked"})


class Test_DeadSites(unittest.TestCase):
    def test_unsubscribe_mute_and_suggestions(self):
        proposal = make_proposal(
            dead=[
                dead_site("d1", 30, "unsubscribe"),
                dead_site("d2", 70, "unsubscribe"),
                dead_site("d3", 80, "unsubscribe"),
                dead_site("d4", 81, "mute"),
                dead_site("d5", 1, "mute"),
            ]
        )
        decisions = {"dead": {"d1": "unsubscribe", "d2": "mute", "d5": "keep"}}

        result = apply_plan(TREE, proposal, decisions, NO_LOCKS)

        expected = copy.deepcopy(TREE)
        folder_items(expected, "Any Broken Feeds").remove(30)
        folder_items(expected, "Tech").remove(30)
        self.assertEqual(result.folders, expected)
        self.assertEqual(result.unsubscribe_feed_ids, [30])
        self.assertEqual(result.mute_feed_ids, [70, 81])


class Test_SanitizeProposal(unittest.TestCase):
    def test_drops_items_that_could_never_apply(self):
        proposal = make_proposal(
            new_folders={"n0": new_folder("Inbox", BLOGS), "n1": new_folder("Empty")},
            moves=[
                move("m1", 61, TECH, WOOD),
                move("m2", 31, TECH, TECH),
                move("m3", 32, TECH, WOOD),
                move("m4", 32, TECH, BOSTON),
                move("m5", 60, BLOGLETS, TECH),
                move("m6", 33, TECH, BLOGS),
                move("m7", 50, PEOPLE, TECH),
                move("m8", 31, TECH, "n0"),
                move("m9", 80, NEW_YORK, WOOD),
            ],
            ops=[
                op("op1", "rename", BLOGS, name="Weblogs"),
                op("op2", "create", "n0"),
                op("op3", "nest", ABF, parent=ABF_SCIENCE),
                op("op4", "merge", TECH, into=TECH),
                op("op5", "merge", TECH, into=BLOGLETS),
                op("op6", "rename", MOBILITY, name="BOSTON"),
                op("op7", "rename", BOSTON, name="   "),
                op("op8", "rename", NEW_YORK, name="river:NYC"),
                op("op9", "remove", BOSTON),
                op("op10", "remove", NEW_YORK),
                op("op11", "remove", WOOD),
                op("op12", "create", "n1"),
                op("op13", "nest", WOOD, parent=BOSTON),
                op("op14", "nest", BOSTON, parent=WOOD),
                op("op15", "rename", MOBILITY, name="Bikes - Transit"),
                op("op16", "rename", MOBILITY, name="top level"),
                op("op17", "rename", MOBILITY, name="global"),
            ],
        )
        guarded = locks(keep=[["Blogs"]], skip=[["Bloglets"]])

        clean = sanitize_proposal(proposal, TREE, guarded)

        self.assertEqual([item["id"] for item in clean["moves"]], ["m3", "m7", "m9"])
        self.assertEqual([item["id"] for item in clean["ops"]], ["op10", "op13"])
        self.assertEqual(
            clean["folders"],
            {key: {"path": PATHS[key]} for key in (PEOPLE, TECH, WOOD, NEW_YORK, BOSTON)},
        )
        self.assertEqual(apply_plan(TREE, clean, {}, guarded).skipped, [])

    def test_create_matching_an_existing_folder_points_at_that_folder(self):
        proposal = make_proposal(
            new_folders={
                "n0": new_folder("tech"),
                "n1": new_folder("Apple"),
                "n2": new_folder("APPLE"),
                "n3": new_folder("people", BLOGS),
            },
            ops=[op("op%d" % (index + 1), "create", "n%d" % index) for index in range(4)],
            moves=[
                move("m1", 1, "root", "n0"),
                move("m2", 2, "root", "n1"),
                move("m3", 70, MOBILITY, "n2"),
                move("m4", 80, NEW_YORK, "n3"),
            ],
        )
        del proposal["folders"][TECH]

        clean = sanitize_proposal(proposal, TREE, NO_LOCKS)

        self.assertEqual([item["id"] for item in clean["ops"]], ["op2"])
        self.assertEqual([item["to"] for item in clean["moves"]], [TECH, "n1", "n1", PEOPLE])
        self.assertEqual(clean["folders"][TECH], {"path": ["Tech"]})
        self.assertNotIn("n0", clean["folders"])
        self.assertNotIn("n2", clean["folders"])
        result = apply_plan(TREE, clean, {}, NO_LOCKS)
        self.assertEqual(folder_items(result.folders, "Apple"), [2, 70])
        self.assertEqual(folder_items(result.folders, "Tech"), [30, 31, 32, 33, 1])
        self.assertEqual(folder_items(result.folders, "Blogs", "People"), [50, 51, 80])

    def test_dead_entries_for_unknown_or_locked_sites_are_dropped(self):
        proposal = make_proposal(
            dead=[
                dead_site("d1", 999, "mute"),
                dead_site("d2", 50, "mute"),
                dead_site("d3", 30, "archive"),
                dead_site("d4", 30, "unsubscribe"),
                dead_site("d5", 81, "unsubscribe"),
            ]
        )

        clean = sanitize_proposal(proposal, TREE, locks(keep=[["Blogs"]]))

        self.assertEqual(
            [(item["id"], item["suggest"]) for item in clean["dead"]], [("d3", "mute"), ("d5", "unsubscribe")]
        )


# A proposal over TREE that touches nearly every site and folder.
BROAD_PROPOSAL = make_proposal(
    new_folders={"n0": new_folder("Apple"), "n1": new_folder("Reading"), "n2": new_folder("Local", "n1")},
    ops=[
        op("c0", "create", "n0"),
        op("c1", "create", "n1"),
        op("c2", "create", "n2"),
        op("r0", "rename", MOBILITY, name="Bikes & Transit"),
        op("r1", "rename", WOOD, name="Woodworking"),
        op("s0", "nest", NEW_YORK, parent="n2"),
        op("s1", "nest", BOSTON, parent="n2"),
        op("s2", "nest", PEOPLE, parent="n1"),
        op("g0", "merge", BLOGLETS, into=BLOGS),
        op("g1", "merge", ABF, into=TECH),
        op("x0", "remove", WOOD),
        op("x1", "remove", SCIENCE),
    ],
    moves=[
        move("m0", 31, TECH, "n0"),
        move("m1", 32, TECH, "n0"),
        move("m2", 60, BLOGLETS, BLOGS),
        move("m3", 61, BLOGLETS, BLOGS),
        move("m4", 10, ABF, TECH),
        move("m5", 11, ABF, TECH),
        move("m6", 12, ABF, TECH),
        move("m7", 30, ABF, TECH),
        move("m8", 21, SCIENCE, ABF_SCIENCE),
        move("m9", 22, SCIENCE, ABF_SCIENCE),
        move("m10", 40, BLOGS, "n1"),
        move("m11", 1, "root", "n1"),
        move("m12", 70, MOBILITY, "root"),
        move("m13", 50, PEOPLE, "root"),
        move("m14", 80, NEW_YORK, "n2"),
        move("m15", 2, "root", WOOD),
    ],
    dead=[
        dead_site("d0", 33, "unsubscribe"),
        dead_site("d1", 41, "mute"),
        dead_site("d2", 81, "unsubscribe"),
        dead_site("d3", 20, "mute"),
        dead_site("d4", 30, "unsubscribe"),
    ],
)


class Test_RandomPlans(unittest.TestCase):
    def test_random_decisions_and_locks_keep_every_invariant(self):
        start = FolderTree.from_list(TREE)
        for seed in range(300):
            rng = random.Random(seed)
            keep, skip = [], []
            for path in PATHS.values():
                roll = rng.random()
                if roll < 0.15:
                    keep.append(path)
                elif roll < 0.25:
                    skip.append(path)
            guarded = locks(keep=keep, skip=skip)
            proposal = sanitize_proposal(BROAD_PROPOSAL, TREE, guarded) if seed % 2 else BROAD_PROPOSAL
            decisions = {
                "moves": {
                    item["id"]: {
                        "arrive": rng.choice([True, False, None]),
                        "leave": rng.choice([True, False, None]),
                    }
                    for item in proposal["moves"]
                },
                "ops": {item["id"]: False for item in proposal["ops"] if rng.random() < 0.3},
                "dead": {
                    item["id"]: rng.choice(["keep", "mute", "unsubscribe", None]) for item in proposal["dead"]
                },
            }

            with self.subTest(seed=seed):
                result = apply_plan(TREE, proposal, decisions, guarded)
                end = tree_of(result)

                explicit_unsubscribes = {
                    item["feed_id"]
                    for item in proposal["dead"]
                    if decisions["dead"][item["id"]] == "unsubscribe"
                }
                self.assertLessEqual(set(result.unsubscribe_feed_ids), explicit_unsubscribes)
                self.assertEqual(end.feed_ids(), start.feed_ids() - set(result.unsubscribe_feed_ids))

                final_paths = folder_paths(result.folders)
                for path in keep + skip:
                    for locked in [path] + [p for p in PATHS.values() if p[: len(path)] == path]:
                        self.assertIn(tuple(locked), final_paths)
                        self.assertEqual(end.feeds_in(locked), start.feeds_in(locked))
                        self.assertEqual(child_paths(end, locked), child_paths(start, locked))

                for path in result.created:
                    self.assertTrue(end.feeds_in(path) or child_paths(end, path))

                changed = {tuple(change["old"]): tuple(change["new"]) for change in result.path_changes}
                gone = {tuple(path) for path in result.removed} | {tuple(m["old"]) for m in result.merged}
                kept = {tuple(path) for path in PATHS.values()} - gone
                expected = {changed.get(path, path) for path in kept} | {
                    tuple(path) for path in result.created
                }
                self.assertEqual(final_paths, expected)
                self.assertEqual(len(final_paths), len(kept) + len(result.created))

                for path in [[]] + list(end.folder_keys().values()):
                    names = [child[-1].lower() for child in child_paths(end, path)]
                    self.assertEqual(len(names), len(set(names)))


SNAPSHOT = [1, {"Tech": [2, 3]}, {"Blogs": [4, {"People": [5]}]}, {"Old": [6]}]


class Test_RestoreFolders(unittest.TestCase):
    def test_a_site_added_since_stays_in_a_folder_the_snapshot_has_and_otherwise_goes_to_the_top(self):
        # 7 to 11 were subscribed to since the snapshot, and 12 is listed without a subscription.
        current = [
            1,
            7,
            {"Gadgets": [2, 3, 8, 9, 11, 12]},
            {"Blogs": [4, 9, {"People": [5, 10]}]},
            {"Old": [6, 8]},
            {"News": [11]},
        ]

        restored = restore_folders(SNAPSHOT, current, range(1, 12))

        self.assertEqual(
            restored,
            [1, {"Tech": [2, 3]}, {"Blogs": [4, {"People": [5, 10]}, 9]}, {"Old": [6, 8]}, 7, 11],
        )


if __name__ == "__main__":
    unittest.main()
