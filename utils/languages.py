"""Supported UI locales, shared with the native catalogs in localization/languages.json."""

import functools
import json
from pathlib import Path

from django.utils import formats, translation

LANGUAGES = json.loads((Path(__file__).resolve().parent.parent / "localization/languages.json").read_text())
LANGUAGE_CODES = {code.lower(): code for code in LANGUAGES}


def normalize_language(value):
    if not isinstance(value, str):
        return None
    value = value.replace("_", "-").lower()
    if value == "auto":
        return "auto"
    return LANGUAGE_CODES.get(value)


def match_language(value):
    value = value.replace("_", "-").lower()
    exact = normalize_language(value)
    if exact and exact != "auto":
        return exact
    if value.startswith("zh"):
        return (
            "zh-Hant" if any(part in value.split("-") for part in ("hant", "tw", "hk", "mo")) else "zh-Hans"
        )
    if value == "pt" or value.startswith("pt-"):
        return "pt-BR"
    return LANGUAGE_CODES.get(value.split("-")[0])


def localized_number(number):
    """utils/languages.py groups digits the way the active language does: 1,234 in English, 1.234 in German."""
    return formats.number_format(number, use_l10n=True, force_grouping=True)


def account_language(profile):
    """utils/languages.py picks the language to write to an account in when there's no request to negotiate
    with, as in emails: the account's explicit choice, then the language its devices last asked for
    (recorded by apps/profile/language.py), then English."""
    try:
        preferences = json.loads(profile.preferences or "{}")
    except ValueError:
        preferences = {}
    choice = normalize_language(preferences.get("language")) if isinstance(preferences, dict) else None
    if choice and choice != "auto":
        return choice
    last_seen = normalize_language(profile.last_seen_language)
    return last_seen if last_seen and last_seen != "auto" else "en"


def account_translation(profile):
    """Render templates and gettext calls in this account's language: `with account_translation(profile):`."""
    return translation.override(account_language(profile).lower())


def in_account_language(method):
    """Decorates a Profile method that emails its own user, so the templates and subject it renders use
    that user's language (apps/profile/models.py)."""

    @functools.wraps(method)
    def wrapper(profile, *args, **kwargs):
        with account_translation(profile):
            return method(profile, *args, **kwargs)

    return wrapper
