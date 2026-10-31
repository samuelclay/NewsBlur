"""
prefs_guard.py: Snapshot and restore a dev account's view_settings and preferences around a
mobile-web scenario run (.agents/skills/mobile-web/run.py copies this into the web container).

Scenarios toggle layouts, pick Feed or Text in the story screen and switch themes, all of which
save to the account. Every worktree shares one database, so these are the same settings the
main checkout uses. Restore puts back only the keys that changed, leaving anything else alone.
"""

import json

from apps.profile.models import Profile


def main(mode, snapshot_path, username):
    profile = Profile.objects.get(user__username=username)
    if mode == "save":
        with open(snapshot_path, "w") as snapshot:
            json.dump(
                {
                    "view_settings": json.loads(profile.view_settings),
                    "preferences": json.loads(profile.preferences),
                },
                snapshot,
            )
        print(f"prefs_guard: saved {username}'s settings")
        return

    with open(snapshot_path) as snapshot:
        before = json.load(snapshot)
    current = {
        "view_settings": json.loads(profile.view_settings),
        "preferences": json.loads(profile.preferences),
    }
    changed = []
    for field in ("view_settings", "preferences"):
        for key in set(current[field]) | set(before[field]):
            if current[field].get(key) == before[field].get(key):
                continue
            changed.append(f"{field}.{key}: {current[field].get(key)} -> {before[field].get(key)}")
            if key in before[field]:
                current[field][key] = before[field][key]
            else:
                current[field].pop(key, None)
    if changed:
        profile.view_settings = json.dumps(current["view_settings"])
        profile.preferences = json.dumps(current["preferences"])
        profile.save()
    print(f"prefs_guard: restored {changed if changed else 'nothing, no settings changed'}")
