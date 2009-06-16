# Originally adapted from IanLewis / dlife

from django.shortcuts import get_list_or_404
from apps.rss_feeds.models import Feed, Story
from utils import feedparser
from utils.dateutil.parser import parse as dateutil_parse
from django.utils.http import urlquote
from django.db.models import Q

import time

class FeedInjest(object):
    
    feed = None
    
    def __init__(self, feed):
        self.feed = feed
        
    def update(self):
        stories = []
        feed_items = feedparser.parse(self.feed.feed_address)
        for entry in feed_items['entries']:
            stories.append(entry)
        self.feed.feed_last_update = time.time()
        self.feed.save()
        return stories

    def save_story(self, story):
        story_contents = story.get('content')
        if story_contents is not None:
            story_contents = story_contents[0]['value']
        else:
            story_contents = story.get('summary')
        print 'Story: ', story_contents
        if story_contents is not None:
            story_content = story_contents
        else:
            story_content = None
    
        s = Story(story_feed = self.feed,
               story_date = story.get('published'),
               story_title = story.get('title'),
               story_content = story_content,
               story_author = story.get('author'),
               story_permalink = story.get('link')
        )
        s.save()
        
    def include_story(self, entry):
        story_count = Story.objects.filter(
            Q(story_date = entry['published']) | Q(story_permalink = entry['link'])
        ).filter(
            story_feed = self.feed
        ).count()
        
        return story_count == 0
        
    def pre_process(self, entry):
        '''
        A hook is used to clean up feed entry data before it is processed.
        This hook can be used to clean up dates and/or media data
        before being processed.
        '''
        date_published = entry.get('published', entry.get('updated'))
        if not date_published:
            date_published = str(datetime.datetime.utcnow())
        date_published = dateutil_parse(date_published)
        # Change the date to UTC and remove timezone info since MySQL doesn't
        # support it.
        date_published = (date_published - date_published.utcoffset()).replace(tzinfo=None)

        entry['published'] = date_published

        protocol_index = entry['link'].find("://")
        if protocol_index != -1:
            entry['link'] = entry['link'][:protocol_index+3] + urlquote(entry['link'][protocol_index+3:])
        else:
            entry['link'] = urlquote(entry['link'])