"""Mirror a CSS stylesheet horizontally for right-to-left (Arabic, Hebrew) pages.

utils/rtl_css.py backs NewsBlur's "full flip" RTL design. A right-to-left page never loads the LTR
"common" (or "blurblog") bundle. It loads a mirrored copy that flip_stylesheet() builds and
apps/profile/language.py serves, so every rule keeps its place in the cascade and only its
physical direction changes. media/css/reader/reader_rtl.css then adds the few overrides that a
mechanical flip can't infer.

flip_stylesheet() keeps every rule and at-rule in its original order and rewrites only
direction-sensitive declarations:

  * margin, padding, border-width/-style/-color and inset 4-value shorthands swap right and left
  * one-sided margin/padding/border properties, left/right offsets and corner radii swap sides
  * border-radius shorthands (including the "/" form) mirror their corners
  * float, clear and text-align swap left and right
  * background positions mirror: keywords swap, percentages become 100% - x, and lengths become
    right edge offsets ("4px center" becomes "right 4px center")
  * horizontal gradient directions (to left/right, 90deg/270deg) swap
  * e/w resize cursors swap, and box-shadow/text-shadow horizontal offsets are negated

Transforms (translateX, scaleX) are never touched, and neither is anything inside @font-face,
@keyframes, @page, @property or @counter-style. Comments are dropped. Selectors matched by the
exclusion patterns below keep some or all of their LTR declarations.

The stylesheet is scanned with one regular expression for braces, semicolons, strings and url()
tokens, so minified bundles (LightningCSS output on a single line) and readable sources take the
same path, and only declarations whose property is direction-sensitive are parsed further.
"""

import re
from urllib.parse import urljoin

# utils/rtl_css.py: JavaScript animates or computes these elements' left/right offsets (the story
# pane slider and mouse indicator in reader.js, the intro carousel and spinning logo in
# reader_intro.js, the growth prompt shimmer transition, and popover containers positioned by
# reader_utils.js), so their offsets stay physical. Their other declarations still flip. The
# patterns also match minified selectors, where LightningCSS writes ::before as :before.
INSET_EXCLUDE = re.compile(
    r"#story_pane|#mouse-indicator|NB-callout-mouse-indicator|NB-intro-spinning-logo|\.carousel|NB-carousel"
    r"|NB-growth-prompt-cta(:hover)?::?before|^\.NB-popover$|^\.popover$"
)

# utils/rtl_css.py: jQuery UI icons pick a cell of a sprite sheet by background offset, so
# mirroring the offset would show a different icon. Any url() naming a sprite is treated the same
# way, and negative horizontal offsets (always a sprite cell) never flip.
BACKGROUND_EXCLUDE = re.compile(r"\.ui-icon")
SPRITE_URL = re.compile(r"url\([^)]*sprite", re.I)

# utils/rtl_css.py: the Chosen select widget ships its own RTL rules (.chzn-rtl in
# media/css/controls/chosen.css, switched on by reader_add_feed.js), written against its LTR base,
# so its rules are left entirely LTR. Flipping them would mirror Chosen twice.
KEEP_EXCLUDE = re.compile(r"\.chzn-")

# utils/rtl_css.py: story bodies and comments carry dir="auto" and follow their own direction, so
# rules for elements inside them stay LTR here and reader_rtl.css gives the few that matter
# (quote bars, widened images) logical sides. A selector is story content when it reaches into a
# story or comment body and its last compound starts with an element name.
CONTENT_HINT = re.compile(
    r"\.NB-feed-story-content(?![\w-])|\.NB-feed-story[\s>+~]+(p|blockquote|ul|ol|li|pre|table|figure)\b"
    r"|\.NB-story-comment-content(?![\w-])|\.NB-story-comment-reply-content(?![\w-])"
    r"|\.NB-story-content(?![\w-])"
)
CONTENT_ELEMENT = re.compile(r"^[a-z][a-z0-9]*", re.I)

# Properties whose name swaps to the other side, keyed by the unprefixed name.
SIDE_SWAP = {}
for _base in ("margin", "padding"):
    SIDE_SWAP[_base + "-left"] = _base + "-right"
    SIDE_SWAP[_base + "-right"] = _base + "-left"
for _suffix in ("", "-width", "-style", "-color"):
    SIDE_SWAP["border-left" + _suffix] = "border-right" + _suffix
    SIDE_SWAP["border-right" + _suffix] = "border-left" + _suffix
for _vertical in ("top", "bottom"):
    SIDE_SWAP["border-%s-left-radius" % _vertical] = "border-%s-right-radius" % _vertical
    SIDE_SWAP["border-%s-right-radius" % _vertical] = "border-%s-left-radius" % _vertical
    # utils/rtl_css.py: old Gecko spelling, as in -moz-border-radius-topleft.
    SIDE_SWAP["border-radius-%sleft" % _vertical] = "border-radius-%sright" % _vertical
    SIDE_SWAP["border-radius-%sright" % _vertical] = "border-radius-%sleft" % _vertical
SIDE_SWAP["left"] = "right"
SIDE_SWAP["right"] = "left"

FOUR_VALUE = {"margin", "padding", "border-width", "border-style", "border-color", "inset"}
KEYWORD_PROPS = {"float", "clear", "text-align"}
BACKGROUND_PROPS = {"background", "background-position", "background-position-x"}
GRADIENT_PROPS = {"background-image", "mask", "mask-image"}
SHADOW_PROPS = {"box-shadow", "text-shadow"}
# Read only, to recognize "left: 50%; transform: translateX(-50%)" centering.
TRANSFORM_PROPS = {"transform", "translate"}
OFFSET_PROPS = {"left", "right", "inset"}

DIRECTIONAL = (
    set(SIDE_SWAP)
    | FOUR_VALUE
    | KEYWORD_PROPS
    | BACKGROUND_PROPS
    | GRADIENT_PROPS
    | SHADOW_PROPS
    | TRANSFORM_PROPS
    | {"border-radius", "cursor"}
)

# At-rules whose block holds style rules. Every other block at-rule (@font-face, @keyframes,
# @page, @property, @counter-style, ...) is copied untouched.
GROUP_AT_RULES = {
    "media",
    "supports",
    "container",
    "layer",
    "document",
    "-moz-document",
    "scope",
    "starting-style",
}

_COMMENT_RE = re.compile(
    r'"(?:[^"\\\n]|\\[\s\S])*"|\'(?:[^\'\\\n]|\\[\s\S])*\'|url\(\s*[^\s"\')][^)]*\)|/\*[\s\S]*?\*/'
)
# One pass over the stylesheet finds the tokens that shape it. Strings, unquoted url()s and
# backslash escapes are matched whole so a brace or semicolon inside them is never structural.
_STRUCTURE_RE = re.compile(
    r'[{};]|"(?:[^"\\\n]|\\[\s\S])*"|\'(?:[^\'\\\n]|\\[\s\S])*\'|url\(\s*[^\s"\')][^)]*\)|\\[\s\S]'
)
_DIRECTIONAL_DECL_RE = re.compile(
    r"(\s*)(-(?:webkit|moz|ms|o)-)?(%s)(\s*:\s*)"
    % "|".join(re.escape(p) for p in sorted(DIRECTIONAL, key=len, reverse=True)),
    re.I,
)
_AT_NAME_RE = re.compile(r"@([-\w]+)")
_IMPORTANT_RE = re.compile(r"\s*!\s*important$", re.I)
_LENGTH_RE = re.compile(r"[-+]?(\d+\.?\d*|\.\d+)(e[-+]?\d+)?([a-z]+|%)?$", re.I)
_ZERO_RE = re.compile(r"[-+]?(0+\.?0*|\.0+)([a-z]+|%)?$", re.I)
_PERCENT_RE = re.compile(r"[-+]?(\d+\.?\d*|\.\d+)%$")
_CURSOR_RE = re.compile(r"(?<![\w-])(e|w|ne|nw|se|sw|nesw|nwse)-resize(?![\w-])", re.I)
_CURSOR_SWAP = {
    "e": "w",
    "w": "e",
    "ne": "nw",
    "nw": "ne",
    "se": "sw",
    "sw": "se",
    "nesw": "nwse",
    "nwse": "nesw",
}
_SIDE_WORD_RE = re.compile(r"(?<![\w-])(left|right)(?![\w-])", re.I)
_GRADIENT_RE = re.compile(
    r"((?:-webkit-|-moz-|-o-)?(?:repeating-)?(?:linear|radial)-gradient|-webkit-gradient)\(", re.I
)
_TRANSLATE_X_CENTER_RE = re.compile(r"translate(?:x|3d)?\(\s*-50%|^\s*-50%", re.I)
_POSITION_WORDS = {"left", "right", "center", "top", "bottom"}
_KEYWORD_SWAP = {}
for _prefix in ("", "-webkit-", "-moz-"):
    _KEYWORD_SWAP[_prefix + "left"] = _prefix + "right"
    _KEYWORD_SWAP[_prefix + "right"] = _prefix + "left"


class _Rule:
    """utils/rtl_css.py: a style rule whose declarations are collected until its closing brace."""

    __slots__ = ("selector", "start", "body_start", "decls", "nested")

    def __init__(self, selector, start, body_start, nested=False):
        self.selector = selector
        self.start = start
        self.body_start = body_start
        self.decls = []
        self.nested = nested


_GROUP = "group"
_RAW = "raw"


def flip_stylesheet(css):
    """Return the whole stylesheet mirrored horizontally (see the utils/rtl_css.py docstring)."""
    css = strip_comments(css)
    edits = []
    stack = []
    segment_start = 0
    for match in _STRUCTURE_RE.finditer(css):
        token = match.group()
        if token == ";":
            if stack and stack[-1].__class__ is _Rule:
                stack[-1].decls.append((segment_start, match.start()))
            segment_start = match.end()
        elif token == "{":
            top = stack[-1] if stack else None
            if top is _RAW:
                stack.append(_RAW)
            else:
                raw_prelude = css[segment_start : match.start()]
                prelude = raw_prelude.strip()
                start = segment_start + len(raw_prelude) - len(raw_prelude.lstrip())
                if prelude.startswith("@"):
                    name = _AT_NAME_RE.match(prelude)
                    if name and name.group(1).lower() in GROUP_AT_RULES:
                        if top.__class__ is _Rule:
                            # utils/rtl_css.py: a nested @media inside a style rule holds that rule's declarations.
                            top.nested = True
                            stack.append(_Rule(top.selector, start, match.end(), nested=True))
                        else:
                            stack.append(_GROUP)
                    else:
                        stack.append(_RAW)
                elif top.__class__ is _Rule:
                    # utils/rtl_css.py: native CSS nesting resolves "&" to the parent selector.
                    top.nested = True
                    selector = (
                        prelude.replace("&", top.selector) if "&" in prelude else top.selector + " " + prelude
                    )
                    stack.append(_Rule(selector, start, match.end(), nested=True))
                else:
                    stack.append(_Rule(prelude, start, match.end()))
            segment_start = match.end()
        elif token == "}":
            top = stack.pop() if stack else None
            if top.__class__ is _Rule:
                top.decls.append((segment_start, match.start()))
                _flip_rule(css, top, match.end(), edits)
            segment_start = match.end()
    if not edits:
        return css
    edits.sort(key=lambda edit: edit[0])
    pieces = []
    position = 0
    for start, end, text in edits:
        pieces.append(css[position:start])
        pieces.append(text)
        position = end
    pieces.append(css[position:])
    return "".join(pieces)


_URL_TOKEN_RE = re.compile(r"""(url\(\s*)(['"]?)([^'"()\s]+)(\2\s*\))|(@import\s+)(['"])([^'"]+)(\6)""", re.I)
_ABSOLUTE_URL_RE = re.compile(r"(/|#|[a-z][a-z0-9+.-]*:)", re.I)


def absolutize_urls(css, stylesheet_url):
    """Resolve relative url() and @import targets against the URL the stylesheet was linked from.

    utils/rtl_css.py: apps/profile/language.py serves flipped CSS from its own path, so a relative
    reference in a source file would otherwise resolve against the wrong directory.
    """

    def resolve(match):
        if match.group(1):
            prefix, quote, target, suffix = match.group(1, 2, 3, 4)
        else:
            prefix, quote, target, suffix = match.group(5, 6, 7, 8)
        if _ABSOLUTE_URL_RE.match(target):
            return match.group()
        return prefix + quote + urljoin(stylesheet_url, target) + suffix

    return _URL_TOKEN_RE.sub(resolve, css)


def strip_comments(css):
    if "/*" not in css:
        return css
    return _COMMENT_RE.sub(lambda match: "" if match.group().startswith("/*") else match.group(), css)


def _flip_rule(css, rule, end, edits):
    """Queue edits for one style rule, splitting its selector list when exclusions differ."""
    directional = []
    for decl_start, decl_end in rule.decls:
        match = _DIRECTIONAL_DECL_RE.match(css, decl_start, decl_end)
        if match:
            directional.append((decl_start, decl_end, match))
    if not directional:
        return

    decls = []
    for decl_start, decl_end, match in directional:
        raw_value = css[match.end() : decl_end]
        value = raw_value.rstrip()
        trailing = raw_value[len(value) :]
        important = _IMPORTANT_RE.search(value)
        important_text = ""
        if important:
            important_text = value[important.start() :]
            value = value[: important.start()]
        decls.append(
            {
                "start": decl_start,
                "end": decl_end,
                "lead": match.group(1),
                "prefix": match.group(2) or "",
                "base": match.group(3).lower(),
                "separator": match.group(4),
                "value": value,
                "suffix": important_text + trailing,
            }
        )
    if all(decl["base"] in TRANSFORM_PROPS for decl in decls):
        return

    facts = _rule_facts(decls)
    groups = {}
    for selector in split_top(rule.selector, ","):
        selector = selector.strip()
        if selector:
            groups.setdefault(_selector_flags(selector), []).append(selector)

    if len(groups) == 1 or rule.nested:
        # utils/rtl_css.py: a nested rule keeps its selector list whole and takes the most cautious flags.
        flags = tuple(any(flag) for flag in zip(*groups)) if groups else (False, False, False)
        edits.extend(_decl_edits(decls, flags, facts))
        return

    body = css[rule.body_start : end - 1]
    rules = []
    for flags, selectors in groups.items():
        group_edits = _decl_edits(decls, flags, facts)
        position = rule.body_start
        pieces = []
        for start, stop, text in group_edits:
            pieces.append(css[position:start])
            pieces.append(text)
            position = stop
        pieces.append(css[position : end - 1])
        rules.append(",".join(selectors) + "{" + ("".join(pieces) if group_edits else body) + "}")
    edits.append((rule.start, end, "".join(rules)))


def _selector_flags(selector):
    """Return (keep every declaration, keep offsets, keep background positions) for one selector."""
    keep = bool(KEEP_EXCLUDE.search(selector)) or (
        bool(CONTENT_HINT.search(selector)) and bool(CONTENT_ELEMENT.match(_key_compound(selector)))
    )
    return (keep, bool(INSET_EXCLUDE.search(selector)), bool(BACKGROUND_EXCLUDE.search(selector)))


def _key_compound(selector):
    selector = re.sub(r"::?[\w-]+(\([^)]*\))?", "", selector)
    parts = re.split(r"[\s>+~]+", selector.strip())
    return parts[-1] if parts else ""


def _rule_facts(decls):
    """Rule-wide facts the per-declaration mirroring needs."""
    centered = any(
        decl["base"] in ("left", "right") and decl["value"].strip() == "50%" for decl in decls
    ) and any(
        decl["base"] in TRANSFORM_PROPS and _TRANSLATE_X_CENTER_RE.search(decl["value"]) for decl in decls
    )
    return {"centered": centered}


def _decl_edits(decls, flags, facts):
    keep, keep_offsets, keep_background = flags
    if keep:
        return []
    keep_offsets = keep_offsets or facts["centered"]
    edits = []
    for decl in decls:
        flipped = _flip_declaration(decl, keep_offsets, keep_background)
        if flipped is None:
            continue
        base, value = flipped
        edits.append(
            (
                decl["start"],
                decl["end"],
                decl["lead"] + decl["prefix"] + base + decl["separator"] + value + decl["suffix"],
            )
        )
    return edits


def _flip_declaration(decl, keep_offsets, keep_background):
    """Return (property, value) for a mirrored declaration, or None when it stays as it is."""
    base = decl["base"]
    value = decl["value"]
    if base in SIDE_SWAP:
        if base in OFFSET_PROPS and keep_offsets:
            return None
        return SIDE_SWAP[base], value
    if base in FOUR_VALUE:
        if base in OFFSET_PROPS and keep_offsets:
            return None
        return _changed(base, value, mirror_four(value))
    if base == "border-radius":
        return _changed(base, value, mirror_radius(value))
    if base in KEYWORD_PROPS:
        keyword = value.strip().lower()
        if keyword in _KEYWORD_SWAP:
            return base, value.replace(value.strip(), _KEYWORD_SWAP[keyword])
        return None
    if base in BACKGROUND_PROPS:
        sprite = keep_background or bool(SPRITE_URL.search(value))
        if base == "background-position-x":
            flipped = (
                value if sprite else ",".join(mirror_position_x(layer) for layer in split_top(value, ","))
            )
        elif base == "background-position":
            flipped = value if sprite else ",".join(mirror_position(layer) for layer in split_top(value, ","))
        else:
            flipped = mirror_background(value, sprite)
        return _changed(base, value, flipped)
    if base in GRADIENT_PROPS:
        return _changed(base, value, mirror_gradients(value))
    if base in SHADOW_PROPS:
        return _changed(base, value, mirror_shadow(value))
    if base == "cursor":
        return _changed(base, value, _CURSOR_RE.sub(_swap_cursor, value))
    return None


def _changed(base, value, flipped):
    return None if flipped == value else (base, flipped)


def _swap_side(match):
    word = match.group(1)
    swapped = "right" if word.lower() == "left" else "left"
    return swapped.upper() if word.isupper() else swapped


def _swap_cursor(match):
    return _CURSOR_SWAP[match.group(1).lower()] + "-resize"


def split_top(text, separator):
    """Split on a separator that sits outside parentheses and strings."""
    if "(" not in text and '"' not in text and "'" not in text:
        return text.split(separator)
    parts = []
    depth = 0
    quote = None
    start = 0
    index = 0
    length = len(text)
    while index < length:
        char = text[index]
        if quote:
            if char == "\\":
                index += 1
            elif char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == separator and depth == 0:
            parts.append(text[start:index])
            start = index + 1
        index += 1
    parts.append(text[start:])
    return parts


def split_space(text):
    """Split a value into its top-level space-separated components."""
    if "(" not in text and '"' not in text and "'" not in text:
        return text.split()
    parts = []
    depth = 0
    quote = None
    current = []
    for char in text:
        if quote:
            current.append(char)
            if char == quote:
                quote = None
        elif char in "\"'":
            quote = char
            current.append(char)
        elif char == "(":
            depth += 1
            current.append(char)
        elif char == ")":
            depth -= 1
            current.append(char)
        elif char.isspace() and depth == 0:
            if current:
                parts.append("".join(current))
                current = []
        else:
            current.append(char)
    if current:
        parts.append("".join(current))
    return parts


def mirror_four(value):
    parts = split_space(value)
    if len(parts) != 4 or parts[1] == parts[3]:
        return value
    top, right, bottom, left = parts
    return " ".join((top, left, bottom, right))


def mirror_radius(value):
    if "/" in value:
        halves = split_top(value, "/")
        if len(halves) == 2:
            return mirror_radius(halves[0].strip()) + " / " + mirror_radius(halves[1].strip())
        return value
    parts = split_space(value)
    if len(parts) == 2:
        top_left_bottom_right, top_right_bottom_left = parts
        if top_left_bottom_right == top_right_bottom_left:
            return value
        return " ".join((top_right_bottom_left, top_left_bottom_right))
    if len(parts) == 3:
        top_left, top_right_bottom_left, bottom_right = parts
        if top_left == top_right_bottom_left == bottom_right:
            return value
        return " ".join((top_right_bottom_left, top_left, top_right_bottom_left, bottom_right))
    if len(parts) == 4:
        top_left, top_right, bottom_right, bottom_left = parts
        if top_left == top_right and bottom_right == bottom_left:
            return value
        return " ".join((top_right, top_left, bottom_left, bottom_right))
    return value


def _is_zero(token):
    return bool(_ZERO_RE.match(token))


def _is_length(token):
    return bool(_LENGTH_RE.match(token)) or token.lower().startswith("calc(")


def _format_number(number):
    text = ("%.4f" % number).rstrip("0").rstrip(".")
    return "0" if text in ("", "-0") else text


def mirror_position(position):
    """Mirror one background-position layer, keeping sprite offsets and anything it can't read."""
    leading = position[: len(position) - len(position.lstrip())]
    trailing = position[len(position.rstrip()) :]
    tokens = split_space(position)
    flipped = _mirror_position_tokens(tokens)
    if flipped is None:
        return position
    return leading + " ".join(flipped) + trailing


def _mirror_position_tokens(tokens):
    if not tokens or len(tokens) > 4:
        return None
    lowered = [token.lower() for token in tokens]
    if "left" in lowered or "right" in lowered:
        return [_SIDE_WORD_RE.sub(_swap_side, token) for token in tokens]
    if len(tokens) > 2 or lowered[0] in ("center", "top", "bottom"):
        return None
    x, rest = tokens[0], tokens[1:]
    if _PERCENT_RE.match(x):
        number = float(x[:-1])
        if number == 50:
            return None
        return [_format_number(100 - number) + "%"] + rest
    if not _is_length(x) or x.startswith("-"):
        # utils/rtl_css.py: a negative offset selects a sprite cell; var() can't be read here.
        return None
    if _is_zero(x):
        return ["100%"] + rest
    if not rest:
        return ["right", x, "center"]
    y = rest[0]
    if y.lower() in ("top", "bottom", "center"):
        return ["right", x, y]
    return ["right", x, "top", y]


def mirror_position_x(value):
    leading = value[: len(value) - len(value.lstrip())]
    trailing = value[len(value.rstrip()) :]
    tokens = split_space(value)
    if not tokens:
        return value
    lowered = [token.lower() for token in tokens]
    if "left" in lowered or "right" in lowered:
        flipped = [_SIDE_WORD_RE.sub(_swap_side, token) for token in tokens]
    elif len(tokens) != 1 or lowered[0] == "center":
        return value
    elif _PERCENT_RE.match(tokens[0]):
        number = float(tokens[0][:-1])
        if number == 50:
            return value
        flipped = [_format_number(100 - number) + "%"]
    elif _is_length(tokens[0]) and not tokens[0].startswith("-"):
        flipped = ["100%"] if _is_zero(tokens[0]) else ["right", tokens[0]]
    else:
        return value
    return leading + " ".join(flipped) + trailing


def _is_position_token(token):
    return token.lower() in _POSITION_WORDS or _is_length(token)


def mirror_background(value, sprite):
    """Mirror the gradient directions and image positions inside a background shorthand."""
    layers = split_top(value, ",")
    flipped_layers = []
    for layer in layers:
        flipped = mirror_gradients(layer)
        if not sprite:
            flipped = _mirror_background_layer(flipped)
        flipped_layers.append(flipped)
    return ",".join(flipped_layers)


def _mirror_background_layer(layer):
    leading = layer[: len(layer) - len(layer.lstrip())]
    trailing = layer[len(layer.rstrip()) :]
    tokens = []
    for token in split_space(layer):
        if "/" in token and "(" not in token:
            # utils/rtl_css.py: "center/16px" carries the position and the size in one token.
            head, _, tail = token.partition("/")
            tokens.extend(part for part in (head, "/", tail) if part)
        else:
            tokens.append(token)
    lowered = [token.lower() for token in tokens]
    sized = "/" in tokens
    has_image = any(
        token.startswith(("url(", "image-set(", "-webkit-image-set(")) or (sized and "gradient(" in token)
        for token in lowered
    )
    if not has_image:
        # utils/rtl_css.py: a color, or a gradient filling the whole box, looks the same from either
        # edge. LightningCSS writes "background: transparent" as "background: 0 0", too.
        return layer
    position_indexes = []
    after_slash = False
    for index, token in enumerate(tokens):
        if token == "/":
            after_slash = True
            continue
        if after_slash:
            if _is_length(token) or token.lower() in ("auto", "cover", "contain"):
                continue
            after_slash = False
        if _is_position_token(token):
            position_indexes.append(index)
    if not position_indexes:
        # utils/rtl_css.py: no position means top left, the same as "0 0", which LightningCSS drops
        # from minified bundles, so both mirror to the top right.
        return leading + " ".join(tokens + ["100%", "0"]) + trailing
    if position_indexes != list(range(position_indexes[0], position_indexes[-1] + 1)):
        return layer
    first, last = position_indexes[0], position_indexes[-1] + 1
    flipped = _mirror_position_tokens(tokens[first:last])
    if flipped is None:
        return layer
    return leading + " ".join(tokens[:first] + flipped + tokens[last:]) + trailing


def mirror_gradients(value):
    """Swap horizontal gradient directions (to left/right, 90deg/270deg, -webkit-gradient points)."""
    if "gradient" not in value.lower():
        return value
    pieces = []
    position = 0
    for match in _GRADIENT_RE.finditer(value):
        open_paren = match.end()
        close_paren = _matching_paren(value, open_paren - 1)
        if close_paren is None or open_paren < position:
            continue
        name = match.group(1).lower()
        arguments = split_top(value[open_paren:close_paren], ",")
        if name == "-webkit-gradient":
            # utils/rtl_css.py: -webkit-gradient(linear, left top, right top, ...) names both points.
            arguments[1:3] = [_SIDE_WORD_RE.sub(_swap_side, argument) for argument in arguments[1:3]]
        else:
            arguments[0] = _mirror_gradient_direction(arguments[0], name)
        pieces.append(value[position:open_paren])
        pieces.append(",".join(arguments))
        position = close_paren
    pieces.append(value[position:])
    return "".join(pieces)


def _mirror_gradient_direction(argument, name):
    stripped = argument.strip().lower()
    if "radial" in name:
        return _SIDE_WORD_RE.sub(_swap_side, argument) if " at " in " " + stripped else argument
    if stripped.startswith("to ") or (name.startswith("-") and stripped.split(" ")[0] in ("left", "right")):
        return _SIDE_WORD_RE.sub(_swap_side, argument)
    if not name.startswith("-"):
        angles = {"90deg": "270deg", "270deg": "90deg", "-90deg": "90deg"}
        if stripped in angles:
            return argument.replace(argument.strip(), angles[stripped])
    return argument


def _matching_paren(text, open_index):
    depth = 0
    quote = None
    for index in range(open_index, len(text)):
        char = text[index]
        if quote:
            if char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index
    return None


def mirror_shadow(value):
    """Negate the horizontal offset of every box-shadow or text-shadow layer."""
    flipped_layers = []
    changed = False
    for layer in split_top(value, ","):
        tokens = split_space(layer)
        for index, token in enumerate(tokens):
            if _LENGTH_RE.match(token):
                if not _is_zero(token):
                    tokens[index] = token[1:] if token[0] == "-" else "-" + token.lstrip("+")
                    changed = True
                    leading = layer[: len(layer) - len(layer.lstrip())]
                    trailing = layer[len(layer.rstrip()) :]
                    layer = leading + " ".join(tokens) + trailing
                break
            if token.lower().startswith(("calc(", "var(")):
                # utils/rtl_css.py: an offset (or color) from calc() or var() before the first length is
                # ambiguous, so the layer stays as it is.
                break
        flipped_layers.append(layer)
    return ",".join(flipped_layers) if changed else value
