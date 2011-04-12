import re

from django.conf import settings
from django import template
from django.utils.html import conditional_escape
from django.utils.safestring import mark_safe
from django.utils.encoding import smart_str, force_unicode

import vendor.typogrify.smartypants as _smartypants
import vendor.typogrify.titlecase as _titlecase

register = template.Library()

@register.filter
def textile(value):
    try:
        import textile
    except ImportError:
        if settings.DEBUG:
            raise template.TemplateSyntaxError("Error in {% textile %} filter: The Python textile library isn't installed.")
        return force_unicode(value)
    else:
        return mark_safe(force_unicode(textile.textile(smart_str(value), encoding='utf-8', output='utf-8')))

@register.filter
def textile_restricted(value):
    try:
        import textile
    except ImportError:
        if settings.DEBUG:
            raise template.TemplateSyntaxError, "Error in {% textile %} filter: The Python textile library isn't installed."
        return force_unicode(value)
    else:
        return mark_safe(force_unicode(textile.textile_restricted(smart_str(value), noimage=False)))

def amp(text):
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
    text = force_unicode(text)
    # tag_pattern from http://haacked.com/archive/2004/10/25/usingregularexpressionstomatchhtml.aspx
    # it kinda sucks but it fixes the standalone amps in attributes bug
    tag_pattern = '</?\w+((\s+\w+(\s*=\s*(?:".*?"|\'.*?\'|[^\'">\s]+))?)+\s*|\s*)/?>'
    amp_finder = re.compile(r"(\s|&nbsp;)(&|&amp;|&\#38;)(\s|&nbsp;)")
    intra_tag_finder = re.compile(r'(?P<prefix>(%s)?)(?P<text>([^<]*))(?P<suffix>(%s)?)' % (tag_pattern, tag_pattern))
    def _amp_process(groups):
        prefix = groups.group('prefix') or ''
        text = amp_finder.sub(r"""\1<span class="amp">&amp;</span>\3""", groups.group('text'))
        suffix = groups.group('suffix') or ''
        return prefix + text + suffix
    output = intra_tag_finder.sub(_amp_process, text)
    return mark_safe(output)
amp.is_safe = True

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
    text = force_unicode(text)

    tokens = _smartypants._tokenize(text)
    result = []
    in_skipped_tag = False

    cap_finder = re.compile(r"""(
                            (\b[A-Z\d]*        # Group 2: Any amount of caps and digits
                            [A-Z]\d*[A-Z]      # A cap string much at least include two caps (but they can have digits between them)
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

    tags_to_skip_regex = re.compile("<(/)?(?:pre|code|kbd|script|math)[^>]*>", re.IGNORECASE)
    
    
    for token in tokens:
        if token[0] == "tag":
            # Don't mess with tags.
            result.append(token[1])
            close_match = tags_to_skip_regex.match(token[1])
            if close_match and close_match.group(1) == None:
                in_skipped_tag = True
            else:
                in_skipped_tag = False
        else:
            if in_skipped_tag:
                result.append(token[1])
            else:
                result.append(cap_finder.sub(_cap_wrapper, token[1]))
    output = "".join(result)
    return mark_safe(output)
caps.is_safe = True

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
    text = force_unicode(text)
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
    return mark_safe(output)
initial_quotes.is_safe = True

def smartypants(text):
    """Applies smarty pants to curl quotes.
    
    >>> smartypants('The "Green" man')
    u'The &#8220;Green&#8221; man'
    """
    text = force_unicode(text)

    output = _smartypants.smartyPants(text)
    return mark_safe(output)
smartypants.is_safe = True

def titlecase(text):
    """Support for titlecase.py's titlecasing

    >>> titlecase("this V that")
    u'This v That'

    >>> titlecase("this is just an example.com")
    u'This Is Just an example.com'
    """
    text = force_unicode(text)

    return _titlecase.titlecase(text)

def typogrify(text):
    """The super typography filter
    
    Applies the following filters: widont, smartypants, caps, amp, initial_quotes
    
    >>> typogrify('<h2>"Jayhawks" & KU fans act extremely obnoxiously</h2>')
    u'<h2><span class="dquo">&#8220;</span>Jayhawks&#8221; <span class="amp">&amp;</span> <span class="caps">KU</span> fans act extremely&nbsp;obnoxiously</h2>'

    Each filters properly handles autoescaping.
    >>> conditional_escape(typogrify('<h2>"Jayhawks" & KU fans act extremely obnoxiously</h2>'))
    u'<h2><span class="dquo">&#8220;</span>Jayhawks&#8221; <span class="amp">&amp;</span> <span class="caps">KU</span> fans act extremely&nbsp;obnoxiously</h2>'
    """
    text = force_unicode(text)
    text = amp(text)
    text = widont(text)
    text = smartypants(text)
    text = caps(text)
    text = initial_quotes(text)
    return text

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
    text = force_unicode(text)
    widont_finder = re.compile(r"""((?:</?(?:a|em|span|strong|i|b)[^>]*>)|[^<>\s]) # must be proceeded by an approved inline opening or closing tag or a nontag/nonspace
                                   \s+                                             # the space to replace
                                   ([^<>\s]+                                       # must be flollowed by non-tag non-space characters
                                   \s*                                             # optional white space! 
                                   (</(a|em|span|strong|i|b)>\s*)*                 # optional closing inline tags with optional white space after each
                                   ((</(p|h[1-6]|li|dt|dd)>)|$))                   # end with a closing p, h1-6, li or the end of the string
                                   """, re.VERBOSE)
    output = widont_finder.sub(r'\1&nbsp;\2', text)
    return mark_safe(output)
widont.is_safe = True

register.filter('amp', amp)
register.filter('caps', caps)
register.filter('initial_quotes', initial_quotes)
register.filter('smartypants', smartypants)
register.filter('titlecase', titlecase)
register.filter('typogrify', typogrify)
register.filter('widont', widont)

def _test():
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()
