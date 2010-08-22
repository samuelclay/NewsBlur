from pprint import pprint
from django.conf import settings
from apps.reader.models import MUserStory, UserStory
from apps.rss_feeds.models import Feed, Story, MStory, StoryAuthor
import mongoengine
import sys
from utils import json

MONGO_DB = settings.MONGO_DB
db = mongoengine.connect(MONGO_DB['NAME'], host=MONGO_DB['HOST'], port=MONGO_DB['PORT'])

def bootstrap_stories():
    print "Mongo DB stories: %s" % MStory.objects().count()

    db.stories.drop()
    print "Dropped! Mongo DB stories: %s" % MStory.objects().count()


    print "Stories: %s" % Story.objects.all().count()

    pprint(db.stories.index_information())

    feeds = Feed.objects.all().order_by('-average_stories_per_month')
    for feed in feeds:
        print "%-5s: %s" % (Story.objects.select_related('story_author', 'tags').filter(story_feed=feed).count(),
                            feed)
        sys.stdout.flush()
    
        stories = Story.objects.filter(story_feed=feed).values()
        for story in stories:
            # story['story_tags'] = [tag.name for tag in Tag.objects.filter(story=story['id'])]
            story['story_tags'] = json.decode(story['story_tags'])
            del story['id']
            del story['story_author_id']
            MStory(**story).save()

    print "Mongo DB stories: %s" % MStory.objects().count()

def bootstrap_userstories():
    print "Mongo DB userstories: %s" % MUserStory.objects().count()

    db.userstories.drop()
    print "Dropped! Mongo DB userstories: %s" % MUserStory.objects().count()


    print "UserStories: %s" % UserStory.objects.all().count()

    pprint(db.userstories.index_information())

    userstories = UserStory.objects.all().values()
    for userstory in userstories:
        try:
            story = Story.objects.get(pk=userstory['story_id'])
        except Story.DoesNotExist:
            continue
        userstory['story'] = MStory.objects(story_feed_id=story.story_feed.pk, story_guid=story.story_guid)[0]
        print '.',
        del userstory['id']
        del userstory['opinion']
        del userstory['story_id']
        MUserStory(**userstory).save()

    print "\nMongo DB userstories: %s" % MUserStory.objects().count()

if __name__ == '__main__':
    # bootstrap_stories()
    bootstrap_userstories()