"""Turn a story into spoken paragraphs and streamable segments (apps/listen/text.py).

A story is read as its title followed by the article's block elements in document order. Paragraphs are what
the clients highlight (they match them against the rendered story by their opening characters), and segments
are what gets sent to ElevenLabs and streamed: usually one paragraph each, with short neighbors merged and long
paragraphs split at sentence boundaries, so playback can start fast and jump anywhere cheaply.
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


def build_paragraphs(title, html):
    """Title first (index 0), then the article's paragraphs, dropping a leading repeat of the title."""
    title = normalize_whitespace(title)
    paragraphs = [{"index": 0, "kind": "title", "text": title}]
    body = extract_paragraphs(html)
    if body and title and body[0]["text"].lower() == title.lower():
        body = body[1:]
    for paragraph in body:
        paragraphs.append({"index": len(paragraphs), "kind": paragraph["kind"], "text": paragraph["text"]})
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
    """Headings and list items often lack end punctuation; add a period so the voice pauses after them."""
    text = paragraph["text"]
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
    body = [paragraph["text"] for paragraph in paragraphs[1:] if paragraph["kind"] != "heading"]
    if not body:
        return ""
    return _cut_text(" ".join(body), limit)
