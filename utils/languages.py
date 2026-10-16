"""Supported UI locales, shared with the native catalogs in localization/languages.json."""

import json
from pathlib import Path

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
