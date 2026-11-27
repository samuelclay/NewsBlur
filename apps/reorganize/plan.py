"""Apply a reviewed reorganization of a user's sites and folders to their stored folder tree.

The stored tree is the JSON list kept in UserSubscriptionFolders.folders (apps/reader/models.py):
ints are feed ids and {"Folder name": [children]} dicts are folders. A proposal names existing
folders by the path they had when it was made ("e0", "e1", ... in FolderTree.folder_keys() order)
and new folders by name and parent ("n0", "n1", ...). Every item in a proposal is approved unless
the user's decisions say otherwise. Anything that no longer fits the tree is skipped and reported,
and everything else still applies.

This module imports only the standard library. Callers save the new tree and mute or unsubscribe
the feeds it reports.
"""

from dataclasses import dataclass, field

ROOT_KEY = "root"
OP_TYPES = ("create", "rename", "nest", "merge", "remove")
DEAD_ACTIONS = ("keep", "mute", "unsubscribe")
SECTIONS = ("ops", "moves", "dead")

# Ids the clients give built-in rivers and sidebar sections (media/js/newsblur/reader/reader.js,
# media/js/newsblur/views/sidebar.js, clients/ios/Classes/FeedChooserViewController.m). Settings
# are saved under a folder's name beside these, so a proposal never names a folder one of them and
# apps/reorganize/state.py never carries one.
RESERVED_FOLDER_NAMES = frozenset(
    [
        "global",
        "infrequent",
        "blurblogs",
        "read",
        "all",
        "everything",
        "starred",
        "searches",
        "river_blurblog",
    ]
)

# Reasons reported in ApplyResult.skipped, one per item that could not be applied.
INVALID = "invalid"  # malformed: unknown key, bad name, duplicate entry, a move onto its own folder
FOLDER_CHANGED = "folder_changed"  # the folder's recorded path no longer resolves
FEED_NOT_IN_FOLDER = "feed_not_in_folder"  # the site is no longer where the item expects it
LOCKED = "locked"  # a keep or skip lock forbids the change
NAME_TAKEN = "name_taken"  # a sibling folder already has that name, ignoring case
WOULD_CYCLE = "would_cycle"  # the folder would end up inside itself
NOT_EMPTY = "not_empty"  # the folder to remove or merge away still holds a site or folder
FOLDER_REJECTED = "folder_rejected"  # the change needs a new folder whose create the user rejected


class PlanError(Exception):
    """The new tree breaks an invariant of this module, so the caller must not save it."""


@dataclass
class ApplyResult:
    """The new stored list and what changed on the way to it.

    `moved` and `copied` hold (feed_id, from_path, to_path) with each folder's final path.
    `path_changes` lists {"old", "new"} for every existing folder whose path ended up different,
    `merged` lists {"old", "into"} and `removed` lists old paths. `skipped` lists {"id", "reason"}.
    """

    folders: list
    moved: list = field(default_factory=list)
    copied: list = field(default_factory=list)
    created: list = field(default_factory=list)
    path_changes: list = field(default_factory=list)
    merged: list = field(default_factory=list)
    removed: list = field(default_factory=list)
    mute_feed_ids: list = field(default_factory=list)
    unsubscribe_feed_ids: list = field(default_factory=list)
    skipped: list = field(default_factory=list)


class _Folder:
    """One folder of a FolderTree. `items` holds feed ids and child folders in stored order."""

    def __init__(self, name):
        self.name = name
        self.parent = None
        self.items = []
        self.dropped_path = None

    def feeds(self):
        return [item for item in self.items if not isinstance(item, _Folder)]

    def subfolders(self):
        return [item for item in self.items if isinstance(item, _Folder)]

    def path(self):
        names = []
        folder = self
        while folder.parent is not None:
            names.append(folder.name)
            folder = folder.parent
        return names[::-1]

    def top(self):
        folder = self
        while folder.parent is not None:
            folder = folder.parent
        return folder

    def is_within(self, other):
        """True when this folder is `other` or sits somewhere inside it."""
        folder = self
        while folder is not None:
            if folder is other:
                return True
            folder = folder.parent
        return False

    def walk(self):
        yield self
        for subfolder in self.subfolders():
            yield from subfolder.walk()

    def subfolder_named(self, name, ignore_case=False, excluding=None):
        for subfolder in self.subfolders():
            if subfolder is excluding:
                continue
            if subfolder.name == name or (ignore_case and subfolder.name.lower() == name.lower()):
                return subfolder
        return None

    def append(self, item):
        if isinstance(item, _Folder):
            item.parent = self
        self.items.append(item)

    def detach(self):
        self.parent.items.remove(self)
        self.parent = None

    def to_list(self):
        return [{item.name: item.to_list()} if isinstance(item, _Folder) else item for item in self.items]


class FolderTree:
    """A user's folders and feeds, loaded from the stored JSON list."""

    def __init__(self):
        self.root = _Folder(None)

    @classmethod
    def from_list(cls, folders):
        tree = cls()
        _load_items(tree.root, folders if isinstance(folders, list) else [])
        return tree

    def to_list(self):
        return self.root.to_list()

    def folder_keys(self):
        """{"e0": path, ...} for every folder, in depth-first document order."""
        return {"e%d" % index: folder.path() for index, folder in enumerate(self._folders())}

    def feed_ids(self):
        return {feed_id for folder in self.root.walk() for feed_id in folder.feeds()}

    def feeds_in(self, path):
        """Feed ids directly in the folder at `path`, in stored order. KeyError if there is none."""
        folder = self._find(path)
        if folder is None:
            raise KeyError(path)
        return folder.feeds()

    def _folders(self):
        return list(self.root.walk())[1:]

    def _find(self, path):
        if not isinstance(path, (list, tuple)):
            return None
        folder = self.root
        for name in path:
            folder = folder.subfolder_named(name) if isinstance(name, str) else None
            if folder is None:
                return None
        return folder


def _load_items(folder, items):
    # Same-named sibling folders merge into the first one, as UserSubscriptionFolders.compact() in
    # apps/reader/models.py also merges them, so every folder path is unique. The subfolders of
    # both are kept and merged by the same rule.
    for item in items:
        if is_feed_id(item):
            if item not in folder.items:
                folder.append(item)
        elif isinstance(item, dict):
            for name, children in item.items():
                subfolder = folder.subfolder_named(name)
                if subfolder is None:
                    subfolder = _Folder(name)
                    folder.append(subfolder)
                _load_items(subfolder, children if isinstance(children, list) else [])


def lock_for(path, locks):
    """The lock on the folder at `path`: "skip", "keep" or None. A lock covers every folder inside it."""
    path = list(path or [])
    if not path:
        return None
    for mode in ("skip", "keep"):
        for locked_path in _lock_paths(locks, mode):
            if path[: len(locked_path)] == locked_path:
                return mode
    return None


def _lock_paths(locks, mode):
    paths = _as_dict(locks).get(mode)
    if not isinstance(paths, (list, tuple)):
        return []
    return [list(path) for path in paths if _valid_path(path)]


def resolve_decisions(proposal, decisions, folders, locks):
    """What the user's decisions mean for each item, before checking it against the tree.

    Moves resolve to "move", "both" (copy), "ask" (nothing until the user accepts a copy) or "stay".
    Ops resolve to True unless rejected. Dead sites resolve to "keep", "mute", "unsubscribe" or None.
    """
    proposal = _as_dict(proposal)
    decisions = _as_dict(decisions)
    op_decisions = _as_dict(decisions.get("ops"))
    move_decisions = _as_dict(decisions.get("moves"))
    dead_decisions = _as_dict(decisions.get("dead"))
    folder_entries = _as_dict(proposal.get("folders"))

    ops = {
        entry["id"]: op_decisions.get(entry["id"]) is not False
        for entry in _entries(proposal, "ops", unique=True)
    }
    rejected_folders = _rejected_new_folders(proposal, ops)

    moves = {}
    for entry in _entries(proposal, "moves", unique=True):
        decision = _as_dict(move_decisions.get(entry["id"]))
        if entry.get("to") in rejected_folders:
            moves[entry["id"]] = "stay"
            continue
        source_lock = lock_for(_recorded_path(folder_entries, entry.get("from")), locks)
        moves[entry["id"]] = _move_outcome(decision.get("arrive"), decision.get("leave"), source_lock)

    locked_feeds = _feeds_in_locked_folders(FolderTree.from_list(folders), locks)
    dead = {}
    for entry in _entries(proposal, "dead", unique=True):
        if entry.get("feed_id") in locked_feeds:
            dead[entry["id"]] = None
        else:
            dead[entry["id"]] = _dead_action(entry, dead_decisions.get(entry["id"]))

    return {"moves": moves, "ops": ops, "dead": dead}


def _move_outcome(arrive, leave, source_lock):
    if arrive is False or source_lock == "skip":
        return "stay"
    if leave is False or source_lock == "keep":
        # A copy only ever happens on an explicit accept.
        return "both" if arrive is True else "ask"
    return "move"


def _dead_action(entry, decision):
    if decision in DEAD_ACTIONS:
        return decision
    return "mute" if entry.get("suggest") == "mute" else None


def _rejected_new_folders(proposal, ops_approved):
    """New folder keys whose create, or the create of a new folder around them, is rejected or missing."""
    create_ids = {}
    for entry in _entries(proposal, "ops", unique=True):
        if entry.get("type") == "create":
            create_ids.setdefault(entry.get("folder"), entry["id"])
    new_entries = {key: entry for key, entry in _as_dict(proposal.get("folders")).items() if _is_new_key(key)}

    rejected = set()
    for key in new_entries:
        current, seen = key, set()
        while _is_new_key(current) and current not in seen:
            seen.add(current)
            op_id = create_ids.get(current)
            if op_id is None or not ops_approved.get(op_id, True):
                rejected.add(key)
                break
            current = _as_dict(new_entries.get(current)).get("parent")
    return rejected


def _feeds_in_locked_folders(tree, locks):
    return {
        feed_id
        for folder in tree._folders()
        if lock_for(folder.path(), locks) is not None
        for feed_id in folder.feeds()
    }


def apply_plan(folders, proposal, decisions, locks):
    """Apply the approved parts of `proposal` to the stored `folders` list and return an ApplyResult."""
    applier = _Applier(folders, proposal, decisions, locks)
    applier.run()
    return applier.result()


def restore_folders(snapshot_folders, current_folders, subscribed_feed_ids):
    """The stored list an undo saves: `snapshot_folders`, the tree before a reorganization, kept
    up to date with the sites the user has subscribed to or left since.

    Sites missing from `subscribed_feed_ids` are dropped. A site in `current_folders` that the
    snapshot lacks goes to each folder it is in now whose path the snapshot also has, after what
    the snapshot keeps there, and to the top level when it is in none of them.
    """
    subscribed = set(subscribed_feed_ids)
    tree = FolderTree.from_list(snapshot_folders)
    snapshot_feeds = tree.feed_ids()
    for folder in tree.root.walk():
        folder.items = [item for item in folder.items if isinstance(item, _Folder) or item in subscribed]

    unplaced = []
    for folder in FolderTree.from_list(current_folders).root.walk():
        destination = tree._find(folder.path())
        for feed_id in folder.feeds():
            if feed_id in snapshot_feeds or feed_id not in subscribed:
                continue
            if destination is None:
                unplaced.append(feed_id)
            elif feed_id not in destination.items:
                destination.append(feed_id)

    placed = tree.feed_ids()
    for feed_id in unplaced:
        if feed_id not in placed:
            tree.root.append(feed_id)
            placed.add(feed_id)
    return tree.to_list()


def sanitize_proposal(proposal, folders, locks):
    """A copy of `proposal` without anything that cannot apply to `folders` under `locks`.

    The checks are apply_plan's own, run with every item approved, every move accepted as at least a
    copy and every dead site muted. Whatever apply_plan skips in that run, and
    any new folder that would end up empty, is removed until a run skips nothing.
    """
    tree = FolderTree.from_list(folders)
    clean = _normalized_proposal(proposal)
    _point_matching_creates_at_existing_folders(clean, tree)

    while True:
        decisions = {
            "moves": {entry["id"]: {"arrive": True} for entry in clean["moves"]},
            # Muting leaves the tree alone, so no folder op passes only because an unsubscribe
            # the reader never chose would have emptied its folder.
            "dead": {entry["id"]: "mute" for entry in clean["dead"]},
        }
        applier = _Applier(folders, clean, decisions, locks)
        applier.run()

        empty_keys = {key for key, folder in applier.created_folders if not applier.attached(folder)}
        if empty_keys:
            clean["ops"] = [
                entry
                for entry in clean["ops"]
                if not (entry["type"] == "create" and entry.get("folder") in empty_keys)
            ]
            continue

        dropped = {(section, entry_id) for section, entry_id, _ in applier.skipped} | applier.no_ops
        if not dropped:
            break
        for section in SECTIONS:
            clean[section] = [entry for entry in clean[section] if (section, entry["id"]) not in dropped]

    clean["folders"] = _referenced_folders(clean)
    return clean


def _normalized_proposal(proposal):
    """Well-formed entries only: string ids unique within a section, int feed ids, clean folder names."""
    proposal = _as_dict(proposal)

    folders = {}
    for key, entry in _as_dict(proposal.get("folders")).items():
        entry = _as_dict(entry)
        if _is_existing_key(key) and _valid_path(entry.get("path")):
            folders[key] = dict(entry, path=list(entry["path"]))
        elif _is_new_key(key):
            name = clean_folder_name(entry.get("name"))
            if name is not None and isinstance(entry.get("parent"), str):
                folders[key] = dict(entry, name=name)

    ops = []
    for entry in _entries(proposal, "ops", unique=True):
        if entry.get("type") not in OP_TYPES:
            continue
        entry = dict(entry)
        if entry["type"] == "rename":
            entry["name"] = clean_folder_name(entry.get("name"))
            if entry["name"] is None:
                continue
        ops.append(entry)

    moves = [
        dict(entry) for entry in _entries(proposal, "moves", unique=True) if is_feed_id(entry.get("feed_id"))
    ]

    dead = []
    for entry in _entries(proposal, "dead", unique=True):
        if is_feed_id(entry.get("feed_id")):
            suggest = "unsubscribe" if entry.get("suggest") == "unsubscribe" else "mute"
            dead.append(dict(entry, suggest=suggest))

    return {"folders": folders, "ops": ops, "moves": moves, "dead": dead}


def _point_matching_creates_at_existing_folders(proposal, tree):
    """Replace each new folder that matches a sibling by name, ignoring case, with that sibling's key."""
    folders = proposal["folders"]
    bound = {key: tree._find(entry["path"]) for key, entry in folders.items() if _is_existing_key(key)}
    key_for_folder = {}
    for key, folder in bound.items():
        if folder is not None:
            key_for_folder.setdefault(folder, key)
    canonical_keys = {tuple(path): key for key, path in tree.folder_keys().items()}

    def key_for(folder):
        if folder not in key_for_folder:
            key = canonical_keys[tuple(folder.path())]
            index = len(canonical_keys)
            while key in folders:
                key = "e%d" % index
                index += 1
            folders[key] = {"path": folder.path()}
            bound[key] = folder
            key_for_folder[folder] = key
        return key_for_folder[folder]

    created_keys = []
    for entry in proposal["ops"]:
        key = entry.get("folder")
        if entry["type"] == "create" and key in folders and _is_new_key(key) and key not in created_keys:
            created_keys.append(key)

    rewrites = {}
    claimed = {}
    for key in _parents_first(created_keys, folders):
        entry = folders[key]
        entry["parent"] = rewrites.get(entry["parent"], entry["parent"])
        parent = tree.root if entry["parent"] == ROOT_KEY else bound.get(entry["parent"])
        sibling = parent.subfolder_named(entry["name"], ignore_case=True) if parent is not None else None
        claim = (entry["parent"], entry["name"].lower())
        if sibling is not None:
            rewrites[key] = key_for(sibling)
        elif claim in claimed:
            rewrites[key] = claimed[claim]
        else:
            claimed[claim] = key
    if not rewrites:
        return

    proposal["ops"] = [
        entry
        for entry in proposal["ops"]
        if not (entry["type"] == "create" and entry.get("folder") in rewrites)
    ]
    for entry in proposal["ops"]:
        for field_name in ("folder", "parent", "into"):
            if entry.get(field_name) in rewrites:
                entry[field_name] = rewrites[entry[field_name]]
    for entry in proposal["moves"]:
        for field_name in ("from", "to"):
            if entry.get(field_name) in rewrites:
                entry[field_name] = rewrites[entry[field_name]]
    for key in rewrites:
        del folders[key]
    for entry in folders.values():
        if entry.get("parent") in rewrites:
            entry["parent"] = rewrites[entry["parent"]]


def _parents_first(keys, folders):
    """New folder keys ordered so each comes after its new parent. Keys in a parent cycle are left out."""
    ordered = []
    remaining = list(keys)
    while remaining:
        ready = [key for key in remaining if folders[key]["parent"] not in remaining]
        if not ready:
            break
        ordered.extend(ready)
        remaining = [key for key in remaining if key not in ready]
    return ordered


def _referenced_folders(proposal):
    referenced = set()
    for entry in proposal["ops"]:
        referenced.update(entry.get(field_name) for field_name in ("folder", "parent", "into"))
    for entry in proposal["moves"]:
        referenced.update((entry.get("from"), entry.get("to")))

    pending = [key for key in referenced if _is_new_key(key)]
    while pending:
        parent = _as_dict(proposal["folders"].get(pending.pop())).get("parent")
        if parent not in referenced:
            referenced.add(parent)
            if _is_new_key(parent):
                pending.append(parent)

    return {key: entry for key, entry in proposal["folders"].items() if key in referenced}


class _Applier:
    """One application of a proposal to a tree, in the order run() lists."""

    def __init__(self, folders, proposal, decisions, locks):
        self.tree = FolderTree.from_list(folders)
        self.proposal = _as_dict(proposal)
        self.folder_entries = _as_dict(self.proposal.get("folders"))
        self.resolved = resolve_decisions(proposal, decisions, folders, locks)
        decisions = _as_dict(decisions)
        self.move_decisions = _as_dict(decisions.get("moves"))
        self.dead_decisions = _as_dict(decisions.get("dead"))

        self.feeds_before = self.tree.feed_ids()
        self.original_paths = {folder: folder.path() for folder in self.tree._folders()}
        self.locked = {}  # locked folder -> (lock mode, original path, original contents)
        for folder, path in self.original_paths.items():
            mode = lock_for(path, locks)
            if mode is not None:
                self.locked[folder] = (mode, path, folder.to_list())

        self.existing = {}  # existing folder key -> (folder, reason it could not be bound)
        self.new_folders = {}  # new folder key -> (folder, reason it could not be created)
        self.create_ops = {}  # new folder key -> its create op
        self.created_folders = []  # (new folder key, folder) for folders this plan added to the tree
        self.entries = {}
        self.skipped = []  # (section, id, reason)
        self.no_ops = set()  # (section, id) of approved ops that would change nothing
        self.moved, self.copied = [], []  # (feed id, source folder, destination folder)
        self.merged, self.removed = [], []
        self.mute, self.unsubscribe = [], []

    def run(self):
        for section in SECTIONS:
            self.entries[section] = self._validated(section)
        self._bind_existing()
        self._apply_creates()
        self._apply_moves()
        self._apply_dead_sites()
        self._apply_renames()
        self._apply_nests()
        self._apply_merges()
        # Pruned before removes too, so an empty new folder does not keep its parent from being removed.
        self._prune_empty_new_folders()
        self._apply_removes()
        self._prune_empty_new_folders()
        self._check_invariants()

    def result(self):
        unsubscribed = set(self.unsubscribe)
        return ApplyResult(
            folders=self.tree.to_list(),
            moved=[
                (feed_id, self._final_path(source), self._final_path(destination))
                for feed_id, source, destination in self.moved
                if feed_id not in unsubscribed
            ],
            copied=[
                (feed_id, self._final_path(source), self._final_path(destination))
                for feed_id, source, destination in self.copied
                if feed_id not in unsubscribed
            ],
            created=[folder.path() for _, folder in self.created_folders if self.attached(folder)],
            path_changes=[
                {"old": old_path, "new": folder.path()}
                for folder, old_path in self.original_paths.items()
                if self.attached(folder) and folder.path() != old_path
            ],
            merged=[{"old": old_path, "into": self._final_path(into)} for old_path, into in self.merged],
            removed=list(self.removed),
            mute_feed_ids=list(self.mute),
            unsubscribe_feed_ids=list(self.unsubscribe),
            skipped=[{"id": entry_id, "reason": reason} for _, entry_id, reason in self.skipped],
        )

    def attached(self, folder):
        return folder.top() is self.tree.root

    # Entries and keys

    def _validated(self, section):
        entries, seen = [], set()
        raw = self.proposal.get(section)
        for entry in raw if isinstance(raw, list) else []:
            entry_id = entry.get("id") if isinstance(entry, dict) else None
            if not isinstance(entry_id, str):
                self.skipped.append((section, None, INVALID))
            elif entry_id in seen or (section == "ops" and entry.get("type") not in OP_TYPES):
                self.skipped.append((section, entry_id, INVALID))
            else:
                seen.add(entry_id)
                entries.append(entry)
        return entries

    def _ops(self, op_type, approved_only=True):
        return [
            entry
            for entry in self.entries["ops"]
            if entry["type"] == op_type and (not approved_only or self.resolved["ops"].get(entry["id"], True))
        ]

    def _skip(self, section, entry, reason):
        self.skipped.append((section, entry["id"], reason))

    def _bind_existing(self):
        for key, entry in self.folder_entries.items():
            if not _is_existing_key(key):
                continue
            path = _as_dict(entry).get("path")
            if not _valid_path(path):
                self.existing[key] = (None, INVALID)
                continue
            folder = self.tree._find(path)
            self.existing[key] = (folder, None) if folder is not None else (None, FOLDER_CHANGED)

    def _node(self, key):
        """(folder, None) for a key that names a folder in the tree, else (None, reason)."""
        if key == ROOT_KEY:
            return self.tree.root, None
        if _is_existing_key(key) and key in self.existing:
            folder, reason = self.existing[key]
        elif _is_new_key(key) and key in self.new_folders:
            folder, reason = self.new_folders[key]
        else:
            return None, INVALID
        if folder is not None and not self.attached(folder):
            return None, FOLDER_CHANGED
        return folder, reason

    def _existing_node(self, key):
        if not _is_existing_key(key):
            return None, INVALID
        return self._node(key)

    def _is_locked(self, folder):
        return folder in self.locked

    def _lock_mode(self, folder):
        return self.locked[folder][0] if folder in self.locked else None

    def _holds_lock(self, folder):
        """Locked itself, or changing it would change the path of a locked folder inside it."""
        return any(locked.is_within(folder) for locked in self.locked)

    def _final_path(self, folder):
        return folder.path() if self.attached(folder) else folder.dropped_path

    def _drop(self, folder):
        folder.dropped_path = folder.path()
        folder.detach()

    # Steps, in run() order

    def _apply_creates(self):
        for entry in self._ops("create", approved_only=False):
            key = entry.get("folder")
            if (
                not _is_new_key(key)
                or key in self.create_ops
                or not isinstance(self.folder_entries.get(key), dict)
            ):
                self._skip("ops", entry, INVALID)
            else:
                self.create_ops[key] = entry
        for key in self.create_ops:
            self._create(key, set())

    def _create(self, key, visiting):
        if key in self.new_folders:
            return self.new_folders[key]
        entry = self.create_ops.get(key)
        if entry is None:
            outcome = (None, INVALID)
        elif not self.resolved["ops"].get(entry["id"], True):
            outcome = (None, FOLDER_REJECTED)
        else:
            outcome = self._place_new_folder(key, visiting | {key})
            if outcome[0] is None:
                self._skip("ops", entry, outcome[1])
        self.new_folders[key] = outcome
        return outcome

    def _place_new_folder(self, key, visiting):
        entry = self.folder_entries[key]
        name = clean_folder_name(entry.get("name"))
        if name is None:
            return None, INVALID
        parent_key = entry.get("parent")
        if _is_new_key(parent_key) and parent_key in visiting:
            return None, WOULD_CYCLE
        if _is_new_key(parent_key):
            parent, reason = self._create(parent_key, visiting)
        else:
            parent, reason = self._node(parent_key)
        if parent is None:
            return None, reason
        if self._is_locked(parent):
            return None, LOCKED
        sibling = parent.subfolder_named(name, ignore_case=True)
        if sibling is not None:
            # The folder exists already, so arrivals go there, as add_object_to_folder in
            # utils/feed_functions.py does for a folder name that is already taken.
            return sibling, None
        folder = _Folder(name)
        parent.append(folder)
        self.created_folders.append((key, folder))
        return folder, None

    def _apply_moves(self):
        planned, placements = [], set()
        for entry in self.entries["moves"]:
            feed_id, source_key = entry.get("feed_id"), entry.get("from")
            source, source_reason = self._node(source_key)
            destination, destination_reason = self._node(entry.get("to"))
            if (
                not is_feed_id(feed_id)
                or _is_new_key(source_key)
                or INVALID in (source_reason, destination_reason)
            ):
                self._skip("moves", entry, INVALID)
                continue

            outcome = self.resolved["moves"].get(entry["id"])
            if outcome not in ("move", "both"):
                decision = _as_dict(self.move_decisions.get(entry["id"]))
                wanted = _move_outcome(decision.get("arrive"), decision.get("leave"), None)
                dropped_by_skip_lock = source is not None and self._lock_mode(source) == "skip"
                if (
                    dropped_by_skip_lock
                    and wanted in ("move", "both")
                    and destination_reason != FOLDER_REJECTED
                ):
                    self._skip("moves", entry, LOCKED)
                continue

            if source is None or destination is None:
                self._skip("moves", entry, source_reason or destination_reason)
            elif source is destination or (feed_id, source) in placements:
                self._skip("moves", entry, INVALID)
            elif feed_id not in source.items:
                self._skip("moves", entry, FEED_NOT_IN_FOLDER)
            elif self._is_locked(destination) or (outcome == "move" and self._is_locked(source)):
                self._skip("moves", entry, LOCKED)
            else:
                placements.add((feed_id, source))
                planned.append((feed_id, source, destination, outcome))

        # Every placement leaves before any arrives, so the result does not depend on move order.
        for feed_id, source, destination, outcome in planned:
            if outcome == "move":
                source.items.remove(feed_id)
        for feed_id, source, destination, outcome in planned:
            already_there = feed_id in destination.items
            if not already_there:
                destination.append(feed_id)
            if outcome == "move":
                self.moved.append((feed_id, source, destination))
            elif not already_there:
                self.copied.append((feed_id, source, destination))

    def _apply_dead_sites(self):
        seen_feeds = set()
        for entry in self.entries["dead"]:
            feed_id = entry.get("feed_id")
            if not is_feed_id(feed_id) or feed_id in seen_feeds:
                self._skip("dead", entry, INVALID)
                continue
            seen_feeds.add(feed_id)
            action = self.resolved["dead"].get(entry["id"])
            wanted = _dead_action(entry, self.dead_decisions.get(entry["id"]))
            if wanted in ("mute", "unsubscribe") and feed_id not in self.feeds_before:
                self._skip("dead", entry, FEED_NOT_IN_FOLDER)
            elif wanted in ("mute", "unsubscribe") and action is None:
                self._skip("dead", entry, LOCKED)
            elif action == "mute":
                self.mute.append(feed_id)
            elif action == "unsubscribe":
                for folder in self.tree.root.walk():
                    if feed_id in folder.items:
                        folder.items.remove(feed_id)
                self.unsubscribe.append(feed_id)

    def _apply_renames(self):
        for entry in self._ops("rename"):
            folder, reason = self._existing_node(entry.get("folder"))
            name = clean_folder_name(entry.get("name"))
            if folder is None:
                self._skip("ops", entry, reason)
            elif name is None:
                self._skip("ops", entry, INVALID)
            elif self._holds_lock(folder):
                self._skip("ops", entry, LOCKED)
            elif name == folder.name:
                self.no_ops.add(("ops", entry["id"]))
            elif folder.parent.subfolder_named(name, ignore_case=True, excluding=folder) is not None:
                self._skip("ops", entry, NAME_TAKEN)
            else:
                folder.name = name

    def _apply_nests(self):
        for entry in self._ops("nest"):
            folder, reason = self._existing_node(entry.get("folder"))
            parent, parent_reason = self._node(entry.get("parent"))
            if folder is None or parent is None:
                self._skip("ops", entry, reason or parent_reason)
            elif self._holds_lock(folder) or self._is_locked(parent):
                self._skip("ops", entry, LOCKED)
            elif parent.is_within(folder):
                self._skip("ops", entry, WOULD_CYCLE)
            elif parent is folder.parent:
                self.no_ops.add(("ops", entry["id"]))
            elif parent.subfolder_named(folder.name, ignore_case=True) is not None:
                self._skip("ops", entry, NAME_TAKEN)
            else:
                folder.detach()
                parent.append(folder)

    def _apply_merges(self):
        # The sites in a merged folder leave through their own entries in "moves", which ran already.
        # A merge is all or nothing: a folder that keeps a site, or whose subfolders cannot all move,
        # stays exactly as it is.
        for entry in self._ops("merge"):
            folder, reason = self._existing_node(entry.get("folder"))
            into, into_reason = self._node(entry.get("into"))
            if folder is None or into is None:
                self._skip("ops", entry, reason or into_reason)
            elif into is folder:
                self._skip("ops", entry, INVALID)
            elif self._holds_lock(folder) or self._is_locked(into):
                self._skip("ops", entry, LOCKED)
            elif into.is_within(folder):
                self._skip("ops", entry, WOULD_CYCLE)
            elif folder.feeds():
                self._skip("ops", entry, NOT_EMPTY)
            elif self._subfolders_clash(folder, into):
                self._skip("ops", entry, NAME_TAKEN)
            else:
                for subfolder in folder.subfolders():
                    subfolder.detach()
                    into.append(subfolder)
                self.merged.append((self.original_paths[folder], into))
                self._drop(folder)

    def _subfolders_clash(self, folder, into):
        """True if moving every subfolder of `folder` into `into` would repeat a name, ignoring case."""
        names = [subfolder.name.lower() for subfolder in folder.subfolders()]
        if len(names) != len(set(names)):
            return True
        return any(
            into.subfolder_named(name, ignore_case=True, excluding=folder) is not None for name in names
        )

    def _apply_removes(self):
        candidates = []
        for entry in self._ops("remove"):
            folder, reason = self._existing_node(entry.get("folder"))
            if folder is None:
                self._skip("ops", entry, reason)
            else:
                candidates.append((entry, folder))
        # Deepest first, so a folder whose only contents are folders being removed empties in time.
        candidates.sort(key=lambda candidate: -len(candidate[1].path()))
        for entry, folder in candidates:
            if not self.attached(folder):
                self._skip("ops", entry, FOLDER_CHANGED)
            elif self._holds_lock(folder):
                self._skip("ops", entry, LOCKED)
            elif folder.items:
                self._skip("ops", entry, NOT_EMPTY)
            else:
                self.removed.append(self.original_paths[folder])
                self._drop(folder)

    def _prune_empty_new_folders(self):
        # Deepest first, so a new folder holding only an empty new folder goes too.
        for _, folder in sorted(self.created_folders, key=lambda created: -len(created[1].path())):
            if self.attached(folder) and not folder.items:
                self._drop(folder)

    def _check_invariants(self):
        expected_feeds = self.feeds_before - set(self.unsubscribe)
        if self.tree.feed_ids() != expected_feeds:
            raise PlanError(
                "Feed set changed: lost %s, gained %s"
                % (
                    sorted(expected_feeds - self.tree.feed_ids()),
                    sorted(self.tree.feed_ids() - expected_feeds),
                )
            )
        for folder, (_, path, contents) in self.locked.items():
            if not self.attached(folder) or folder.path() != path or folder.to_list() != contents:
                raise PlanError("Locked folder %s changed" % (path,))


def _entries(proposal, section, unique=False):
    """Dict entries of a proposal section that carry a string id, optionally first occurrence only."""
    raw = _as_dict(proposal).get(section)
    entries, seen = [], set()
    for entry in raw if isinstance(raw, list) else []:
        if not isinstance(entry, dict) or not isinstance(entry.get("id"), str):
            continue
        if unique and entry["id"] in seen:
            continue
        seen.add(entry["id"])
        entries.append(entry)
    return entries


def _recorded_path(folder_entries, key):
    if _is_existing_key(key):
        path = _as_dict(folder_entries.get(key)).get("path")
        if _valid_path(path):
            return list(path)
    return []


def clean_folder_name(name):
    """The name with surrounding spaces removed, or None if it breaks the folder name limits.

    apps/reader/views.py add_folder and rename_folder refuse an empty name, and add_folder strips
    "river:" out of names, so a name holding it could not be made through them either. A proposed
    name also never holds " - ", which joins folder names into the paths that folder classifiers
    in apps/analyzer/models.py are stored under, is never "Top Level", the name the folder
    pickers give the top of the tree, and is never one of RESERVED_FOLDER_NAMES.
    """
    if not isinstance(name, str):
        return None
    name = name.strip()
    if not name or "river:" in name or " - " in name or name.lower() == "top level":
        return None
    if name in RESERVED_FOLDER_NAMES:
        return None
    return name


def is_feed_id(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _is_existing_key(key):
    return isinstance(key, str) and key[:1] == "e" and key[1:].isdigit()


def _is_new_key(key):
    return isinstance(key, str) and key[:1] == "n" and key[1:].isdigit()


def _valid_path(path):
    return isinstance(path, (list, tuple)) and len(path) > 0 and all(isinstance(name, str) for name in path)


def _as_dict(value):
    return value if isinstance(value, dict) else {}
