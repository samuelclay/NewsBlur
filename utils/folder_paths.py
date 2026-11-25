"""Explicit folder paths for mobile clients; legacy name-based requests remain supported."""

import json
from functools import wraps

from django.utils.translation import gettext_lazy

INVALID_FOLDER_PATH = gettext_lazy("Invalid folder path. Please choose the folder again.")
FOLDER_PATH_CHANGED = gettext_lazy("That folder has changed. Refresh your feeds and choose it again.")


class InvalidFolderPath(ValueError):
    pass


def validate_folder_path(path):
    if not isinstance(path, list) or any(not isinstance(part, str) or not part for part in path):
        raise InvalidFolderPath(INVALID_FOLDER_PATH)
    return path


def parse_folder_path(request, key):
    value = request.POST.get(key)
    if value is None:
        return None
    try:
        return validate_folder_path(json.loads(value))
    except (ValueError, TypeError) as exc:
        raise InvalidFolderPath(INVALID_FOLDER_PATH) from exc


def parse_folder_paths(request, key):
    value = request.POST.get(key)
    if value is None:
        return None
    try:
        paths = json.loads(value)
        if not isinstance(paths, list):
            raise ValueError("Expected paths")
        return [validate_folder_path(path) for path in paths]
    except (ValueError, TypeError) as exc:
        raise InvalidFolderPath("Invalid folder paths. Please choose the folders again.") from exc


def resolve_folder_path(folders, path):
    validate_folder_path(path)
    children = folders
    for name in path:
        matches = [item[name] for item in children if isinstance(item, dict) and name in item]
        if len(matches) != 1:
            raise InvalidFolderPath(FOLDER_PATH_CHANGED)
        children = matches[0]
    return children


def iter_folder_paths(folders, parent=()):
    for item in folders:
        if isinstance(item, dict):
            for name, children in item.items():
                path = (*parent, name)
                yield path
                yield from iter_folder_paths(children, path)


def unique_folder_path(paths):
    matches = list(paths)
    if len(matches) != 1:
        raise InvalidFolderPath(FOLDER_PATH_CHANGED)
    return list(matches[0])


def folder_path_errors(view):
    # views.py applies this inside json_view so invalid/stale paths become normal API errors.
    @wraps(view)
    def wrapped(*args, **kwargs):
        try:
            return view(*args, **kwargs)
        except InvalidFolderPath as exc:
            return {"code": -1, "message": str(exc)}

    return wrapped
