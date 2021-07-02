import time
import pymongo
from django.conf import settings
from apps.rss_feeds.models import MStory, Feed

db = settings.MONGODB
batch = 0
start = 0
for f in range(start, Feed.objects.latest('pk').pk):
    if f < batch*100000: continue
    start = time.time()
    try:
        cp1 = time.time() - start
        # if feed.active_premium_subscribers < 1: continue
        stories = MStory.objects.filter(story_feed_id=f, story_hash__exists=False)\
                                .only('id', 'story_feed_id', 'story_guid')\
                                .read_preference(pymongo.ReadPreference.SECONDARY)
        cp2 = time.time() - start
        count = 0
        for story in stories:
            count += 1
            db.newsblur.stories.update({"_id": story.id}, {"$set": {
                "story_hash": story.feed_guid_hash
            }})
        cp3 = time.time() - start
        print(("%s: %3s stories (%s/%s/%s)" % (f, count, round(cp1, 2), round(cp2, 2), round(cp3, 2))))
    except Exception as e:
        print((" ***> (%s) %s" % (f, e)))

