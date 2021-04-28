# Use this script to copy the contents of MongoDB from one server 
# to another using only pymongo. This circumvents the mongod --repair
# option, which can fail.

import sys
import pymongo
import datetime
from apps.rss_feeds.models import Feed

collections = [
    "classifier_author",
    "classifier_feed",
    "classifier_tag",
    "classifier_title",
    "feed_icons",
    "feed_pages",
    "feedback",
    "starred_stories",
    "statistics",
    "userstories",
    # "stories",
    # "feed_fetch_history",
    # "page_fetch_history",
]

db01 = pymongo.Connection('db01:27018')
db02 = pymongo.Connection('db02:27018')
db03 = pymongo.Connection('db03:27017')

for collection in collections:
    i = 0
    latest_item_id = 0
    total = db03.newsblur[collection].count()
    items = db03.newsblur[collection].find(sort=[('_id', pymongo.ASCENDING)])
    for item in items:
        if item.get('_id') != latest_item_id:
            latest_item_id = item['_id']
            print(" ---> Inserted %s items in %s (at: %s) (%2s%%)" % (
                i, collection, item['_id'], (round(i/float(total), 4)*100)
            ))
            sys.stdout.flush()
        db02.newsblur[collection].insert(item)
        i += 1


# Stories
feeds = Feed.objects.all().only('id', 'average_stories_per_month').order_by('-average_stories_per_month')
feed_count = feeds.count()
total_inserted = 0
for f, feed in enumerate(feeds):
    feed_inserted = 0
    latest_feed_id = feed.id
    latest_story_date = datetime.datetime(2011, 12, 18, 18, 50, 59, 614000)
    items = db03.newsblur.stories.find({'story_feed_id': feed.id, 'story_date': {'$gte': latest_story_date}})
    for item in items:
        db02.newsblur.stories.insert(item)
        total_inserted += 1
        feed_inserted += 1
    if feed_inserted:
        print(" ---> Inserted %s items (total: %s) in stories (at: %s -- %s/month) (%2s%%)" % (
            feed_inserted, total_inserted, latest_feed_id, feed.average_stories_per_month, (round(f/float(feed_count), 4)*100)
        ))
        sys.stdout.flush()
