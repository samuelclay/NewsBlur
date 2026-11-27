"""Merge a user's decisions on a reorganization proposal, and carry them into a revision of it.

Decisions take the shape apps/reorganize/plan.py reads: {"ops": {op id: False}, "moves": {move id:
{"arrive": bool, "leave": bool}}, "dead": {dead id: "keep" | "mute" | "unsubscribe"}}. Every item
without a decision is approved, so stored decisions hold only the choices a user made, and both
functions here return all three sections.

When a proposal is revised its items get new ids and its folders new keys, so carry_decisions()
matches items by what they change. Folders are matched by identity: an existing folder by the path
the proposal recorded for it, a new folder by its name and its parent's identity.

This module imports only the standard library and apps/reorganize/plan.py.
"""

from apps.reorganize.plan import DEAD_ACTIONS, ROOT_KEY, SECTIONS, is_feed_id

MOVE_SIDES = ("arrive", "leave")


def merge_decisions(stored, changes, proposal):
    """The stored decisions with `changes`, which holds only what the user just changed, merged in.

    A move change is {"arrive": ..., "leave": ...} with either key optional, each true, false, or
    null to clear that side. An op change is false to reject, or null or true to clear the
    rejection. A dead site change is one of DEAD_ACTIONS, or null to clear. Ids that are not in
    `proposal` and values of the wrong type are dropped, and an entry left with nothing set is
    removed.
    """
    ids = {section: _entry_ids(proposal, section) for section in SECTIONS}
    merged = {section: {} for section in SECTIONS}
    stored = _as_dict(stored)
    for section in SECTIONS:
        for entry_id, value in _as_dict(stored.get(section)).items():
            if entry_id in ids[section]:
                _set_choice(merged[section], section, entry_id, value)

    changes = _as_dict(changes)
    for section in SECTIONS:
        for entry_id, change in _as_dict(changes.get(section)).items():
            if entry_id in ids[section]:
                _change_choice(merged[section], section, entry_id, change)
    return merged


def carry_decisions(old_proposal, old_decisions, new_proposal):
    """Decisions for `new_proposal`, a revision of `old_proposal`: each decision in `old_decisions`
    moves to the item of the new proposal that makes the same change, and the rest are dropped.

    Moves are the same with the same site, source folder and destination folder. Ops are the same
    with the same type and folder, and for a rename the same new name, for a merge the same folder
    merged into, for a nest the same new parent. Dead sites are the same with the same site.
    """
    old_decisions = merge_decisions(old_decisions, {}, old_proposal)
    old_change = _change_identities(old_proposal)
    decided = {}
    for section in SECTIONS:
        for entry_id, value in old_decisions[section].items():
            identity = old_change[section].get(entry_id)
            if identity is not None:
                decided.setdefault((section, identity), value)

    carried = {section: {} for section in SECTIONS}
    for section, identities in _change_identities(new_proposal).items():
        for entry_id, identity in identities.items():
            if (section, identity) in decided:
                carried[section][entry_id] = decided[(section, identity)]
    return merge_decisions({}, carried, new_proposal)


def _set_choice(entries, section, entry_id, value):
    """Store an already merged choice, if it is one."""
    if section == "moves":
        sides = {
            side: value[side] for side in MOVE_SIDES if isinstance(value, dict) and _is_bool(value.get(side))
        }
        if sides:
            entries[entry_id] = sides
    elif section == "ops":
        if value is False:
            entries[entry_id] = False
    elif _is_dead_action(value):
        entries[entry_id] = value


def _change_choice(entries, section, entry_id, change):
    if section == "moves":
        if not isinstance(change, dict):
            return
        sides = dict(entries.get(entry_id, {}))
        for side in MOVE_SIDES:
            if side not in change:
                continue
            if change[side] is None:
                sides.pop(side, None)
            elif _is_bool(change[side]):
                sides[side] = change[side]
        if sides:
            entries[entry_id] = sides
        else:
            entries.pop(entry_id, None)
    elif section == "ops":
        if change is False:
            entries[entry_id] = False
        elif change is None or change is True:
            entries.pop(entry_id, None)
    elif change is None:
        entries.pop(entry_id, None)
    elif _is_dead_action(change):
        entries[entry_id] = change


def _change_identities(proposal):
    """{section: {entry id: what the entry changes}}, for comparing items across proposals.

    An entry whose folders cannot be identified gets no identity and never matches.
    """
    folder = _folder_identities(proposal)
    identities = {section: {} for section in SECTIONS}

    for entry in _entries(proposal, "moves"):
        source, destination = folder(entry.get("from")), folder(entry.get("to"))
        if is_feed_id(entry.get("feed_id")) and source is not None and destination is not None:
            identities["moves"][entry["id"]] = (entry["feed_id"], source, destination)

    for entry in _entries(proposal, "ops"):
        op_type, target = entry.get("type"), folder(entry.get("folder"))
        if op_type == "rename":
            detail = entry.get("name") if isinstance(entry.get("name"), str) else None
        elif op_type == "merge":
            detail = folder(entry.get("into"))
        elif op_type == "nest":
            detail = folder(entry.get("parent"))
        else:
            detail = op_type
        if isinstance(op_type, str) and target is not None and detail is not None:
            identities["ops"][entry["id"]] = (op_type, target, detail)

    for entry in _entries(proposal, "dead"):
        if is_feed_id(entry.get("feed_id")):
            identities["dead"][entry["id"]] = entry["feed_id"]
    return identities


def _folder_identities(proposal):
    """A function from a folder key of `proposal` to that folder's identity, or None if it has none."""
    folders = _as_dict(_as_dict(proposal).get("folders"))

    def identity(key, visiting=frozenset()):
        if key == ROOT_KEY:
            return (ROOT_KEY,)
        entry = folders.get(key) if isinstance(key, str) else None
        if not isinstance(entry, dict) or key in visiting:
            return None
        if _is_existing_key(key):
            path = entry.get("path")
            if isinstance(path, list) and path and all(isinstance(name, str) for name in path):
                return ("existing", tuple(path))
            return None
        if _is_new_key(key) and isinstance(entry.get("name"), str):
            parent = identity(entry.get("parent"), visiting | {key})
            return ("new", entry["name"], parent) if parent is not None else None
        return None

    return identity


def _entry_ids(proposal, section):
    return {entry["id"] for entry in _entries(proposal, section)}


def _entries(proposal, section):
    raw = _as_dict(proposal).get(section)
    return [
        entry
        for entry in (raw if isinstance(raw, list) else [])
        if isinstance(entry, dict) and isinstance(entry.get("id"), str)
    ]


def _is_bool(value):
    return isinstance(value, bool)


def _is_dead_action(value):
    return isinstance(value, str) and value in DEAD_ACTIONS


def _is_existing_key(key):
    return key[:1] == "e" and key[1:].isdigit()


def _is_new_key(key):
    return key[:1] == "n" and key[1:].isdigit()


def _as_dict(value):
    return value if isinstance(value, dict) else {}
