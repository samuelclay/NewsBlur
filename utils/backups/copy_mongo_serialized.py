# Use this script to copy the contents of MongoDB from one server 
# to another using only pymongo. This circumvents the mongod --repair
# option, which can fucking fail.

import sys
import pymongo

db01 = pymongo.Connection('db01:27018')
db02 = pymongo.Connection('db02:27018')
story_feed_id = 5799
total = db01.newsblur.stories.count()
stories = db01.newsblur.stories.find({'story_feed_id': {'$gte': story_feed_id}}, sort=[('story_feed_id', pymongo.ASCENDING), ('story_date', pymongo.DESCENDING)])
i = 0
for story in stories:
    if story.get('story_feed_id', 0) != story_feed_id:
        story_feed_id = story['story_feed_id']
        print " ---> Inserted %s stories (%s%%)" % (
            i, round(i/float(total), 2)
        )
        print " ---> At feed_id: %s" % story_feed_id
        sys.stdout.flush()
    db02.newsblur.stories.insert(story)
    i += 1
