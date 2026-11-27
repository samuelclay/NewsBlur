"""Carry what a user has attached to folders through a reorganization, and put it back on undo.

Folder icons, auto mark read settings, view settings, collapsed folders, saved searches, dashboard
rivers, the daily briefing's story source, folder classifiers and classifier notifications each
name a folder by text: the folder's own name, as the web saves most of them, or its full path
joined with " - ", as folder classifiers and mobile requests do. When apps/reorganize/plan.py
renames or re-parents folders, carry_folder_state() rewrites those names to follow and returns
`carried`, a JSON list with one entry per change. revert_folder_state() puts back exactly those.

A full path names one folder, so an entry keyed by it always follows. A folder's own name can be
shared, so an entry keyed by it follows only when exactly one folder had the old name before,
exactly one has the new name after, and neither name is one the web reserves for a built-in river
or sidebar section. Nothing is deleted or overwritten: a move that would land on
an entry that stays is not made. Every move in a batch is worked out against the state before any
of them, so a chain (Tech to Tech News while Hardware becomes Tech) or a swap of two names leaves
each entry with its own folder.
"""

import json
from collections import Counter, defaultdict
from dataclasses import dataclass, field

from mongoengine.errors import NotUniqueError
from pymongo import ReadPreference

from apps.analyzer.models import (
    MClassifierAuthor,
    MClassifierPrompt,
    MClassifierTag,
    MClassifierText,
    MClassifierTitle,
    MClassifierUrl,
    classifier_write_lock,
)
from apps.briefing.models import MBriefingPreferences
from apps.notifications.models import MUserClassifierNotification
from apps.profile.models import MDashboardRiver, Profile
from apps.reader.models import MFolderAutoMarkRead, MFolderIcon
from apps.reorganize.plan import RESERVED_FOLDER_NAMES, FolderTree
from apps.rss_feeds.models import MSavedSearch

# How a store names a folder.
BY_NAME = "name"  # the folder's own name
BY_PATH = "path"  # the full path joined with " - "
BY_EITHER = "either"  # the web saves the folder's own name and mobile requests the full path

PATH_SEPARATOR = " - "
VIEW_SETTINGS = "view_settings"
COLLAPSED_FOLDERS = "collapsed_folders"
BRIEFING_SOURCES = "briefing_story_sources"


@dataclass
class _DocumentStore:
    """A Mongo collection whose documents name a folder in `key_field`.

    Two documents are the same entry when their `identity` fields and key match, so a move only
    stops for a document that would duplicate one already at the new key. With no identity
    fields, any document at the new key stops it.
    """

    name: str
    model: type
    key_field: str
    keyed_by: str
    prefix: str = ""
    filters: dict = field(default_factory=dict)
    identity: tuple = ()
    trained: bool = False  # classifier rules, written under classifier_write_lock in apps/analyzer/models.py


def _classifier_store(model, value_field):
    return _DocumentStore(
        "classifier_" + value_field,
        model,
        "folder_name",
        BY_PATH,
        filters={"scope": "folder"},
        identity=("feed_id", "social_user_id", value_field, "is_regex"),
        trained=True,
    )


DOCUMENT_STORES = (
    _DocumentStore("folder_icon", MFolderIcon, "folder_title", BY_EITHER),
    _DocumentStore("folder_auto_mark_read", MFolderAutoMarkRead, "folder_title", BY_EITHER),
    _DocumentStore("saved_search", MSavedSearch, "feed_id", BY_NAME, prefix="river:", identity=("query",)),
    _DocumentStore("dashboard_river", MDashboardRiver, "river_id", BY_NAME, prefix="river:"),
    _classifier_store(MClassifierTitle, "title"),
    _classifier_store(MClassifierText, "text"),
    _classifier_store(MClassifierUrl, "url"),
    _classifier_store(MClassifierAuthor, "author"),
    _classifier_store(MClassifierTag, "tag"),
    _DocumentStore(
        "classifier_prompt",
        MClassifierPrompt,
        "folder_id",
        BY_PATH,
        identity=("feed_id", "prompt", "include_images"),
        trained=True,
    ),
    _DocumentStore(
        "classifier_notification",
        MUserClassifierNotification,
        "folder_name",
        BY_PATH,
        filters={"scope": "folder"},
        identity=("classifier_type", "classifier_value", "is_regex", "feed_id"),
    ),
)


@dataclass
class _Entry:
    """One stored entry that names a folder, and the key it is moving to, if any."""

    namespace: tuple
    key: str
    source: str
    target: str = None
    document: object = None


def carry_folder_state(user, path_changes, folders_before, folders_after):
    """Move this user's folder-keyed entries to follow `path_changes` and return what moved.

    `path_changes` is ApplyResult.path_changes from apps/reorganize/plan.py, and the two folder
    lists are the stored tree before and after the reorganization. Each item of the returned list
    names its store and the entry's old and new key, plus the document id for Mongo stores.
    """
    renames = _renames(path_changes, folders_before, folders_after)
    carried = []
    for store in DOCUMENT_STORES:
        store_renames = _prefixed(renames[store.keyed_by], store.prefix)
        if store_renames:
            carried.extend(_carry_documents(store, user.pk, store_renames))
    carried.extend(_carry_profile(user.pk, renames[BY_NAME]))
    carried.extend(_carry_briefing(user.pk, _prefixed(renames[BY_NAME], "folder:")))
    return carried


def revert_folder_state(user, carried):
    """Put back every entry that `carried` lists, skipping any the user has changed since.

    An entry is skipped when it is no longer under its new key, or when its old key holds another
    entry again. Stores are reverted in the reverse of the order they were carried.
    """
    records = [record for record in carried or [] if _is_record(record)]
    if any(record["store"] == BRIEFING_SOURCES for record in records):
        _revert_briefing(user.pk, [record for record in records if record["store"] == BRIEFING_SOURCES])
    profile_records = [record for record in records if record["store"] in (VIEW_SETTINGS, COLLAPSED_FOLDERS)]
    if profile_records:
        _revert_profile(user.pk, profile_records)
    for store in reversed(DOCUMENT_STORES):
        store_records = [record for record in records if record["store"] == store.name and "id" in record]
        if store_records:
            _revert_documents(store, user.pk, store_records)


def _renames(path_changes, folders_before, folders_after):
    """{BY_NAME: {old: new}, BY_PATH: {...}, BY_EITHER: {...}}, the keys each kind of store moves."""
    names_before = _folder_name_counts(folders_before)
    names_after = _folder_name_counts(folders_after)
    by_path, by_name, nested_paths = {}, {}, {}
    for change in path_changes or []:
        old, new = (change.get("old"), change.get("new")) if isinstance(change, dict) else (None, None)
        if not _is_path(old) or not _is_path(new) or list(old) == list(new):
            continue
        by_path[PATH_SEPARATOR.join(old)] = PATH_SEPARATOR.join(new)
        if len(old) > 1:
            nested_paths[PATH_SEPARATOR.join(old)] = PATH_SEPARATOR.join(new)
        # The web keys a built-in river or sidebar section by a reserved name too, so a folder named
        # one shares those settings with that section and they stay.
        if (
            old[-1] != new[-1]
            and old[-1] not in RESERVED_FOLDER_NAMES
            and new[-1] not in RESERVED_FOLDER_NAMES
            and names_before[old[-1]] == 1
            and names_after[new[-1]] == 1
        ):
            by_name[old[-1]] = new[-1]
    # A top-level folder's full path is also its own name, and in a store that holds both kinds of
    # key it could be either, so it moves by the rule for names.
    return {BY_NAME: by_name, BY_PATH: by_path, BY_EITHER: _merged(nested_paths, by_name)}


def _folder_name_counts(folders):
    return Counter(path[-1] for path in FolderTree.from_list(folders).folder_keys().values())


def _merged(*rename_maps):
    """One map from all of `rename_maps`, without any old key they send to different new keys."""
    merged, clashing = {}, set()
    for renames in rename_maps:
        for old, new in renames.items():
            if merged.get(old, new) != new:
                clashing.add(old)
            merged[old] = new
    return {old: new for old, new in merged.items() if old not in clashing}


def _prefixed(renames, prefix):
    return {prefix + old: prefix + new for old, new in renames.items()}


def _settle(entries):
    """Drop every move that lands on an entry that stays, or on a key entries from another key also
    move to, until none does. Returns the entries still moving."""
    while True:
        staying = {(entry.namespace, entry.key) for entry in entries if entry.target is None}
        arriving_from = defaultdict(set)
        for entry in entries:
            if entry.target is not None:
                arriving_from[(entry.namespace, entry.target)].add(entry.key)
        blocked = [
            entry
            for entry in entries
            if entry.target is not None
            and (
                (entry.namespace, entry.target) in staying
                or len(arriving_from[(entry.namespace, entry.target)]) > 1
            )
        ]
        if not blocked:
            return [entry for entry in entries if entry.target is not None]
        for entry in blocked:
            entry.target = None


def _write_moves(entries, write):
    """Write each settled move once no other moving entry still holds its key, and return the moved.

    `write(entry, key)` stores the entry under `key` and says whether it did. A cycle of moves,
    such as a swap, parks one entry on a key of its own first, since folder icons, auto mark read
    settings, saved searches and notifications each keep their key unique.
    """
    moved = []
    pending = _settle(entries)
    while pending:
        held = {(entry.namespace, entry.key) for entry in pending}
        ready = [entry for entry in pending if (entry.namespace, entry.target) not in held]
        if not ready:
            # Once every pending entry is parked, every target is free, so one is always unparked here.
            parked = next(entry for entry in pending if entry.key == entry.source)
            parking_key = "\0%s" % parked.document.pk
            if write(parked, parking_key):
                parked.key = parking_key
            else:
                parked.target = None
        for entry in ready:
            if write(entry, entry.target):
                entry.key = entry.target
                moved.append(entry)
            elif entry.key != entry.source and write(entry, entry.source):
                entry.key = entry.source
            entry.target = None
        pending = _settle(entries)
    return moved


def _document_writer(store, user_id):
    def write(entry, key):
        # Only a document still under the key it was read with moves, so a change the user made in
        # the meantime is never overwritten.
        try:
            updated = store.model.objects(
                id=entry.document.pk, user_id=user_id, **{store.key_field: entry.key}
            ).update_one(**{"set__" + store.key_field: key})
        except NotUniqueError:
            return False
        return updated == 1

    return write


def _load_entries(store, user_id, keys):
    documents = store.model.objects(
        user_id=user_id, **store.filters, **{store.key_field + "__in": sorted(keys)}
    ).read_preference(ReadPreference.PRIMARY)
    entries = []
    for document in documents:
        key = getattr(document, store.key_field)
        # A field left at its default reads back as None or as the default, and both mean the same
        # rule, as matching_classifiers in apps/analyzer/models.py also treats them.
        namespace = tuple(getattr(document, name, None) or None for name in store.identity)
        entries.append(_Entry(namespace=namespace, key=key, source=key, document=document))
    return entries


def _move_documents(store, user_id, entries):
    if store.trained:
        with classifier_write_lock(user_id):
            return _write_moves(entries, _document_writer(store, user_id))
    return _write_moves(entries, _document_writer(store, user_id))


def _carry_documents(store, user_id, renames):
    entries = _load_entries(store, user_id, set(renames) | set(renames.values()))
    for entry in entries:
        entry.target = renames.get(entry.key)
    moved = _move_documents(store, user_id, entries)
    return [
        {"store": store.name, "id": str(entry.document.pk), "old": entry.source, "new": entry.key}
        for entry in moved
    ]


def _revert_documents(store, user_id, records):
    old_keys = {str(record["id"]): record["old"] for record in records}
    new_keys = {str(record["id"]): record["new"] for record in records}
    entries = _load_entries(store, user_id, set(old_keys.values()) | set(new_keys.values()))
    for entry in entries:
        document_id = str(entry.document.pk)
        if new_keys.get(document_id) == entry.key:
            entry.target = old_keys[document_id]
    _move_documents(store, user_id, entries)


def _carry_profile(user_id, renames):
    """Carry view settings ("river:<name>" keys) and collapsed folders (a list of names)."""
    profile = Profile.objects.filter(user_id=user_id).first() if renames else None
    if profile is None:
        return []
    view_moves = _settled_renames(_decoded(profile.view_settings, dict), _prefixed(renames, "river:"))
    collapsed_moves = _settled_renames(_decoded(profile.collapsed_folders, list), renames)
    _save_profile(profile, view_moves, collapsed_moves)
    return [
        *({"store": VIEW_SETTINGS, "old": old, "new": new} for old, new in view_moves.items()),
        *({"store": COLLAPSED_FOLDERS, "old": old, "new": new} for old, new in collapsed_moves.items()),
    ]


def _revert_profile(user_id, records):
    profile = Profile.objects.filter(user_id=user_id).first()
    if profile is None:
        return
    view_moves = _settled_renames(
        _decoded(profile.view_settings, dict),
        {record["new"]: record["old"] for record in records if record["store"] == VIEW_SETTINGS},
    )
    collapsed_moves = _settled_renames(
        _decoded(profile.collapsed_folders, list),
        {record["new"]: record["old"] for record in records if record["store"] == COLLAPSED_FOLDERS},
    )
    _save_profile(profile, view_moves, collapsed_moves)


def _settled_renames(keys, renames):
    """{old: new} for each of `keys` that can move by `renames` without landing on another key."""
    involved = set(renames) | set(renames.values())
    entries = [
        _Entry(namespace=(), key=key, source=key, target=renames.get(key))
        for key in dict.fromkeys(keys)
        if isinstance(key, str) and key in involved
    ]
    return {entry.key: entry.target for entry in _settle(entries)}


def _save_profile(profile, view_moves, collapsed_moves):
    changed = []
    if view_moves:
        view_settings = _decoded(profile.view_settings, dict)
        profile.view_settings = json.dumps(
            {view_moves.get(key, key): value for key, value in view_settings.items()}
        )
        changed.append(VIEW_SETTINGS)
    if collapsed_moves:
        collapsed = _decoded(profile.collapsed_folders, list)
        profile.collapsed_folders = json.dumps([collapsed_moves.get(name, name) for name in collapsed])
        changed.append(COLLAPSED_FOLDERS)
    if changed:
        profile.save(update_fields=changed)


def _decoded(text, kind):
    try:
        value = json.loads(text or "null")
    except (TypeError, ValueError):
        return kind()
    return value if isinstance(value, kind) else kind()


def _carry_briefing(user_id, renames):
    """The briefing reads stories from one folder, named "folder:<name>" in story_sources."""
    if not renames:
        return []
    preferences = (
        MBriefingPreferences.objects(user_id=user_id).read_preference(ReadPreference.PRIMARY).first()
    )
    if preferences is None or preferences.story_sources not in renames:
        return []
    old, new = preferences.story_sources, renames[preferences.story_sources]
    if not _set_story_sources(user_id, old, new):
        return []
    return [{"store": BRIEFING_SOURCES, "old": old, "new": new}]


def _revert_briefing(user_id, records):
    for record in reversed(records):
        _set_story_sources(user_id, record["new"], record["old"])


def _set_story_sources(user_id, current, value):
    updated = MBriefingPreferences.objects(user_id=user_id, story_sources=current).update_one(
        set__story_sources=value
    )
    return updated == 1


def _is_record(record):
    if not isinstance(record, dict):
        return False
    return all(isinstance(record.get(name), str) for name in ("store", "old", "new"))


def _is_path(path):
    return isinstance(path, (list, tuple)) and len(path) > 0 and all(isinstance(name, str) for name in path)
