"""Story language detection for Listen (apps/listen/language.py).

Listen picks a voice per language, so it needs to know what language a story is written in. Stories carry no
reliable language metadata, and the voice only has to match one of NewsBlur's 21 interface languages
(localization/languages.json), so this is a small dependency-free detector: Unicode script decides most
languages outright, and stopword frequency separates the Latin and Cyrillic script languages.
"""

import re
import unicodedata

SAMPLE_CHARACTERS = 4000
MINIMUM_LETTERS = 20

# Characters that only exist in one of the two Chinese scripts, used to choose zh-Hans or zh-Hant.
SIMPLIFIED_ONLY = set("们这为说时会来过还进对开关问题发经与东车长门见现实们国个后从发动应学种当义战计报处观统权证认议边区组际变选级")
TRADITIONAL_ONLY = set("們這為說時會來過還進對開關問題發經與東車長門見現實國個後從發動應學種當義戰計報處觀統權證認議邊區組際變選級")

UKRAINIAN_LETTERS = set("іїєґ")
# Letters only Vietnamese writes among the Latin script languages: its tone marks, ơ, ư and đ. Plain â, ê
# and ô are left out because French and Portuguese write them too (tempête, forêt, você, avô), and so is ă,
# which Romanian writes.
VIETNAMESE_LETTERS = set("đơưạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ")

STOPWORDS = {
    "en": "the and of to in is that for it with as was on are be this by have from or at an not but they".split(),
    "es": "de la que el en y los del se las por un para con una es al lo como más pero sus le ya".split(),
    "fr": "de la le et les des en du un une est que pour qui dans sur pas par au plus avec ce sont".split(),
    "de": "der die und in den von zu das mit sich des auf für ist im dem nicht ein eine als auch es".split(),
    "pt-BR": "de que não da em um para com uma os no se na por mais as dos como mas foi ao ele das".split(),
    "it": "di che il la per non una sono del della con gli le si nel alla anche questo ma come più".split(),
    "nl": "de het een van en in is dat op te zijn voor met die niet aan er ook als maar om bij".split(),
    "pl": "w i na nie się z do to że jest jak co ale po od za tak dla są przez już".split(),
    "tr": "ve bir bu da de için ile çok olarak daha gibi ama en kadar sonra olan değil var".split(),
    "id": "yang dan di ini itu dengan untuk dari tidak dalam akan pada juga ada ke karena atau oleh".split(),
    "vi": "của và là có được cho không trong người những một các với này đã để khi đến".split(),
    "ru": "и в не на что я с он как это по но из у за от так все она же".split(),
    "uk": "і в не на що з як це до за та але від так його все вона ж ти".split(),
}
STOPWORD_SETS = {language: set(words) for language, words in STOPWORDS.items()}
LATIN_LANGUAGES = ["en", "es", "fr", "de", "pt-BR", "it", "nl", "pl", "tr", "id", "vi"]
CYRILLIC_LANGUAGES = ["ru", "uk"]

WORD_RE = re.compile(r"[^\W\d_]+", re.UNICODE)


def _script(character):
    """Coarse Unicode script for a letter, from its character name."""
    if "぀" <= character <= "ヿ" or "ㇰ" <= character <= "ㇿ":
        return "kana"
    if "가" <= character <= "힯" or "ᄀ" <= character <= "ᇿ" or "㄰" <= character <= "㆏":
        return "hangul"
    if "一" <= character <= "鿿" or "㐀" <= character <= "䶿":
        return "han"
    try:
        name = unicodedata.name(character)
    except ValueError:
        return None
    for script in ("THAI", "HEBREW", "ARABIC", "DEVANAGARI", "CYRILLIC", "LATIN"):
        if name.startswith(script):
            return script.lower()
    return None


def detect_language(text):
    """Return one of our 21 language codes for `text`, or None when there isn't enough text to tell."""
    if not text:
        return None
    sample = text[:SAMPLE_CHARACTERS]
    counts = {}
    letters = 0
    for character in sample:
        if not character.isalpha():
            continue
        script = _script(character)
        if not script:
            continue
        counts[script] = counts.get(script, 0) + 1
        letters += 1
    if letters < MINIMUM_LETTERS:
        return None

    def share(script):
        return counts.get(script, 0) / letters

    if share("kana") > 0.05:
        return "ja"
    if share("hangul") > 0.2:
        return "ko"
    if share("han") > 0.2:
        simplified = sum(1 for character in sample if character in SIMPLIFIED_ONLY)
        traditional = sum(1 for character in sample if character in TRADITIONAL_ONLY)
        return "zh-Hant" if traditional > simplified else "zh-Hans"
    for script, language in (("thai", "th"), ("hebrew", "he"), ("arabic", "ar"), ("devanagari", "hi")):
        if share(script) > 0.3:
            return language

    lowered = sample.lower()
    words = WORD_RE.findall(lowered)
    if share("cyrillic") > 0.3:
        if sum(1 for character in lowered if character in UKRAINIAN_LETTERS) >= 3:
            return "uk"
        return _best_stopword_match(_stopword_scores(words, CYRILLIC_LANGUAGES)) or "ru"
    if share("latin") > 0.3:
        scores = _stopword_scores(words, LATIN_LANGUAGES)
        # Vietnamese names (Nguyễn, Hồ Chí Minh) carry these letters into other languages' stories too, so the
        # letters only decide it when no other language's stopwords outscore Vietnamese ones.
        vietnamese_letters = sum(1 for character in lowered if character in VIETNAMESE_LETTERS)
        if vietnamese_letters >= 5 and scores["vi"] >= max(scores.values()):
            return "vi"
        return _best_stopword_match(scores)
    return None


def _stopword_scores(words, languages):
    scores = {language: 0 for language in languages}
    for word in words:
        for language in languages:
            if word in STOPWORD_SETS[language]:
                scores[language] += 1
    return scores


def _best_stopword_match(scores):
    best = max(scores, key=lambda language: scores[language])
    if scores[best] < 2:
        return None
    return best
