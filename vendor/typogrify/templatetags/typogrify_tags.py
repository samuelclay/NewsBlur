# -*- coding: utf-8 -*-
# Vendored and patched for Django 4.x / Python 3.14 compatibility
import calendar
import re
from datetime import date, timedelta

import smartypants as _smartypants
from vendor.typogrify import titlecase as _titlecase
from django import template
from django.conf import settings
from django.utils.encoding import force_str  # Changed from force_text
from django.utils.html import conditional_escape
from django.utils.safestring import mark_safe
from django.utils.translation import gettext, ngettext  # Changed from ugettext, ungettext

register = template.Library()


__all__ = ['amp', 'caps', 'date', 'fuzzydate', 'initial_quotes',
           'number_suffix', 'smart_filter', 'super_fuzzydate', 'titlecase',
           'widont']


def smart_filter(fn):
    '''
    Escapes filter's content based on template autoescape mode and marks output as safe
    '''
    def wrapper(text, autoescape=None):
        if autoescape:
            esc = conditional_escape
        else:
            esc = lambda x: x

        return mark_safe(fn(esc(text)))
    wrapper.needs_autoescape = True

    register.filter(fn.__name__, wrapper)
    return wrapper


@smart_filter
def amp(text, autoescape=None):
    """Wraps apersands in HTML with ``<span class="amp">`` so they can be
    styled with CSS. Apersands are also normalized to ``&amp;``. Requires
    ampersands to have whitespace or an ``&nbsp;`` on both sides.

    >>> amp('One & two')
    u'One <span class="amp">&amp;</span> two'
    >>> amp('One &amp; two')
    u'One <span class="amp">&amp;</span> two'
    >>> amp('One &#38; two')
    u'One <span class="amp">&amp;</span> two'

    >>> amp('One&nbsp;&amp;&nbsp;two')
    u'One&nbsp;<span class="amp">&amp;</span>&nbsp;two'

    It won't mess up & that are already wrapped, in entities or URLs

    >>> amp('One <span class="amp">&amp;</span> two')
    u'One <span class="amp">&amp;</span> two'
    >>> amp('&ldquo;this&rdquo; & <a href="/?that&amp;test">that</a>')
    u'&ldquo;this&rdquo; <span class="amp">&amp;</span> <a href="/?that&amp;test">that</a>'

    It should ignore standalone amps that are in attributes
    >>> amp('<link href="xyz.html" title="One & Two">xyz</link>')
    u'<link href="xyz.html" title="One & Two">xyz</link>'
    """

    # tag_pattern from http://haacked.com/archive/2004/10/25/usingregularexpressionstomatchhtml.aspx
    # it kinda sucks but it fixes the standalone amps in attributes bug
    tag_pattern = r'</?\w+((\s+\w+(\s*=\s*(?:".*?"|\'.*?\'|[^\'">\s]+))?)+\s*|\s*)/?>'
    amp_finder = re.compile(r"(\s|&nbsp;)(&|&amp;|&\#38;)(\s|&nbsp;)")
    intra_tag_finder = re.compile(
        r'(?P<prefix>(%s)?)(?P<text>([^<]*))(?P<suffix>(%s)?)' % (tag_pattern, tag_pattern))

    def _amp_process(groups):
        prefix = groups.group('prefix') or ''
        text = amp_finder.sub(
            r"""\1<span class="amp">&amp;</span>\3""", groups.group('text'))
        suffix = groups.group('suffix') or ''
        return prefix + text + suffix
    return intra_tag_finder.sub(_amp_process, text)


@smart_filter
def caps(text):
    """Wraps multiple capital letters in ``<span class="caps">``
    so they can be styled with CSS.

    >>> caps("A message from KU")
    u'A message from <span class="caps">KU</span>'

    Uses the smartypants tokenizer to not screw with HTML or with tags it shouldn't.

    >>> caps("<PRE>CAPS</pre> more CAPS")
    u'<PRE>CAPS</pre> more <span class="caps">CAPS</span>'

    >>> caps("A message from 2KU2 with digits")
    u'A message from <span class="caps">2KU2</span> with digits'

    >>> caps("Dotted caps followed by spaces should never include them in the wrap D.O.T.   like so.")
    u'Dotted caps followed by spaces should never include them in the wrap <span class="caps">D.O.T.</span>  like so.'

    All caps with with apostrophes in them shouldn't break. Only handles dump apostrophes though.
    >>> caps("JIMMY'S")
    u'<span class="caps">JIMMY\\'S</span>'

    >>> caps("<i>D.O.T.</i>HE34T<b>RFID</b>")
    u'<i><span class="caps">D.O.T.</span></i><span class="caps">HE34T</span><b><span class="caps">RFID</span></b>'
    """

    tokens = _smartypants._tokenize(text)
    result = []
    in_skipped_tag = False

    cap_finder = re.compile(r"""(
                            (\b[A-Z\d]*        # Group 2: Any amount of caps and digits
                            [A-Z]\d*[A-Z]      # A cap string must at least include two caps (but they can have digits between them)
                            [A-Z\d']*\b)       # Any amount of caps and digits or dumb apostsrophes
                            | (\b[A-Z]+\.\s?   # OR: Group 3: Some caps, followed by a '.' and an optional space
                            (?:[A-Z]+\.\s?)+)  # Followed by the same thing at least once more
                            (?:\s|\b|$))
                            """, re.VERBOSE)

    def _cap_wrapper(matchobj):
        """This is necessary to keep dotted cap strings to pick up extra spaces"""
        if matchobj.group(2):
            return """<span class="caps">%s</span>""" % matchobj.group(2)
        else:
            if matchobj.group(3)[-1] == " ":
                caps = matchobj.group(3)[:-1]
                tail = ' '
            else:
                caps = matchobj.group(3)
                tail = ''
            return """<span class="caps">%s</span>%s""" % (caps, tail)

    tags_to_skip_regex = re.compile(
        r"<(/)?(?:pre|code|kbd|script|math)[^>]*>", re.IGNORECASE)

    for token in tokens:
        if token[0] == "tag":
            # Don't mess with tags.
            result.append(token[1])
            close_match = tags_to_skip_regex.match(token[1])
            if close_match and close_match.group(1) is None:
                in_skipped_tag = True
            else:
                in_skipped_tag = False
        else:
            if in_skipped_tag:
                result.append(token[1])
            else:
                result.append(cap_finder.sub(_cap_wrapper, token[1]))
    return "".join(result)


@smart_filter
def number_suffix(text):
    """Wraps date suffix in <span class="ord">
    so they can be styled with CSS.

    >>> number_suffix("10th")
    u'10<span class="rod">th</span>'

    Uses the smartypants tokenizer to not screw with HTML or with tags it shouldn't.

    """

    suffix_finder = re.compile(r'(?P<number>[\d]+)(?P<ord>st|nd|rd|th)')

    def _suffix_process(groups):
        number = groups.group('number')
        suffix = groups.group('ord')

        return "%s<span class='ord'>%s</span>" % (number, suffix)
    return suffix_finder.sub(_suffix_process, text)


@smart_filter
def initial_quotes(text):
    """Wraps initial quotes in ``class="dquo"`` for double quotes or
    ``class="quo"`` for single quotes. Works in these block tags ``(h1-h6, p, li, dt, dd)``
    and also accounts for potential opening inline elements ``a, em, strong, span, b, i``

    >>> initial_quotes('"With primes"')
    u'<span class="dquo">"</span>With primes"'
    >>> initial_quotes("'With single primes'")
    u'<span class="quo">\\'</span>With single primes\\''

    >>> initial_quotes('<a href="#">"With primes and a link"</a>')
    u'<a href="#"><span class="dquo">"</span>With primes and a link"</a>'

    >>> initial_quotes('&#8220;With smartypanted quotes&#8221;')
    u'<span class="dquo">&#8220;</span>With smartypanted quotes&#8221;'
    """

    quote_finder = re.compile(r"""((<(p|h[1-6]|li|dt|dd)[^>]*>|^)              # start with an opening p, h1-6, li, dd, dt or the start of the string
                                  \s*                                          # optional white space!
                                  (<(a|em|span|strong|i|b)[^>]*>\s*)*)         # optional opening inline tags, with more optional white space for each.
                                  (("|&ldquo;|&\#8220;)|('|&lsquo;|&\#8216;))  # Find me a quote! (only need to find the left quotes and the primes)
                                                                               # double quotes are in group 7, singles in group 8
                                  """, re.VERBOSE)

    def _quote_wrapper(matchobj):
        if matchobj.group(7):
            classname = "dquo"
            quote = matchobj.group(7)
        else:
            classname = "quo"
            quote = matchobj.group(8)
        return """%s<span class="%s">%s</span>""" % (matchobj.group(1), classname, quote)
    output = quote_finder.sub(_quote_wrapper, text)
    return output


@smart_filter
def smartypants(text):
    """Applies smarty pants to curl quotes.

    >>> smartypants('The "Green" man')
    u'The &#8220;Green&#8221; man'
    """

    return _smartypants.smartypants(text)


@smart_filter
def titlecase(text):
    """Support for titlecase.py's titlecasing

    >>> titlecase("this V that")
    u'This v That'

    >>> titlecase("this is just an example.com")
    u'This Is Just an example.com'
    """

    return _titlecase.titlecase(text)


@smart_filter
def widont(text):
    """Replaces the space between the last two words in a string with ``&nbsp;``
    Works in these block tags ``(h1-h6, p, li, dd, dt)`` and also accounts for
    potential closing inline elements ``a, em, strong, span, b, i``

    >>> widont('A very simple test')
    u'A very simple&nbsp;test'

    Single word items shouldn't be changed
    >>> widont('Test')
    u'Test'
    >>> widont(' Test')
    u' Test'
    >>> widont('<ul><li>Test</p></li><ul>')
    u'<ul><li>Test</p></li><ul>'
    >>> widont('<ul><li> Test</p></li><ul>')
    u'<ul><li> Test</p></li><ul>'

    >>> widont('<p>In a couple of paragraphs</p><p>paragraph two</p>')
    u'<p>In a couple of&nbsp;paragraphs</p><p>paragraph&nbsp;two</p>'

    >>> widont('<h1><a href="#">In a link inside a heading</i> </a></h1>')
    u'<h1><a href="#">In a link inside a&nbsp;heading</i> </a></h1>'

    >>> widont('<h1><a href="#">In a link</a> followed by other text</h1>')
    u'<h1><a href="#">In a link</a> followed by other&nbsp;text</h1>'

    Empty HTMLs shouldn't error
    >>> widont('<h1><a href="#"></a></h1>')
    u'<h1><a href="#"></a></h1>'

    >>> widont('<div>Divs get no love!</div>')
    u'<div>Divs get no love!</div>'

    >>> widont('<pre>Neither do PREs</pre>')
    u'<pre>Neither do PREs</pre>'

    >>> widont('<div><p>But divs with paragraphs do!</p></div>')
    u'<div><p>But divs with paragraphs&nbsp;do!</p></div>'
    """

    widont_finder = re.compile(r"""((?:</?(?:a|em|span|strong|i|b)[^>]*>)|[^<>\s]) # must be proceeded by an approved inline opening or closing tag or a nontag/nonspace
                                   \s+                                             # the space to replace
                                   ([^<>\s]+                                       # must be flollowed by non-tag non-space characters
                                   \s*                                             # optional white space!
                                   (</(a|em|span|strong|i|b)>\s*)*                 # optional closing inline tags with optional white space after each
                                   ((</(p|h[1-6]|li|dt|dd)>)|$))                   # end with a closing p, h1-6, li or the end of the string
                                   """, re.VERBOSE)

    output = widont_finder.sub(r'\1&nbsp;\2', text)
    return output


@register.filter
def fuzzydate(value, cutoff=180):
    """
    * takes a value (date) and cutoff (in days)

    If the date is within 1 day of Today:
        Returns
            'today'
            'yesterday'
            'tomorrow'

    If the date is within Today +/- the cutoff:
        Returns
            '2 months ago'
            'in 3 weeks'
            '2 years ago'
            etc.


    if this date is from the current year, but outside the cutoff:
        returns the value for 'CURRENT_YEAR_DATE_FORMAT' in settings if it exists.
        Otherwise returns:
            January 10th
            December 1st

    if the date is not from the current year and outside the cutoff:
        returns the value for 'DATE_FORMAT' in settings if it exists.
    """

    try:
        value = date(value.year, value.month, value.day)
    except AttributeError:
        # Passed value wasn't a date object
        return value
    except ValueError:
        # Date arguments out of range
        return value

    today = date.today()
    delta = value - today

    if delta.days == 0:
        return "today"
    elif delta.days == -1:
        return "yesterday"
    elif delta.days == 1:
        return "tomorrow"

    chunks = (
        (365.0, lambda n: ngettext('year', 'years', n)),
        (30.0, lambda n: ngettext('month', 'months', n)),
        (7.0, lambda n: ngettext('week', 'weeks', n)),
        (1.0, lambda n: ngettext('day', 'days', n)),
    )

    if abs(delta.days) <= cutoff:
        for i, (chunk, name) in enumerate(chunks):
            if abs(delta.days) >= chunk:
                count = abs(round(delta.days / chunk, 0))
                break

        date_str = gettext('%(number)d %(type)s') % {
            'number': count, 'type': name(count)}

        if delta.days > 0:
            return "in " + date_str
        else:
            return date_str + " ago"
    else:
        if value.year == today.year:
            format = getattr(settings, "CURRENT_YEAR_DATE_FORMAT", "F jS")
        else:
            format = getattr(settings, "DATE_FORMAT")

        return template.defaultfilters.date(value, format)
fuzzydate.is_safe = True


@register.filter
def super_fuzzydate(value):
    try:
        value = date(value.year, value.month, value.day)
    except AttributeError:
        # Passed value wasn't a date object
        return value
    except ValueError:
        # Date arguments out of range
        return value

    # today
    today = date.today()
    delta = value - today

    # get the easy values out of the way
    if delta.days == 0:
        return "Today"
    elif delta.days == -1:
        return "Yesterday"
    elif delta.days == 1:
        return "Tomorrow"

    # if we're in the future...
    if value > today:
        end_of_week = today + timedelta(days=7 - today.isoweekday())
        if value <= end_of_week:
            # return the name of the day (Wednesday)
            return 'this %s' % template.defaultfilters.date(value, "l")

        end_of_next_week = end_of_week + timedelta(weeks=1)
        if value <= end_of_next_week:
            # return the name of the day(Next Wednesday)
            return "next %s" % template.defaultfilters.date(value, "l")

        end_of_month = today + \
            timedelta(
                calendar.monthrange(today.year, today.month)[1] - today.day)
        if value <= end_of_month:
            # return the number of weeks (in two weeks)
            if value <= end_of_next_week + timedelta(weeks=1):
                return "in two weeks"
            elif value <= end_of_next_week + timedelta(weeks=2):
                return "in three weeks"
            elif value <= end_of_next_week + timedelta(weeks=3):
                return "in four weeks"
            elif value <= end_of_next_week + timedelta(weeks=4):
                return "in five weeks"

        if today.month == 12:
            next_month = 1
        else:
            next_month = today.month + 1

        end_of_next_month = date(
            today.year, next_month, calendar.monthrange(today.year, today.month)[1])
        if value <= end_of_next_month:
            # if we're in next month
            return 'next month'

        # the last day of the year
        end_of_year = date(today.year, 12, 31)
        if value <= end_of_year:
            # return the month name (March)
            return template.defaultfilters.date(value, "F")

        # the last day of next year
        end_of_next_year = date(today.year + 1, 12, 31)
        if value <= end_of_next_year:
            return 'next %s' % template.defaultfilters.date(value, "F")

        return template.defaultfilters.date(value, "Y")
    else:
        # TODO add the past
        return fuzzydate(value)
super_fuzzydate.is_safe = True


@register.filter
def text_whole_number(value):
    """
    Takes a whole number, and if its less than 10, writes it out in text.

    english only for now.
    """

    try:
        value = int(value)
    except ValueError:
        # Not an int
        return value

    if value <= 10:
        if value == 1:
            value = "one"
        elif value == 2:
            value = "two"
        elif value == 3:
            value = "three"
        elif value == 4:
            value = "four"
        elif value == 5:
            value = "five"
        elif value == 6:
            value = "six"
        elif value == 7:
            value = "seven"
        elif value == 8:
            value = "eight"
        elif value == 9:
            value = "nine"
        elif value == 10:
            value = "ten"
    return value
text_whole_number.is_safe = True


@smart_filter
def typogrify(text):
    """The super typography filter

    Applies the following filters: widont, smartypants, caps, amp, initial_quotes

    >>> typogrify('<h2>"Jayhawks" & KU fans act extremely obnoxiously</h2>')
    u'<h2><span class="dquo">&#8220;</span>Jayhawks&#8221; <span class="amp">&amp;</span> <span class="caps">KU</span> fans act extremely&nbsp;obnoxiously</h2>'

    Each filters properly handles autoescaping.
    >>> conditional_escape(typogrify('<h2>"Jayhawks" & KU fans act extremely obnoxiously</h2>'))
    u'<h2><span class="dquo">&#8220;</span>Jayhawks&#8221; <span class="amp">&amp;</span> <span class="caps">KU</span> fans act extremely&nbsp;obnoxiously</h2>'
    """
    text = force_str(text)
    text = amp(text)
    text = widont(text)
    text = smartypants(text)
    text = caps(text)
    text = initial_quotes(text)
    text = number_suffix(text)

    return text
