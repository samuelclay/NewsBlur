import datetime
import dateutil.parser
from django.conf import settings
from django.utils import feedgenerator
from utils import log as logging
from utils.json_functions import decode

class JSONFetcher:
    
    def __init__(self, feed, options=None):
        self.feed = feed
        self.options = options or {}
    
    def fetch(self, address, raw_feed):
        if not address:
            address = self.feed.feed_address
        
        json_feed = decode(raw_feed.content)
        if not json_feed:
            logging.debug('   ***> [%-30s] ~FRJSON fetch failed: %s' % 
                          (self.feed.log_title[:30], address))
            return

        data = {}
        data['title'] = json_feed.get('title', '[Untitled]')
        data['link'] = json_feed.get('home_page_url', "")
        data['description'] = json_feed.get('title', "")
        data['lastBuildDate'] = datetime.datetime.utcnow()
        data['generator'] = 'NewsBlur JSON Feed - %s' % settings.NEWSBLUR_URL
        data['docs'] = None
        data['feed_url'] = json_feed.get('feed_url')
        
        rss = feedgenerator.Atom1Feed(**data)

        for item in json_feed.get('items', []):
            story_data = self.json_feed_story(item)
            rss.add_item(**story_data)
        
        return rss.writeString('utf-8')
    
    def json_feed_story(self, item):
        date_published = datetime.datetime.now()
        pubdate = item.get('date_published', None)
        if pubdate:
            date_published = dateutil.parser.parse(pubdate)
        authors = item.get('authors', item.get('author', {}))
        if isinstance(authors, list):
            author_name = ', '.join([author.get('name', "") for author in authors])
        else:
            author_name = authors.get('name', "")
        story = {
            'title': item.get('title', ""),
            'link': item.get('external_url', item.get('url', "")),
            'description': item.get('content_html', item.get('content_text', "")),
            'author_name': author_name,
            'categories': item.get('tags', []),
            'unique_id': str(item.get('id', item.get('url', ""))),
            'pubdate': date_published,
        }
        
        return story
