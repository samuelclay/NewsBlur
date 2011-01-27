from django.core.management.base import BaseCommand
from apps.rss_feeds.models import merge_feeds, MStory
from optparse import make_option
from django.db import connection

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", dest="feed", default=None),
        make_option("-V", "--verbose", dest="verbose", action="store_true"),
    )

    def handle(self, *args, **options):
        cursor = connection.cursor()
        cursor.execute("""SELECT DISTINCT f.id AS original_id, f2.id AS duplicate_id, 
                              f.feed_address AS original_feed_address,
                              f2.feed_address AS duplicate_feed_address,
                              f.feed_title AS original_feed_title,
                              f2.feed_title AS duplicate_feed_title, 
                              f.feed_link AS original_feed_link,
                              f2.feed_link AS duplicate_feed_link, 
                              fd2.feed_tagline AS original_feed_tagline,
                              fd.feed_tagline AS duplicate_feed_tagline 
                          FROM feeds f, feeds f2
                          INNER JOIN rss_feeds_feeddata fd ON fd.feed_id = f.feed_id
                          INNER JOIN rss_feeds_feeddata fd2 ON fd2.feed_id = f2.feed_id
                          WHERE f2.id > f.id
                              AND fd.feed_tagline = fd2.feed_tagline 
                              AND f.feed_link = f2.feed_link 
                              AND f.feed_title = f2.feed_title
                          ORDER BY original_id ASC;""")

        feed_fields = ('original_id', 'duplicate_id', 'original_feed_address', 'duplicate_feed_address')
        skips = 0
        merges = 0
        for feeds_values in cursor.fetchall():
            feeds = dict(zip(feed_fields, feeds_values))
            duplicate_stories = MStory.objects(story_feed_id=feeds['duplicate_id']).only('story_guid')[5:8]
            duplicate_story_ids = [story.story_guid for story in duplicate_stories]
            original_stories = MStory.objects(story_feed_id=feeds['original_id'], story_guid__in=duplicate_story_ids)
            if duplicate_stories.count() == original_stories.count():
                merges += 1
                merge_feeds(feeds['original_id'], feeds['duplicate_id'])
            else:
                # print duplicate_stories
                # print duplicate_story_ids
                # print original_stories
                # print "Skipping: %s" % feeds
                skips += 1

        print "Skips: %s, Merges: %s" % (skips, merges)