"""Turn a model's answer about a user's sites and folders into a proposal for apps/reorganize/plan.py.

model_view() is what the model may see: the open folders by key, and where each site it may file
sits. The model answers with targets (the folders the result should have) and assignments (one
folder per site); dead sites come from the rule in apps/reorganize/sites.py. build_proposal()
resolves all of that against the stored folders into a proposal in plan.py's shape. The answer may be malformed or name folders and sites that do not
exist; whatever cannot be used is dropped.

This module imports only the standard library and apps/reorganize/plan.py.
"""

import re
from dataclasses import dataclass, field
from typing import Optional

from apps.reorganize.plan import (
    ROOT_KEY,
    FolderTree,
    apply_plan,
    clean_folder_name,
    is_feed_id,
    lock_for,
    sanitize_proposal,
)

REASON_LIMIT = 200

# Why a dead site looks dead, and the month of its latest story as "YYYY-MM". The interface writes
# its sentence from these, so a dead entry carries no prose of its own.
DEAD_CAUSES = ("failing", "quiet")
MONTH_PATTERN = re.compile(r"\d{4}-(0[1-9]|1[0-2])")


def model_view(folders, locks):
    """The open folders and the sites the model may file, for a stored folder list and its locks.

    "folders" lists every unlocked folder as {"key", "path", "sites"} in document order, where
    "sites" counts the sites directly in it. "sites" maps each feed id with a placement outside the
    "skip" folders to {"folders": keys of its open placements, "copy_only": bool}. A site whose
    visible placements are all in "keep" folders is copy_only and shows no folders, so the model can
    offer it to an open folder as a copy without learning where it is locked.
    """
    tree = FolderTree.from_list(folders)
    open_folders = [
        {"key": key, "path": path, "sites": len(tree.feeds_in(path))}
        for key, path in tree.folder_keys().items()
        if lock_for(path, locks) is None
    ]
    return {"folders": open_folders, "sites": _visible_sites(_placements(tree, locks))}


def build_proposal(folders, locks, targets, assignments, dead, allow_folder_changes=True):
    """A proposal for `folders` from the model's targets, assignments and dead sites.

    The result has been through sanitize_proposal, and apply_plan with no decisions skips none of
    it. A target named like an open folder directly under its parent is that folder and keeps its
    name. With allow_folder_changes False the targets are ignored and no folder op is proposed, so
    sites are only filed into folders the user already has. An answer with nothing usable gives an
    empty proposal.
    """
    tree = FolderTree.from_list(folders)
    paths = tree.folder_keys()
    placements = _placements(tree, locks)
    sites = _visible_sites(placements)

    resolved = _resolve_targets(targets, paths, locks) if allow_folder_changes else []
    filed = _filed_sites(assignments, sites, _destinations(resolved, paths))
    dead_sites = _dead_sites(dead, sites)
    if not (resolved or filed or dead_sites):
        return {"folders": {}, "ops": [], "moves": [], "dead": []}

    new_folders, ops = _folder_ops(resolved, paths)
    merges = [entry for entry in ops if entry["type"] == "merge"]
    proposal = {
        "folders": {**{key: {"path": path} for key, path in paths.items()}, **new_folders},
        "ops": _numbered(ops, "op"),
        "moves": _numbered(_site_moves(filed, placements, merges, tree, paths), "m"),
        "dead": _numbered(dead_sites, "d"),
    }
    proposal = sanitize_proposal(proposal, folders, locks)
    if allow_folder_changes:
        proposal = _with_removes(proposal, folders, locks, paths, next_op=len(ops) + 1)
    return proposal


@dataclass
class _Target:
    """One folder of the model's answer, resolved against the stored tree."""

    id: str
    name: Optional[str]  # None when the answer gave no usable name
    parent: Optional[str]  # the parent target's id, or None for the top level
    continues: list  # the open existing folder keys the answer says it carries on, deduplicated
    reason: str
    claims: list = field(default_factory=list)  # the keys it carries on; the first is the folder itself
    keeps_name: bool = False  # it is the folder its name already names under its parent
    key: str = ""
    parent_key: str = ROOT_KEY
    depth: int = 0


def _resolve_targets(targets, paths, locks):
    """The usable targets, in answer order, each with its claims, folder key, parent key and depth."""
    open_paths = {key: path for key, path in paths.items() if lock_for(path, locks) is None}
    resolved = _usable_targets(targets, open_paths)
    parents = _parents_without_cycles(resolved)
    _set_depths(resolved, parents)

    # A name claim can take a key that another target got through continues, and that target's key
    # decides what its own subfolders can claim by name. So claim again, holding back every key
    # claimed by name so far, until a pass claims nothing new by name.
    by_name = _open_folders_by_name(open_paths, paths)
    reserved = set()
    while True:
        named = _claim_keys(resolved, parents, by_name, reserved)
        if named <= reserved:
            break
        reserved |= named

    # A target left with no folder and no name to create one is dropped, and its subfolders go to
    # the top level, as _claim_keys already treated them.
    resolved = [target for target in resolved if target.claims or target.name is not None]
    kept_ids = {target.id for target in resolved}
    parents = {
        target.id: parents[target.id] if parents[target.id] in kept_ids else None for target in resolved
    }
    _set_depths(resolved, parents)

    new_index = 0
    for target in resolved:
        if target.claims:
            target.key = target.claims[0]
        else:
            target.key = "n%d" % new_index
            new_index += 1
    by_id = {target.id: target for target in resolved}
    for target in resolved:
        target.parent = parents[target.id]
        target.parent_key = by_id[target.parent].key if target.parent is not None else ROOT_KEY
    return resolved


def _usable_targets(targets, open_paths):
    """Targets with a string id seen for the first time and a usable name or an open continues key."""
    usable, seen_ids = [], set()
    for entry in _dict_entries(targets):
        target_id = entry.get("id")
        if not isinstance(target_id, str) or target_id == ROOT_KEY or target_id in seen_ids:
            continue
        continues = []
        raw_continues = entry.get("continues")
        for key in raw_continues if isinstance(raw_continues, list) else []:
            if isinstance(key, str) and key in open_paths and key not in continues:
                continues.append(key)
        name = clean_folder_name(entry.get("name"))
        if not continues and name is None:
            continue
        seen_ids.add(target_id)
        parent = entry.get("parent")
        usable.append(
            _Target(
                id=target_id,
                name=name,
                parent=parent if isinstance(parent, str) else None,
                continues=continues,
                reason=_reason(entry.get("reason")),
            )
        )
    return usable


def _claim_keys(resolved, parents, by_name, reserved):
    """Set each target's claims for one pass and return the keys claimed by name.

    Each continues key goes to the first target in answer order that lists it, unless it is
    reserved. Then, parents first, a target whose parent is an existing folder or the top level
    claims the open folder of its name directly under that parent, ahead of its continues keys,
    so the answer never renames a folder away from a name it also creates in the same place.
    """
    claimed = set(reserved)
    for target in resolved:
        target.claims = [key for key in target.continues if key not in claimed]
        target.keeps_name = False
        claimed.update(target.claims)

    by_id = {target.id: target for target in resolved}
    named = set()
    for target in sorted(resolved, key=lambda target: target.depth):
        parent = by_id.get(parents[target.id])
        if parent is None or (not parent.claims and parent.name is None):
            parent_key = ROOT_KEY
        else:
            # A parent that will be a new folder has no existing subfolders to claim.
            parent_key = parent.claims[0] if parent.claims else None
        key = by_name.get((parent_key, target.name.lower())) if target.name is not None else None
        if key is not None and key not in named:
            named.add(key)
            target.claims = [key] + [other for other in target.claims if other != key]
            target.keeps_name = True
    return named


def _open_folders_by_name(open_paths, paths):
    """{(parent key, lower-cased name): key} for every open folder, the first in document order."""
    key_for_path = {tuple(path): key for key, path in paths.items()}
    by_name = {}
    for key, path in open_paths.items():
        parent_key = key_for_path[tuple(path[:-1])] if len(path) > 1 else ROOT_KEY
        by_name.setdefault((parent_key, path[-1].lower()), key)
    return by_name


def _set_depths(resolved, parents):
    for target in resolved:
        target.depth, ancestor = 0, parents[target.id]
        while ancestor is not None:
            target.depth += 1
            ancestor = parents[ancestor]


def _parents_without_cycles(resolved):
    """{target id: parent target id or None}. A parent that is unknown, or that would close a cycle
    with the targets listed before it, becomes None, the top level."""
    known_ids = {target.id for target in resolved}
    parents = {}
    for target in resolved:
        parent = target.parent if target.parent in known_ids else None
        ancestor = parent
        while ancestor is not None and ancestor != target.id:
            ancestor = parents.get(ancestor)
        parents[target.id] = None if ancestor == target.id else parent
    return parents


def _destinations(resolved, paths):
    """The folder key each usable assignment "folder" value files a site into."""
    destinations = {key: key for key in paths}
    # A folder a target merges away files into the folder it merges into, so the merge can still empty it.
    for target in resolved:
        for key in target.claims:
            destinations[key] = target.key
    destinations.update({target.id: target.key for target in resolved})
    destinations[ROOT_KEY] = ROOT_KEY
    return destinations


def _filed_sites(assignments, sites, destinations):
    """{feed id: (destination key, reason)} from the first usable assignment for each visible site."""
    filed = {}
    for entry in _dict_entries(assignments):
        feed_id, folder = entry.get("feed_id"), entry.get("folder")
        if not is_feed_id(feed_id) or feed_id not in sites or feed_id in filed:
            continue
        if isinstance(folder, str) and folder in destinations:
            filed[feed_id] = (destinations[folder], _reason(entry.get("reason")))
    return filed


def _dead_sites(dead, sites):
    entries, seen = [], set()
    for entry in _dict_entries(dead):
        feed_id = entry.get("feed_id")
        if not is_feed_id(feed_id) or feed_id not in sites or feed_id in seen:
            continue
        seen.add(feed_id)
        suggest = "unsubscribe" if entry.get("suggest") == "unsubscribe" else "mute"
        since = entry.get("since")
        entries.append(
            {
                "feed_id": feed_id,
                "reason": _reason(entry.get("reason")),
                "suggest": suggest,
                "cause": entry.get("cause") if entry.get("cause") in DEAD_CAUSES else None,
                "since": since if isinstance(since, str) and MONTH_PATTERN.fullmatch(since) else None,
            }
        )
    return entries


def _folder_ops(resolved, paths):
    """New folder entries and the create, rename, nest and merge ops the targets need, in that order."""
    key_for_path = {tuple(path): key for key, path in paths.items()}
    new_folders, creates, renames, nesting, merges = {}, [], [], [], []
    for target in resolved:
        if not target.claims:
            new_folders[target.key] = {"name": target.name, "parent": target.parent_key}
            creates.append({"type": "create", "folder": target.key, "reason": target.reason})
            continue
        path = paths[target.key]
        if not target.keeps_name and target.name is not None and target.name != path[-1]:
            renames.append(
                {"type": "rename", "folder": target.key, "name": target.name, "reason": target.reason}
            )
        current_parent = key_for_path[tuple(path[:-1])] if len(path) > 1 else ROOT_KEY
        if target.parent_key != current_parent:
            nesting.append(target)
        for key in target.claims[1:]:
            merges.append({"type": "merge", "folder": key, "into": target.key, "reason": target.reason})

    # Shallowest first, so a folder moving under its own former subfolder finds that subfolder
    # already moved out of it.
    nesting.sort(key=lambda target: target.depth)
    nests = [
        {"type": "nest", "folder": target.key, "parent": target.parent_key, "reason": target.reason}
        for target in nesting
    ]
    return new_folders, creates + renames + nests + merges


def _site_moves(filed, placements, merges, tree, paths):
    """A move for each filed site not yet in its destination, then the moves that empty merged folders."""
    moves = []
    for feed_id, (destination, reason) in filed.items():
        homes = placements[feed_id]
        if any(key == destination for key, _ in homes):
            continue
        open_homes = [key for key, lock in homes if lock is None]
        # A site only in "keep" folders leaves its first one, which apply_plan offers as a copy.
        source = open_homes[0] if open_homes else next(key for key, lock in homes if lock == "keep")
        moves.append({"feed_id": feed_id, "from": source, "to": destination, "reason": reason})

    filed_moves = {(move["feed_id"], move["from"]) for move in moves}
    for merge in merges:
        for feed_id in tree.feeds_in(paths[merge["folder"]]):
            if (feed_id, merge["folder"]) not in filed_moves:
                moves.append({"feed_id": feed_id, "from": merge["folder"], "to": merge["into"], "reason": ""})
    return moves


def _with_removes(proposal, folders, locks, paths, next_op):
    """The proposal plus a remove op for every open folder it leaves with no sites and no folders."""
    proposed = set()
    while True:
        empty = [key for key in _empty_open_folders(proposal, folders, locks, paths) if key not in proposed]
        if not empty:
            return proposal
        for key in empty:
            proposal["folders"][key] = {"path": paths[key]}
            proposal["ops"].append({"id": "op%d" % next_op, "type": "remove", "folder": key, "reason": ""})
            next_op += 1
        proposed.update(empty)
        # A folder that held only the folders just removed is empty on the next pass.
        proposal = sanitize_proposal(proposal, folders, locks)


def _empty_open_folders(proposal, folders, locks, paths):
    """Keys of the open existing folders the proposal leaves empty, leaving out folders it merges away.

    Every move is accepted, as sanitize_proposal in apps/reorganize/plan.py accepts them, so a folder
    that gains a copy is not empty. No site is unsubscribed, since that waits on the user.
    """
    decisions = {
        "moves": {entry["id"]: {"arrive": True} for entry in proposal["moves"]},
        "dead": {entry["id"]: "keep" for entry in proposal["dead"]},
    }
    result = apply_plan(folders, proposal, decisions, locks)
    after = FolderTree.from_list(result.folders)
    after_paths = list(after.folder_keys().values())
    gone = result.removed + [merge["old"] for merge in result.merged]
    final_paths = {tuple(change["old"]): change["new"] for change in result.path_changes}

    empty = []
    for key, path in paths.items():
        if path in gone or lock_for(path, locks) is not None:
            continue
        final = final_paths.get(tuple(path), path)
        holds_folder = any(other[:-1] == final for other in after_paths)
        if final in after_paths and not holds_folder and not after.feeds_in(final):
            empty.append(key)
    return empty


def _placements(tree, locks):
    """{feed id: [(folder key, lock), ...]} in document order, with "root" for the top level."""
    keys = {tuple(path): key for key, path in tree.folder_keys().items()}
    placements = {}

    def visit(items, path):
        for item in items:
            if isinstance(item, dict):
                for name, children in item.items():
                    visit(children, path + [name])
            else:
                key = keys[tuple(path)] if path else ROOT_KEY
                placements.setdefault(item, []).append((key, lock_for(path, locks)))

    visit(tree.to_list(), [])
    return placements


def _visible_sites(placements):
    sites = {}
    for feed_id, homes in placements.items():
        visible = [(key, lock) for key, lock in homes if lock != "skip"]
        if visible:
            open_keys = [key for key, lock in visible if lock is None]
            sites[feed_id] = {"folders": open_keys, "copy_only": not open_keys}
    return sites


def _numbered(entries, prefix):
    return [{"id": "%s%d" % (prefix, index), **entry} for index, entry in enumerate(entries, 1)]


def _dict_entries(value):
    return [entry for entry in value if isinstance(entry, dict)] if isinstance(value, list) else []


def _reason(value):
    return value.strip()[:REASON_LIMIT] if isinstance(value, str) else ""
