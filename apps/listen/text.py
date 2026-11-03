"""Turn a story into spoken paragraphs and streamable segments (apps/listen/text.py).

A story is read as its title followed by the article's block elements in document order. Paragraphs are what
the clients highlight (they match them against the rendered story by their opening characters), and segments
are what gets sent to ElevenLabs and streamed: usually one paragraph each, with short neighbors merged and long
paragraphs split at sentence boundaries, so playback can start fast and jump anywhere cheaply.

A headline repeated at the top of the story is read once. A paragraph that is only the title (after a byline,
with different quotes or punctuation) is dropped; one that goes on, like Techmeme's "Author / Source : Headline
— excerpt", keeps its `text` for highlighting and gets a `spoken` form without the headline.
"""

import re

import lxml.html
from lxml.etree import ParserError, XMLSyntaxError

BLOCK_KINDS = {
    "p": "text",
    "h1": "heading",
    "h2": "heading",
    "h3": "heading",
    "h4": "heading",
    "h5": "heading",
    "h6": "heading",
    "li": "list",
    "blockquote": "quote",
    "dd": "text",
    "dt": "text",
}
CONTAINER_TAGS = {
    "div",
    "section",
    "article",
    "main",
    "header",
    "ul",
    "ol",
    "dl",
    "center",
    "body",
    "html",
    "details",
    "summary",
}
SKIP_TAGS = {
    "script",
    "style",
    "noscript",
    "svg",
    "canvas",
    "iframe",
    "pre",
    "table",
    "figure",
    "figcaption",
    "audio",
    "video",
    "object",
    "embed",
    "form",
    "button",
    "nav",
    "aside",
    "footer",
    "img",
    "picture",
    "select",
    "textarea",
}

# Characters per second of speech at 1x, used to estimate durations before audio exists.
CHARACTERS_PER_SECOND = {
    "ja": 7.0,
    "zh-Hans": 5.0,
    "zh-Hant": 5.0,
    "ko": 7.0,
    "th": 11.0,
    "hi": 13.0,
    "ar": 13.0,
    "he": 13.0,
    "ru": 14.0,
    "uk": 14.0,
    "vi": 14.0,
}
DEFAULT_CHARACTERS_PER_SECOND = 15.0

PARAGRAPH_PREFIX_LENGTH = 160
MERGE_BELOW_CHARACTERS = 200
TARGET_SEGMENT_CHARACTERS = 600
MAX_SEGMENT_CHARACTERS = 700
CONTEXT_CHARACTERS = 300

WHITESPACE_RE = re.compile(r"\s+")
NOT_PROSE_RE = re.compile(r"caption|credit|gallery", re.IGNORECASE)
MAX_CAPTION_CHARACTERS = 1000
LETTER_RE = re.compile(r"[^\W\d_]", re.UNICODE)
SENTENCE_END_RE = re.compile(r"(?<=[.!?。！？])\s+|(?<=[。！？])")
TERMINAL_PUNCTUATION = tuple(".!?:;。！？…\"'”’»")
WORD_RE = re.compile(r"[^\W_]+", re.UNICODE)
# Techmeme and other aggregators end titles with the author and source: "Headline (Jane Doe/The Verge)".
TRAILING_ATTRIBUTION_RE = re.compile(r"\s*\([^()]*\)\s*$")
# What may separate a repeated headline from the rest of its paragraph, and may lead the spoken remainder.
HEADLINE_SEPARATOR_CHARACTERS = " \t\u2014\u2013-:|.\u00b7\u2022;\u2026\"'\u201d\u2019\u00bb)]"
# A byline like "Jane Doe / The Verge : " may come before the headline inside the same paragraph.
MAX_BYLINE_CHARACTERS = 80
# A byline or dateline paragraph this short may come before the paragraph that repeats the headline.
MAX_SHORT_LEAD_CHARACTERS = 80
# A title this long is cut from the front of a longer first sentence even without punctuation after it; a
# shorter one ("Update") is only cut when punctuation separates it from the rest ("Update. The body...").
MIN_UNSEPARATED_HEADLINE_WORDS = 5


def normalize_whitespace(text):
    return WHITESPACE_RE.sub(" ", text or "").strip()


def characters_per_second(language):
    return CHARACTERS_PER_SECOND.get(language, DEFAULT_CHARACTERS_PER_SECOND)


def estimate_seconds(text, language):
    return round(len(text) / characters_per_second(language), 1)


def extract_paragraphs(html):
    """Block-level text of an HTML document as [{"kind": ..., "text": ...}], in reading order."""
    if not html or not html.strip():
        return []
    try:
        document = lxml.html.fromstring(html)
    except (ParserError, XMLSyntaxError, ValueError):
        return []
    paragraphs = []
    _collect(document, paragraphs, inherited_kind=None)
    return [paragraph for paragraph in paragraphs if LETTER_RE.search(paragraph["text"])]


def _tag(element):
    return element.tag.lower() if isinstance(element.tag, str) else None


def _has_block_descendant(element):
    for descendant in element.iterdescendants():
        tag = _tag(descendant)
        if tag in BLOCK_KINDS or tag in CONTAINER_TAGS:
            return True
    return False


def _is_skipped(element):
    """Elements that aren't article prose: SKIP_TAGS, hidden decoration, and image captions, credits and
    galleries, which sites mark by class rather than with <figure>."""
    tag = _tag(element)
    if tag is None or tag in SKIP_TAGS or element.get("aria-hidden") == "true":
        return True
    if not NOT_PROSE_RE.search(f"{element.get('class') or ''} {element.get('id') or ''}"):
        return False
    # A long element is an article wrapper that happens to mention galleries, not a caption.
    return len(element.text_content()) < MAX_CAPTION_CHARACTERS


def _inline_text(element):
    """Text of an inline element, leaving out anything _is_skipped."""
    pieces = [element.text or ""]
    for child in element:
        tag = _tag(child)
        if tag == "br":
            pieces.append(" ")
        elif not _is_skipped(child):
            pieces.append(_inline_text(child))
        pieces.append(child.tail or "")
    return "".join(pieces)


def _collect(element, paragraphs, inherited_kind):
    buffer = []

    def flush():
        text = normalize_whitespace("".join(buffer))
        buffer.clear()
        if text:
            paragraphs.append({"kind": inherited_kind or "text", "text": text})

    buffer.append(element.text or "")
    for child in element:
        tag = _tag(child)
        if _is_skipped(child):
            pass
        elif tag == "br":
            buffer.append(" ")
        elif tag in BLOCK_KINDS and not _has_block_descendant(child):
            flush()
            text = normalize_whitespace(_inline_text(child))
            if text:
                paragraphs.append({"kind": inherited_kind or BLOCK_KINDS[tag], "text": text})
        elif tag in BLOCK_KINDS or tag in CONTAINER_TAGS or _has_block_descendant(child):
            flush()
            kind = inherited_kind or {"blockquote": "quote", "li": "list"}.get(tag)
            _collect(child, paragraphs, inherited_kind=kind)
        else:
            buffer.append(_inline_text(child))
        buffer.append(child.tail or "")
    flush()


def _words(text):
    """(casefolded word, start, end) for each run of letters and digits, so quotes and punctuation don't matter."""
    return [(match.group(0).casefold(), match.start(), match.end()) for match in WORD_RE.finditer(text)]


def _headline_word_lists(title):
    """The title's words, then the title's words without a trailing "(Author/Source)"."""
    variants = []
    for candidate in (title, TRAILING_ATTRIBUTION_RE.sub("", title)):
        words = [word for word, _, _ in _words(candidate)]
        if words and words not in variants:
            variants.append(words)
    return variants


def strip_repeated_headline(title, text):
    """`text` without a repeat of `title` at its start (or after a short byline), "" when nothing else was
    there, or `text` itself when the title isn't repeated."""
    words = _words(text)
    if not words:
        return text
    for headline in _headline_word_lists(title):
        count = len(headline)
        for position in range(len(words) - count + 1):
            if words[position][1] > MAX_BYLINE_CHARACTERS:
                break
            if [word for word, _, _ in words[position : position + count]] != headline:
                continue
            remainder = text[words[position + count - 1][2] :]
            spoken = remainder.lstrip(HEADLINE_SEPARATOR_CHARACTERS).strip()
            if not LETTER_RE.search(spoken):
                return ""
            separated = bool(
                remainder[: len(remainder) - len(remainder.lstrip(HEADLINE_SEPARATOR_CHARACTERS))].strip()
            )
            if separated or count >= MIN_UNSEPARATED_HEADLINE_WORDS:
                return spoken
    return text


def _without_repeated_headline(title, body):
    """`body` with the headline read once: the first paragraph, or the second when the first is a short byline
    or dateline, loses its repeat of the title. Dropped outright when that is all it said, else kept with its
    full `text` for the clients' highlighting and a `spoken` remainder for the voice."""
    for position, paragraph in enumerate(body[:2]):
        if position and len(body[position - 1]["text"]) > MAX_SHORT_LEAD_CHARACTERS:
            break
        spoken = strip_repeated_headline(title, paragraph["text"])
        if spoken == paragraph["text"]:
            continue
        if not spoken:
            return body[:position] + body[position + 1 :]
        return body[:position] + [dict(paragraph, spoken=spoken)] + body[position + 1 :]
    return body


def build_paragraphs(title, html):
    """Title first (index 0), then the article's paragraphs, reading a headline repeated at the top only once."""
    title = normalize_whitespace(title)
    paragraphs = [{"index": 0, "kind": "title", "text": title}]
    body = extract_paragraphs(html)
    if title:
        body = _without_repeated_headline(title, body)
    for paragraph in body:
        spoken_paragraph = {"index": len(paragraphs), "kind": paragraph["kind"], "text": paragraph["text"]}
        if "spoken" in paragraph:
            spoken_paragraph["spoken"] = paragraph["spoken"]
        paragraphs.append(spoken_paragraph)
    return paragraphs


def split_sentences(text, limit):
    """Split text into chunks no longer than `limit`, breaking at sentence ends, else at spaces."""
    sentences = [sentence for sentence in SENTENCE_END_RE.split(text) if sentence and sentence.strip()]
    chunks = []
    current = ""
    for sentence in sentences:
        sentence = sentence.strip()
        while len(sentence) > limit:
            cut = sentence.rfind(" ", 0, limit)
            cut = cut if cut > limit // 2 else limit
            if current:
                chunks.append(current)
                current = ""
            chunks.append(sentence[:cut].strip())
            sentence = sentence[cut:].strip()
        if current and len(current) + 1 + len(sentence) > limit:
            chunks.append(current)
            current = sentence
        else:
            current = f"{current} {sentence}".strip()
    if current:
        chunks.append(current)
    return chunks


def _spoken(paragraph):
    """What the voice reads: the paragraph without a repeated headline (apps/listen/text.py build_paragraphs).
    Headings and list items often lack end punctuation; add a period so the voice pauses after them."""
    text = paragraph.get("spoken", paragraph["text"])
    if paragraph["kind"] in ("heading", "list", "title") and not text.endswith(TERMINAL_PUNCTUATION):
        return text + "."
    return text


def build_segments(paragraphs, title_suffix=""):
    """Group paragraphs into segments: [{"index", "paragraphs": [paragraph indexes], "text"}].

    Segment 0 is always the title alone (plus `title_suffix`, e.g. "From The Verge.") so audio starts quickly.
    """
    segments = []
    if not paragraphs:
        return segments
    title_text = " ".join(part for part in (_spoken(paragraphs[0]), title_suffix) if part)
    segments.append({"paragraphs": [0], "text": title_text})

    pending = None
    for paragraph in paragraphs[1:]:
        text = _spoken(paragraph)
        if len(text) > MAX_SEGMENT_CHARACTERS:
            if pending:
                segments.append(pending)
                pending = None
            for chunk in split_sentences(text, TARGET_SEGMENT_CHARACTERS):
                segments.append({"paragraphs": [paragraph["index"]], "text": chunk})
            continue
        if pending and (
            len(pending["text"]) < MERGE_BELOW_CHARACTERS
            and len(pending["text"]) + len(text) + 2 <= TARGET_SEGMENT_CHARACTERS
        ):
            pending["paragraphs"].append(paragraph["index"])
            pending["text"] = f"{pending['text']}\n\n{text}"
            continue
        if pending:
            segments.append(pending)
        pending = {"paragraphs": [paragraph["index"]], "text": text}
    if pending:
        segments.append(pending)

    for index, segment in enumerate(segments):
        segment["index"] = index
        segment["previous_text"] = segments[index - 1]["text"][-CONTEXT_CHARACTERS:] if index else ""
        segment["next_text"] = (
            segments[index + 1]["text"][:CONTEXT_CHARACTERS] if index + 1 < len(segments) else ""
        )
    return segments


def truncate_segments(segments, seconds, language):
    """Keep only the first `seconds` of speech, cutting the last segment at a sentence or word boundary."""
    budget = int(seconds * characters_per_second(language))
    kept = []
    used = 0
    for segment in segments:
        remaining = budget - used
        if remaining <= 0:
            break
        segment = dict(segment)
        if len(segment["text"]) > remaining:
            segment["text"] = _cut_text(segment["text"], remaining)
            segment["next_text"] = ""
            kept.append(segment)
            break
        kept.append(segment)
        used += len(segment["text"])
    return kept


def _cut_text(text, limit):
    head = text[:limit]
    sentence_end = max(head.rfind(mark) for mark in (". ", "! ", "? ", "。", "！", "？"))
    if sentence_end > limit // 2:
        return head[: sentence_end + 1].strip()
    space = head.rfind(" ")
    if space > limit // 2:
        return head[:space].strip()
    return head.strip()


def preview_text(paragraphs, limit=160):
    """The opening of a story for voice previews: its first sentence or two, up to `limit` characters."""
    body = [
        paragraph.get("spoken", paragraph["text"])
        for paragraph in paragraphs[1:]
        if paragraph["kind"] != "heading"
    ]
    if not body:
        return ""
    return _cut_text(" ".join(body), limit)
