#!/usr/bin/env python
"""Pynliner : Convert CSS to inline styles

Python CSS-to-inline-styles conversion tool for HTML using BeautifulSoup and cssutils

Copyright (c) 2011 Tanner Netterville

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

The generated output of this software shall not be used in a mass marketing service.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

"""

__version__ = "0.4.0"

import urllib2
import cssutils
from BeautifulSoup import BeautifulSoup
from soupselect import select

class Pynliner(object):
    """Pynliner class"""

    soup = False
    style_string = False
    stylesheet = False
    output = False

    def __init__(self, log=None):
        self.log = log
        cssutils.log.enabled = False if log is None else True

    def from_url(self, url):
        """Gets remote HTML page for conversion

        Downloads HTML page from `url` as a string and passes it to the
        `from_string` method. Also sets `self.root_url` and `self.relative_url`
        for use in importing <link> elements.

        Returns self.

        >>> p = Pynliner()
        >>> p.from_url('http://somewebsite.com/file.html')
        <Pynliner object at 0x26ac70>
        """
        self.url = url
        self.relative_url = '/'.join(url.split('/')[:-1]) + '/'
        self.root_url = '/'.join(url.split('/')[:3])
        self.source_string = self._get_url(self.url)
        return self

    def from_string(self, string):
        """Generates a Pynliner object from the given HTML string.

        Returns self.

        >>> p = Pynliner()
        >>> p.from_string('<style>h1 { color:#ffcc00; }</style><h1>Hello World!</h1>')
        <Pynliner object at 0x26ac70>
        """
        self.source_string = string
        return self

    def with_cssString(self, cssString):
        """Adds external CSS to the Pynliner object. Can be "chained".

        Returns self.

        >>> html = "<h1>Hello World!</h1>"
        >>> css = "h1 { color:#ffcc00; }"
        >>> p = Pynliner()
        >>> p.from_string(html).with_cssString(css)
        <pynliner.Pynliner object at 0x2ca810>
        """
        if not self.style_string:
            self.style_string = cssString + u'\n'
        else:
            self.style_string += cssString + u'\n'
        return self

    def run(self):
        """Applies each step of the process if they have not already been
        performed.

        Returns Unicode output with applied styles.

        >>> html = "<style>h1 { color:#ffcc00; }</style><h1>Hello World!</h1>"
        >>> Pynliner().from_string(html).run()
        u'<h1 style="color: #fc0">Hello World!</h1>'
        """
        if not self.soup:
            self._get_soup()
        if not self.stylesheet:
            self._get_styles()
        self._apply_styles()
        return self._get_output()

    def _get_url(self, url):
        """Returns the response content from the given url
        """
        return urllib2.urlopen(url).read()

    def _get_soup(self):
        """Convert source string to BeautifulSoup object. Sets it to self.soup.

        If using mod_wgsi, use html5 parsing to prevent BeautifulSoup incompatibility.
        """
        # Check if mod_wsgi is running - see http://code.google.com/p/modwsgi/wiki/TipsAndTricks
        try:
            from mod_wsgi import version
            self.soup = BeautifulSoup(self.source_string, "html5lib")
        except:
            self.soup = BeautifulSoup(self.source_string)

    def _get_styles(self):
        """Gets all CSS content from and removes all <link rel="stylesheet"> and
        <style> tags concatenating into one CSS string which is then parsed with
        cssutils and the resulting CSSStyleSheet object set to
        `self.stylesheet`.
        """
        self._get_external_styles()
        self._get_internal_styles()

        cssparser = cssutils.CSSParser(log=self.log)
        self.stylesheet = cssparser.parseString(self.style_string)

    def _get_external_styles(self):
        """Gets <link> element styles
        """
        if not self.style_string:
            self.style_string = u''
        else:
            self.style_string += u'\n'

        link_tags = self.soup.findAll('link', {'rel': 'stylesheet'})
        for tag in link_tags:
            url = tag['href']
            if url.startswith('http://'):
                pass
            elif url.startswith('/'):
                url = self.root_url + url
            else:
                url = self.relative_url + url
            self.style_string += self._get_url(url)
            tag.extract()

    def _get_internal_styles(self):
        """Gets <style> element styles
        """
        if not self.style_string:
            self.style_string = u''
        else:
            self.style_string += u'\n'

        style_tags = self.soup.findAll('style')
        for tag in style_tags:
            self.style_string += u'\n'.join(tag.contents) + u'\n'
            tag.extract()

    def _get_specificity_from_list(self, lst):
        """
        Takes an array of ints and returns an integer formed
        by adding all ints multiplied by the power of 10 of the current index

        (1, 0, 0, 1) => (1 * 10**3) + (0 * 10**2) + (0 * 10**1) + (1 * 10**0) => 1001
        """
        return int(''.join(map(str, lst)))

    def _get_rule_specificity(self, rule):
        """
        For a given CSSRule get its selector specificity in base 10
        """
        return sum(map(self._get_specificity_from_list, (s.specificity for s in rule.selectorList)))

    def _apply_styles(self):
        """Steps through CSS rules and applies each to all the proper elements
        as @style attributes prepending any current @style attributes.
        """
        rules = self.stylesheet.cssRules.rulesOfType(1)
        elem_prop_map = {}
        elem_style_map = {}

        # build up a property list for every styled element
        for rule in rules:
            # select elements for every selector
            selectors = rule.selectorText.split(',')
            elements = []
            for selector in selectors:
                elements += select(self.soup, selector)
            # build prop_list for each selected element
            for elem in elements:
                if elem not in elem_prop_map:
                    elem_prop_map[elem] = []
                elem_prop_map[elem].append({
                    'specificity': self._get_rule_specificity(rule),
                    'props': rule.style.getProperties(),
                })

        # build up another property list using selector specificity
        for elem, props in elem_prop_map.items():
            if elem not in elem_style_map:
                elem_style_map[elem] = cssutils.css.CSSStyleDeclaration()
            # ascending sort of prop_lists based on specificity
            props = sorted(props, key=lambda p: p['specificity'])
            # for each prop_list, apply to CSSStyleDeclaration
            for prop_list in map(lambda obj: obj['props'], props):
                for prop in prop_list:
                    elem_style_map[elem][prop.name] = prop.value


        # apply rules to elements
        for elem, style_declaration in elem_style_map.items():
            if elem.has_key('style'):
                elem['style'] = u'%s; %s' % (style_declaration.cssText.replace('\n', ' '), elem['style'])
            else:
                elem['style'] = style_declaration.cssText.replace('\n', ' ')

    def _get_output(self):
        """Generate Unicode string of `self.soup` and set it to `self.output`

        Returns self.output
        """
        self.output = unicode(str(self.soup))
        return self.output

def fromURL(url, log=None):
    """Shortcut Pynliner constructor. Equivelent to:

    >>> Pynliner().from_url(someURL).run()

    Returns processed HTML string.
    """
    return Pynliner(log).from_url(url).run()

def fromString(string, log=None):
    """Shortcut Pynliner constructor. Equivelent to:

    >>> Pynliner().from_string(someString).run()

    Returns processed HTML string.
    """
    return Pynliner(log).from_string(string).run()

