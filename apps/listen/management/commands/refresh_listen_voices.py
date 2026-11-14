import collections
import datetime
import json

from django.core.management.base import BaseCommand, CommandError

from apps.listen import elevenlabs
from apps.listen.voices import (
    CATALOG_PATH,
    ELEVENLABS_LANGUAGES,
    NAME_TAGLINE_RE,
    normalize_voice,
)

VOICES_PER_LANGUAGE = 10
PAGES_PER_LANGUAGE = 2
MINIMUM_NOTICE_DAYS = 90
USE_CASE_SCORES = {
    "narrative_story": 3,
    "informative_educational": 3,
    "conversational": 2,
    "entertainment_tv": 1,
}
EXCLUDED_USE_CASES = {"characters_animation", "advertisement"}
ACCENTS_PER_LANGUAGE = 12


class Command(BaseCommand):
    help = """Rebuild apps/listen/voice_catalog.json from the ElevenLabs voice library.

    For each of NewsBlur's 21 languages, picks the most used library voices suited to reading articles
    (narration, informative, conversational), balanced by gender and preferring the language's locale and
    voices whose owners must give long notice before removing them. Commit the regenerated file.

    Example:
        python manage.py refresh_listen_voices
        python manage.py refresh_listen_voices --language he --language th
    """

    def add_arguments(self, parser):
        parser.add_argument("--language", action="append", help="Only refresh these languages")

    def handle(self, *args, **options):
        if not elevenlabs.is_configured():
            raise CommandError("ELEVENLABS_API_KEY is not configured")

        existing = {"premade": [], "languages": {}}
        if CATALOG_PATH.exists():
            existing = json.loads(CATALOG_PATH.read_text())
        languages = options.get("language") or list(ELEVENLABS_LANGUAGES)
        unknown = [language for language in languages if language not in ELEVENLABS_LANGUAGES]
        if unknown:
            raise CommandError(f"Unknown languages: {', '.join(unknown)}")

        catalog = {
            "generated_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
            "premade": self.premade_voices() or existing.get("premade", []),
            "languages": dict(existing.get("languages", {})),
        }
        for language in languages:
            entry = self.language_entry(language)
            if entry["voices"]:
                catalog["languages"][language] = entry
            self.stdout.write(
                f"{language}: {len(entry['voices'])} voices, default {entry.get('default')} "
                f"({', '.join(voice['name'] for voice in entry['voices'])})"
            )
        CATALOG_PATH.write_text(json.dumps(catalog, indent=1, ensure_ascii=False, sort_keys=True) + "\n")
        self.stdout.write(f"Wrote {CATALOG_PATH}")

    def premade_voices(self):
        response = elevenlabs.account_voices()
        if not response:
            return []
        return [
            normalize_voice(voice, source="premade")
            for voice in response.get("voices", [])
            if voice.get("category") == "premade"
        ]

    def language_entry(self, language):
        elevenlabs_language, locales = ELEVENLABS_LANGUAGES[language]
        candidates = []
        for page in range(PAGES_PER_LANGUAGE):
            response = elevenlabs.shared_voices(
                language=elevenlabs_language, sort="usage_character_count_1y", page_size=100, page=page
            )
            if not response:
                break
            candidates.extend(response.get("voices", []))
            if not response.get("has_more"):
                break

        accents = collections.Counter(voice.get("accent") for voice in candidates if voice.get("accent"))
        ranked = sorted(
            (voice for voice in candidates if self.is_suitable(voice, locales)),
            key=lambda voice: self.rank(voice, locales),
        )
        picked = self.balanced_pick(ranked)
        voices = [normalize_voice(voice, source="curated") for voice in picked]
        default = self.default_voice(voices, locales)
        return {
            "voices": voices,
            "default": default,
            "accents": [accent for accent, _ in accents.most_common(ACCENTS_PER_LANGUAGE)],
        }

    def default_voice(self, voices, locales):
        """The top narrator in the language's primary locale, else the top narrator, else the top voice."""
        narrators = [
            voice for voice in voices if voice["use_case"] in ("narrative_story", "informative_educational")
        ]
        for candidates in (
            [voice for voice in narrators if locales and voice["locale"] == locales[0]],
            narrators,
            voices,
        ):
            if candidates:
                return candidates[0]["voice_id"]
        return None

    def is_suitable(self, voice, locales):
        if voice.get("use_case") in EXCLUDED_USE_CASES:
            return False
        notice = voice.get("notice_period")
        if notice is not None and notice < MINIMUM_NOTICE_DAYS:
            return False
        # A language with two scripts (zh-Hans/zh-Hant) only takes voices from its own locale.
        if (
            locales
            and voice.get("locale")
            and locales[0].startswith("cmn")
            and voice["locale"] not in locales
        ):
            return False
        return True

    def rank(self, voice, locales):
        locale_bonus = 1 if (not locales or voice.get("locale") in locales) else 0
        return (
            -locale_bonus,
            -USE_CASE_SCORES.get(voice.get("use_case"), 0),
            -(voice.get("usage_character_count_1y") or 0),
        )

    def balanced_pick(self, ranked):
        by_gender = collections.defaultdict(list)
        for voice in ranked:
            by_gender[voice.get("gender") or "neutral"].append(voice)
        picked = []
        names = set()
        while len(picked) < VOICES_PER_LANGUAGE and any(by_gender.values()):
            for gender in ("female", "male", "neutral"):
                while by_gender[gender]:
                    voice = by_gender[gender].pop(0)
                    name = NAME_TAGLINE_RE.split(voice.get("name", ""), maxsplit=1)[0].strip().lower()
                    if name in names:
                        continue
                    names.add(name)
                    picked.append(voice)
                    break
                if len(picked) >= VOICES_PER_LANGUAGE:
                    break
        return picked
