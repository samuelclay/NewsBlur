"""Tests for apps/reorganize/decisions.py, which merges a user's decisions on a proposal and carries
them into a revision of it."""

import unittest

from apps.reorganize.decisions import carry_decisions, merge_decisions

GADGETS, PHONES, TABLETS, SILENT, QUIET = 11, 12, 13, 14, 15


def move(move_id, feed_id, source, destination):
    return {"id": move_id, "feed_id": feed_id, "from": source, "to": destination, "reason": "fits"}


def op(op_id, op_type, folder, **fields):
    return {"id": op_id, "type": op_type, "folder": folder, "reason": "tidier", **fields}


def dead(dead_id, feed_id):
    return {"id": dead_id, "feed_id": feed_id, "reason": "", "suggest": "mute", "cause": "quiet"}


def proposal(folders, ops=(), moves=(), dead_sites=()):
    return {"folders": folders, "ops": list(ops), "moves": list(moves), "dead": list(dead_sites)}


def decided(ops=None, moves=None, dead_sites=None):
    return {"ops": ops or {}, "moves": moves or {}, "dead": dead_sites or {}}


REVIEWED = proposal(
    {"e0": {"path": ["Tech"]}, "e1": {"path": ["Sorted"]}, "n0": {"name": "Handsets", "parent": "root"}},
    ops=[op("op1", "create", "n0"), op("op2", "rename", "e1", name="Filed")],
    moves=[move("m1", GADGETS, "e0", "e1"), move("m2", PHONES, "e0", "n0")],
    dead_sites=[dead("d1", SILENT)],
)


class Test_MergeDecisions(unittest.TestCase):
    def test_each_side_of_a_move_is_set_on_its_own_and_null_clears_it(self):
        stored = merge_decisions({}, {"moves": {"m1": {"arrive": True}}}, REVIEWED)
        stored = merge_decisions(
            stored, {"moves": {"m1": {"leave": False}, "m2": {"arrive": False}}}, REVIEWED
        )
        self.assertEqual(
            stored, decided(moves={"m1": {"arrive": True, "leave": False}, "m2": {"arrive": False}})
        )

        stored = merge_decisions(stored, {"moves": {"m1": {"arrive": None}}}, REVIEWED)
        self.assertEqual(stored, decided(moves={"m1": {"leave": False}, "m2": {"arrive": False}}))

        stored = merge_decisions(stored, {"moves": {"m1": {"leave": None}}}, REVIEWED)
        self.assertEqual(stored, decided(moves={"m2": {"arrive": False}}))

    def test_false_rejects_an_op_and_null_or_true_clears_the_rejection(self):
        stored = merge_decisions({}, {"ops": {"op1": False, "op2": False}}, REVIEWED)
        self.assertEqual(stored, decided(ops={"op1": False, "op2": False}))

        stored = merge_decisions(stored, {"ops": {"op1": None, "op2": True}}, REVIEWED)
        self.assertEqual(stored, decided())

    def test_a_dead_site_takes_one_action_and_null_clears_it(self):
        for action in ("keep", "mute", "unsubscribe"):
            stored = merge_decisions({}, {"dead": {"d1": action}}, REVIEWED)
            self.assertEqual(stored, decided(dead_sites={"d1": action}))

        self.assertEqual(merge_decisions(stored, {"dead": {"d1": None}}, REVIEWED), decided())

    def test_unknown_ids_and_wrong_typed_values_are_dropped_and_the_rest_applies(self):
        stored = merge_decisions({}, {"ops": {"op1": False}}, REVIEWED)
        changes = {
            "moves": {
                "m9": {"arrive": False},
                "m1": {"arrive": "no", "leave": False},
                "m2": {"arrive": 0},
                "op1": {"arrive": False},
            },
            "ops": {"op9": False, "op2": "reject", "m1": False, "op1": 0},
            "dead": {"d1": "delete", "d9": "mute"},
            "folders": {"e0": False},
        }

        stored = merge_decisions(stored, changes, REVIEWED)

        self.assertEqual(stored, decided(ops={"op1": False}, moves={"m1": {"leave": False}}))


class Test_CarryDecisions(unittest.TestCase):
    def test_a_move_keeps_its_decision_when_folder_keys_are_renumbered(self):
        old = proposal(
            {"e0": {"path": ["Tech"]}, "e1": {"path": ["Sorted"]}},
            moves=[move("m1", GADGETS, "e0", "e1"), move("m2", PHONES, "e1", "e0")],
        )
        # A folder added ahead of Tech shifts every key, and e1 now names Tech instead of Sorted.
        new = proposal(
            {"e0": {"path": ["Inbox"]}, "e1": {"path": ["Tech"]}, "e2": {"path": ["Sorted"]}},
            moves=[move("m1", PHONES, "e2", "e1"), move("m2", GADGETS, "e1", "e2")],
        )
        old_decisions = decided(moves={"m1": {"arrive": False}, "m2": {"leave": False}})

        carried = carry_decisions(old, old_decisions, new)

        self.assertEqual(carried, decided(moves={"m2": {"arrive": False}, "m1": {"leave": False}}))

    def test_a_folder_at_the_same_key_but_another_path_is_another_folder(self):
        old = proposal(
            {"e0": {"path": ["Tech"]}, "e1": {"path": ["Sorted"]}}, moves=[move("m1", GADGETS, "e0", "e1")]
        )
        new = proposal(
            {"e0": {"path": ["Tech"]}, "e1": {"path": ["Filed"]}}, moves=[move("m1", GADGETS, "e0", "e1")]
        )

        carried = carry_decisions(old, decided(moves={"m1": {"arrive": False}}), new)

        self.assertEqual(carried, decided())

    def test_a_new_folder_that_keeps_its_name_keeps_the_decisions_about_it(self):
        old = proposal(
            {
                "e0": {"path": ["Tech"]},
                "n0": {"name": "Handsets", "parent": "root"},
                "n1": {"name": "Tablets", "parent": "n0"},
            },
            ops=[op("op1", "create", "n0"), op("op2", "create", "n1")],
            moves=[move("m1", PHONES, "e0", "n0"), move("m2", TABLETS, "e0", "n1")],
        )
        # The revision adds a folder of its own first, so the same new folders get other keys.
        new = proposal(
            {
                "e0": {"path": ["Tech"]},
                "n0": {"name": "Wearables", "parent": "root"},
                "n1": {"name": "Handsets", "parent": "root"},
                "n2": {"name": "Tablets", "parent": "n1"},
            },
            ops=[op("op1", "create", "n0"), op("op2", "create", "n1"), op("op3", "create", "n2")],
            moves=[
                move("m1", GADGETS, "e0", "n0"),
                move("m2", PHONES, "e0", "n1"),
                move("m3", TABLETS, "e0", "n2"),
            ],
        )
        old_decisions = decided(
            ops={"op1": False, "op2": False}, moves={"m1": {"arrive": True}, "m2": {"leave": False}}
        )

        carried = carry_decisions(old, old_decisions, new)

        self.assertEqual(
            carried,
            decided(ops={"op2": False, "op3": False}, moves={"m2": {"arrive": True}, "m3": {"leave": False}}),
        )

    def test_a_renamed_new_folder_and_the_new_folders_inside_it_lose_their_decisions(self):
        old = proposal(
            {
                "e0": {"path": ["Tech"]},
                "n0": {"name": "Handsets", "parent": "root"},
                "n1": {"name": "Tablets", "parent": "n0"},
            },
            ops=[op("op1", "create", "n0"), op("op2", "create", "n1")],
            moves=[move("m1", PHONES, "e0", "n0"), move("m2", TABLETS, "e0", "n1")],
        )
        new = proposal(
            {
                "e0": {"path": ["Tech"]},
                "n0": {"name": "Mobile", "parent": "root"},
                "n1": {"name": "Tablets", "parent": "n0"},
            },
            ops=[op("op1", "create", "n0"), op("op2", "create", "n1")],
            moves=[move("m1", PHONES, "e0", "n0"), move("m2", TABLETS, "e0", "n1")],
        )
        old_decisions = decided(
            ops={"op1": False, "op2": False}, moves={"m1": {"arrive": False}, "m2": {"arrive": False}}
        )

        self.assertEqual(carry_decisions(old, old_decisions, new), decided())

    def test_a_move_whose_destination_changes_loses_its_decision(self):
        folders = {
            "e0": {"path": ["Tech"]},
            "e1": {"path": ["Sorted"]},
            "n0": {"name": "Handsets", "parent": "root"},
        }
        old = proposal(folders, ops=[op("op1", "create", "n0")], moves=[move("m1", PHONES, "e0", "e1")])
        new = proposal(folders, ops=[op("op1", "create", "n0")], moves=[move("m1", PHONES, "e0", "n0")])

        carried = carry_decisions(old, decided(moves={"m1": {"arrive": False}}), new)

        self.assertEqual(carried, decided())

    def test_an_op_keeps_its_decision_only_with_the_same_name_target_or_parent(self):
        folders = {
            "e0": {"path": ["Tech"]},
            "e1": {"path": ["Sorted"]},
            "e2": {"path": ["Old"]},
            "e3": {"path": ["Misc"]},
            "e4": {"path": ["Archive"]},
            "e5": {"path": ["Reading"]},
        }
        old = proposal(
            folders,
            ops=[
                op("op1", "rename", "e0", name="Technology"),
                op("op2", "rename", "e1", name="Filed"),
                op("op3", "merge", "e2", into="e1"),
                op("op4", "merge", "e3", into="e1"),
                op("op5", "nest", "e4", parent="e0"),
                op("op6", "remove", "e3"),
                op("op7", "nest", "e5", parent="e1"),
            ],
        )
        new = proposal(
            folders,
            ops=[
                op("op1", "nest", "e4", parent="e1"),
                op("op2", "merge", "e3", into="e1"),
                op("op3", "merge", "e2", into="e0"),
                op("op4", "rename", "e1", name="Done"),
                op("op5", "rename", "e0", name="Technology"),
                op("op6", "remove", "e3"),
                op("op7", "nest", "e5", parent="e1"),
            ],
        )
        rejected_all = decided(ops={"op%d" % index: False for index in range(1, 8)})

        carried = carry_decisions(old, rejected_all, new)

        self.assertEqual(carried, decided(ops={"op2": False, "op5": False, "op6": False, "op7": False}))

    def test_a_dead_site_keeps_its_decision_while_the_revision_still_lists_it(self):
        old = proposal({}, dead_sites=[dead("d1", SILENT), dead("d2", QUIET)])
        new = proposal({}, dead_sites=[dead("d1", QUIET)])

        carried = carry_decisions(old, decided(dead_sites={"d1": "unsubscribe", "d2": "keep"}), new)

        self.assertEqual(carried, decided(dead_sites={"d1": "keep"}))
