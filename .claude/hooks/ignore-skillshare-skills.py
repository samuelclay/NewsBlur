#!/usr/bin/env python3
"""
Ignore skillshare skills in this repo (.claude/hooks/ignore-skillshare-skills.py)

The skillshare CLI symlinks another organization's shared skills into
~/.claude/skills, where every project sees them. They do not apply to NewsBlur,
and one of them (commit-pr) shares a name with this repo's own skill.

Runs on SessionStart and turns each of those skills off for this checkout by
adding it to skillOverrides in .claude/settings.local.json, which git ignores.
Claude Code matches skillOverrides on the exact directory name and has no
wildcard, so the list is rebuilt from the links on every start. Does nothing
on a machine without skillshare.
"""
import json
import os
import sys
from pathlib import Path

USER_SKILLS = Path.home() / ".claude" / "skills"
SKILLSHARE_SOURCE = Path.home() / ".config" / "skillshare"


def skillshare_skill_names():
    if not USER_SKILLS.is_dir():
        return []
    source = SKILLSHARE_SOURCE.resolve()
    names = []
    for entry in USER_SKILLS.iterdir():
        if entry.is_symlink() and source in entry.resolve().parents:
            names.append(entry.name)
    return sorted(names)


def main():
    names = skillshare_skill_names()
    if not names:
        return
    project = Path(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
    settings_path = project / ".claude" / "settings.local.json"
    settings = {}
    if settings_path.exists():
        try:
            settings = json.loads(settings_path.read_text())
        except ValueError:
            print(f"{settings_path} is not valid JSON; skillshare skills left on", file=sys.stderr)
            return
    overrides = settings.setdefault("skillOverrides", {})
    missing = [name for name in names if overrides.get(name) != "off"]
    if not missing:
        return
    for name in missing:
        overrides[name] = "off"
    settings_path.parent.mkdir(exist_ok=True)
    settings_path.write_text(json.dumps(settings, indent=2) + "\n")


if __name__ == "__main__":
    main()
