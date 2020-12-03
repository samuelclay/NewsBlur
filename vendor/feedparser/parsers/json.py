# The JSON feed parser
# Copyright 2017 Beat Bolli
# All rights reserved.
#
# This file is a part of feedparser.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 'AS IS'
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

import json

from ..datetimes import _parse_date
from ..sanitizer import _sanitize_html
from ..util import FeedParserDict


class _JsonFeedParser(object):
    VERSIONS = {
        'https://jsonfeed.org/version/1': 'json1',
        'https://jsonfeed.org/version/1.1': 'json11',
    }
    FEED_FIELDS = (
        ('title', 'title'),
        ('icon', 'image'),
        ('home_page_url', 'link'),
        ('description', 'description'),
    )
    ITEM_FIELDS = (
        ('title', 'title'),
        ('id', 'guid'),
        ('url', 'link'),
        ('summary', 'summary'),
        ('external_url', 'source'),
    )

    def __init__(self, baseuri=None, baselang=None, encoding=None):
        self.baseuri = baseuri or ''
        self.lang = baselang or None
        self.encoding = encoding or 'utf-8' # character encoding

        self.version = None
        self.feeddata = FeedParserDict()
        self.namespacesInUse = []

    def feed(self, data):
        data = json.loads(data)

        v = data.get('version', '')
        try:
            self.version = self.VERSIONS[v]
        except KeyError:
            raise ValueError("Unrecognized JSONFeed version '%s'" % v)

        for src, dst in self.FEED_FIELDS:
            if src in data:
                self.feeddata[dst] = data[src]
        if 'author' in data:
            self.parse_author(data['author'], self.feeddata)
        # TODO: hubs; expired has no RSS equivalent

        self.entries = [self.parse_entry(e) for e in data['items']]

    def parse_entry(self, e):
        entry = FeedParserDict()
        for src, dst in self.ITEM_FIELDS:
            if src in e:
                entry[dst] = e[src]

        if 'content_text' in e:
            entry['content'] = c = FeedParserDict()
            c['value'] = e['content_text']
            c['type'] = 'text'
        elif 'content_html' in e:
            entry['content'] = c = FeedParserDict()
            c['value'] = _sanitize_html(e['content_html'],
                self.encoding, 'application/json')
            c['type'] = 'html'

        if 'date_published' in e:
            entry['published'] = e['date_published']
            entry['published_parsed'] = _parse_date(e['date_published'])
        if 'date_updated' in e:
            entry['updated'] = e['date_modified']
            entry['updated_parsed'] = _parse_date(e['date_modified'])

        if 'tags' in e:
            entry['category'] = e['tags']

        if 'author' in e:
            self.parse_author(e['author'], entry)

        if 'attachments' in e:
            entry['enclosures'] = [self.parse_attachment(a) for a in e['attachments']]

        return entry

    def parse_author(self, parent, dest):
        dest['author_detail'] = detail = FeedParserDict()
        if 'name' in parent:
            dest['author'] = detail['name'] = parent['name']
        if 'url' in parent:
            if parent['url'].startswith('mailto:'):
                detail['email'] = parent['url'][7:]
            else:
                detail['href'] = parent['url']

    def parse_attachment(self, attachment):
        enc = FeedParserDict()
        enc['href'] = attachment['url']
        enc['type'] = attachment['mime_type']
        if 'size_in_bytes' in attachment:
            enc['length'] = attachment['size_in_bytes']
        return enc
