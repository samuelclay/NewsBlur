"""
Whitelisting HTML sanitizer.

Copyright (c) 2009-2010 Lefora <samuel@lefora.com>

See LICENSE for license details.
"""

__author__ = "Samuel Stauffer <samuel@lefora.com>"
__version__ = "1.6.1"
__license__ = "BSD"
__all__ = ['Scrubber', 'SelectiveScriptScrubber', 'ScrubberWarning', 'UnapprovedJavascript', 'urlize']

import re, string
from urlparse import urljoin
from itertools import chain
from BeautifulSoup import BeautifulSoup, Comment

def urlize(text, trim_url_limit=None, nofollow=False, autoescape=False):
    """Converts any URLs in text into clickable links.

    If trim_url_limit is not None, the URLs in link text longer than this limit
    will truncated to trim_url_limit-3 characters and appended with an elipsis.

    If nofollow is True, the URLs in link text will get a rel="nofollow"
    attribute.

    If autoescape is True, the link text and URLs will get autoescaped.

    *Modified from Django*
    """
    from urllib import quote as urlquote
    
    LEADING_PUNCTUATION  = ['(', '<', '&lt;']
    TRAILING_PUNCTUATION = ['.', ',', ')', '>', '\n', '&gt;']
    
    word_split_re = re.compile(r'([\s\xa0]+|&nbsp;)') # a0 == NBSP
    punctuation_re = re.compile('^(?P<lead>(?:%s)*)(?P<middle>.*?)(?P<trail>(?:%s)*)$' % \
        ('|'.join([re.escape(x) for x in LEADING_PUNCTUATION]),
        '|'.join([re.escape(x) for x in TRAILING_PUNCTUATION])))
    simple_email_re = re.compile(r'^\S+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9._-]+$')
    del x # Temporary variable

    def escape(html):
        return html.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", '&#39;')

    trim_url = lambda x, limit=trim_url_limit: limit is not None and (len(x) > limit and ('%s...' % x[:max(0, limit - 3)])) or x
    words = word_split_re.split(text)
    nofollow_attr = nofollow and ' rel="nofollow"' or ''
    for i, word in enumerate(words):
        match = None
        if '.' in word or '@' in word or ':' in word:
            match = punctuation_re.match(word.replace(u'\u2019', "'"))
        if match:
            lead, middle, trail = match.groups()
            middle = middle.encode('utf-8')
            # Make URL we want to point to.
            url = None
            if middle.startswith('http://') or middle.startswith('https://'):
                url = urlquote(middle, safe='%/&=:;#?+*')
            elif middle.startswith('www.') or ('@' not in middle and \
                    middle and middle[0] in string.ascii_letters + string.digits and \
                    (middle.endswith('.org') or middle.endswith('.net') or middle.endswith('.com'))):
                url = urlquote('http://%s' % middle, safe='%/&=:;#?+*')
            elif '@' in middle and not ':' in middle and simple_email_re.match(middle):
                url = 'mailto:%s' % middle
                nofollow_attr = ''
            # Make link.
            if url:
                trimmed = trim_url(middle)
                if autoescape:
                    lead, trail = escape(lead), escape(trail)
                    url, trimmed = escape(url), escape(trimmed)
                middle = '<a href="%s"%s>%s</a>' % (url, nofollow_attr, trimmed)
                words[i] = '%s%s%s' % (lead, middle.decode('utf-8'), trail)
            elif autoescape:
                words[i] = escape(word)
        elif autoescape:
            words[i] = escape(word)
    return u''.join(words)
    
class ScrubberWarning(object):
    pass

class Scrubber(object):
    allowed_tags = set((
            'a', 'abbr', 'acronym', 'b', 'bdo', 'big', 'blockquote', 'br',
            'center', 'cite', 'code',
            'dd', 'del', 'dfn', 'div', 'dl', 'dt', 'em', 'embed', 'font',
            'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'hr', 'i', 'img', 'ins',
            'kbd', 'li', 'object', 'ol', 'param', 'pre', 'p', 'q',
            's', 'samp', 'small', 'span', 'strike', 'strong', 'sub', 'sup',
            'table', 'tbody', 'td', 'th', 'thead', 'tr', 'tt', 'ul', 'u',
            'var', 'wbr',
        ))
    disallowed_tags_save_content = set((
            'blink', 'body', 'html',
        ))
    allowed_attributes = set((
            'align', 'alt', 'border', 'cite', 'class', 'dir',
            'height', 'href', 'src', 'style', 'title', 'type', 'width',
            'face', 'size', # font tags
            'flashvars', # Not sure about flashvars - if any harm can come from it
            'classid', # FF needs the classid on object tags for flash
            'name', 'value', 'quality', 'data', 'scale', # for flash embed param tags, could limit to just param if this is harmful
            'salign', 'align', 'wmode',
        )) # Bad attributes: 'allowscriptaccess', 'xmlns', 'target'
    normalized_tag_replacements = {'b': 'strong', 'i': 'em'}

    def __init__(self, base_url=None, autolink=True, nofollow=True, remove_comments=True):
        self.base_url = base_url
        self.autolink = autolink and bool(urlize)
        self.nofollow = nofollow
        self.remove_comments = remove_comments
        self.allowed_tags = self.__class__.allowed_tags.copy()
        self.disallowed_tags_save_content = self.__class__.disallowed_tags_save_content.copy()
        self.allowed_attributes = self.__class__.allowed_attributes.copy()
        self.normalized_tag_replacements = self.__class__.normalized_tag_replacements.copy()
        self.warnings = []

        # Find all _scrub_tab_<name> methods
        self.tag_scrubbers = {}
        for k in chain(*[cls.__dict__ for cls in self.__class__.__mro__]):
            if k.startswith('_scrub_tag_'):
                self.tag_scrubbers[k[11:]] = [getattr(self, k)]

    def autolink_soup(self, soup):
        """Autolink urls in text nodes that aren't already linked (inside anchor tags)."""
        def _autolink(node):
            if isinstance(node, basestring):
                text = node
                text2 = urlize(text, nofollow=self.nofollow)
                if text != text2:
                    node.replaceWith(text2)
            else:
                if node.name == "a":
                    return

                for child in node.contents:
                    _autolink(child)
        _autolink(soup)

    def strip_disallowed(self, soup):
        """Remove nodes and attributes from the soup that aren't specifically allowed."""
        toremove = []
        for node in soup.recursiveChildGenerator():
            if self.remove_comments and isinstance(node, Comment):
                toremove.append((False, node))
                continue

            if isinstance(node, basestring):
                continue

            # Remove disallowed tags
            if node.name not in self.allowed_tags:
                toremove.append((node.name in self.disallowed_tags_save_content, node))
                continue

            # Remove disallowed attributes
            attrs = []
            for k, v in node.attrs:
                if not v:
                    continue

                if k.lower() not in self.allowed_attributes:
                    continue

                # TODO: This probably needs to be more robust
                v2 = v.lower()
                if any(x in v2 for x in ('javascript:', 'vbscript:', 'expression(')):
                    continue

                attrs.append((k,v))
            node.attrs = attrs

        self._remove_nodes(toremove)

    def normalize_html(self, soup):
        """Convert tags to a standard set. (e.g. convert 'b' tags to 'strong')"""
        for node in soup.findAll(self.normalized_tag_replacements.keys()):
            node.name = self.normalized_tag_replacements[node.name]
        # for node in soup.findAll('br', clear="all"):
        #     node.extract()

    def _remove_nodes(self, nodes):
        """Remove a list of nodes from the soup."""
        for keep_contentes, node in nodes:
            if keep_contentes and node.contents:
                idx = node.parent.contents.index(node)
                for n in reversed(list(node.contents)): # Copy the contents list to avoid modifying while traversing
                    node.parent.insert(idx, n)
            node.extract()

    def _clean_path(self, node, attrname):
        url = node.get(attrname)
        if url and '://' not in url and not url.startswith('mailto:'):
            print url
            if url[0] not in ('/', '.') and not self.base_url:
                node[attrname] = "http://" + url
            elif not url.startswith('http') and self.base_url:
                print self.base_url
                node[attrname] = urljoin(self.base_url, url)

    def _scrub_tag_a(self, a):
        if self.nofollow:
            a['rel'] = "nofollow"

        if not a.get('class', None):
            a['class'] = "external"

        self._clean_path(a, 'href')

    def _scrub_tag_img(self, img):
        try:
            if img['src'].lower().startswith('chrome://'):
                return True
        except KeyError:
            return True

        # Make sure images always have an 'alt' attribute
        img['alt'] = img.get('alt', '')

        self._clean_path(img, 'src')

    def _scrub_tag_font(self, node):
        attrs = []
        for k, v in node.attrs:
            if k.lower() == 'size' and v.startswith('+'):
                # Remove "size=+0"
                continue
            attrs.append((k, v))
        node.attrs = attrs

        if len(node.attrs) == 0:
            # IE renders font tags with no attributes differently then other browsers so remove them
            return "keep_contents"

    def _scrub_html_pre(self, html):
        """Process the html before sanitization"""
        return html

    def _scrub_html_post(self, html):
        """Process the html after sanitization"""
        return html

    def _scrub_soup(self, soup):
        self.strip_disallowed(soup)

        if self.autolink:
            self.autolink_soup(soup)

        toremove = []
        for tag_name, scrubbers in self.tag_scrubbers.items():
            for node in soup(tag_name):
                for scrub in scrubbers:
                    remove = scrub(node)
                    if remove:
                        # Remove the node from the tree
                        toremove.append((remove == "keep_contents", node))
                        break

        self._remove_nodes(toremove)

        self.normalize_html(soup)

    def scrub(self, html):
        """Return a sanitized version of the given html."""

        self.warnings = []

        html = self._scrub_html_pre(html)
        soup = BeautifulSoup(html)
        self._scrub_soup(soup)
        html = unicode(soup)
        return self._scrub_html_post(html)

class UnapprovedJavascript(ScrubberWarning):
    def __init__(self, src):
        self.src = src
        self.path = src[:src.rfind('/')]

class SelectiveScriptScrubber(Scrubber):
    allowed_tags = Scrubber.allowed_tags | set(('script', 'noscript', 'iframe'))
    allowed_attributes = Scrubber.allowed_attributes | set(('scrolling', 'frameborder'))

    def __init__(self, *args, **kwargs):
        super(SelectiveScriptScrubber, self).__init__(*args, **kwargs)

        self.allowed_script_srcs = set((
            'http://www.statcounter.com/counter/counter_xhtml.js',
            # 'http://www.google-analytics.com/urchin.js',
            'http://pub.mybloglog.com/',
            'http://rpc.bloglines.com/blogroll',
            'http://widget.blogrush.com/show.js',
            'http://re.adroll.com/',
            'http://widgetserver.com/',
            'http://pagead2.googlesyndication.com/pagead/show_ads.js', # are there pageadX for all kinds of numbers?
        ))

        self.allowed_script_line_res = set(re.compile(text) for text in (
             r"^(var )?sc_project\=\d+;$",
             r"^(var )?sc_invisible\=\d;$",
             r"^(var )?sc_partition\=\d+;$",
             r'^(var )?sc_security\="[A-Za-z0-9]+";$',
             # """^_uacct \= "[^"]+";$""",
             # """^urchinTracker\(\);$""",
             r'^blogrush_feed = "[^"]+";$',
             # """^!--$""",
             # """^//-->$""",
        ))

        self.allowed_iframe_srcs = set(re.compile(text) for text in (
            r'^http://www\.google\.com/calendar/embed\?[\w&;=\%]+$', # Google Calendar
            r'^https?://www\.youtube\.com/', # YouTube
            r'^http://player\.vimeo\.com/', # Vimeo
        ))

    def _scrub_tag_script(self, script):
        src = script.get('src', None)
        if src:
            for asrc in self.allowed_script_srcs:
                # TODO: It could be dangerous to only check "start" of string
                #       as there could be browser bugs using crafted urls
                if src.startswith(asrc):
                    script.contents = []
                    break
            else:
                self.warnings.append(UnapprovedJavascript(src))
                script.extract()
        elif script.get('type', '') != 'text/javascript':
            script.extract()
        else:
            for line in script.string.splitlines():
                line = line.strip()
                if not line:
                    continue

                line_match = any(line_re.match(line) for line_re in self.allowed_script_line_res)

                if not line_match:
                    script.extract()
                    break

    def _scrub_tag_iframe(self, iframe):
        src = iframe.get('src', None)
        if not src or not any(asrc.match(src) for asrc in self.allowed_iframe_srcs):
            iframe.extract()
