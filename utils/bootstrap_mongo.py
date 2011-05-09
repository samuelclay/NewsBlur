from pprint import pprint
from django.conf import settings
from apps.reader.models import MUserStory
from apps.rss_feeds.models import Feed, MStory, MFeedPage
from apps.rss_feeds.models import MFeedIcon, FeedIcon
from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
import mongoengine, pymongo
import sys
from mongoengine.queryset import OperationError
from utils import json_functions as json

MONGO_DB = settings.MONGO_DB
db = mongoengine.connect(MONGO_DB['NAME'], host=MONGO_DB['HOST'], port=MONGO_DB['PORT'])

def bootstrap_stories():
    print "Mongo DB stories: %s" % MStory.objects().count()
    # db.stories.drop()
    print "Dropped! Mongo DB stories: %s" % MStory.objects().count()

    print "Stories: %s" % Story.objects.all().count()
    pprint(db.stories.index_information())

    feeds = Feed.objects.all().order_by('-average_stories_per_month')
    feed_count = feeds.count()
    i = 0
    for feed in feeds:
        i += 1
        print "%s/%s: %s (%s stories)" % (i, feed_count,
                            feed, Story.objects.filter(story_feed=feed).count())
        sys.stdout.flush()
    
        stories = Story.objects.filter(story_feed=feed).values()
        for story in stories:
            # story['story_tags'] = [tag.name for tag in Tag.objects.filter(story=story['id'])]
            try:
                story['story_tags'] = json.decode(story['story_tags'])
            except:
                continue
            del story['id']
            del story['story_author_id']
            try:
                MStory(**story).save()
            except:
                continue

    print "\nMongo DB stories: %s" % MStory.objects().count()

def bootstrap_userstories():
    print "Mongo DB userstories: %s" % MUserStory.objects().count()
    # db.userstories.drop()
    print "Dropped! Mongo DB userstories: %s" % MUserStory.objects().count()

    print "UserStories: %s" % UserStory.objects.all().count()
    pprint(db.userstories.index_information())

    userstories = UserStory.objects.all().values()
    for userstory in userstories:
        try:
            story = Story.objects.get(pk=userstory['story_id'])
        except Story.DoesNotExist:
            continue
        try:
            userstory['story'] = MStory.objects(story_feed_id=story.story_feed.pk, story_guid=story.story_guid)[0]
        except:
            print '!',
            continue
        print '.',
        del userstory['id']
        del userstory['opinion']
        del userstory['story_id']
        try:
            MUserStory(**userstory).save()
        except:
            print '\n\n!\n\n'
            continue

    print "\nMongo DB userstories: %s" % MUserStory.objects().count()

def bootstrap_classifiers():
    for sql_classifier, mongo_classifier in ((ClassifierTitle, MClassifierTitle), 
                                             (ClassifierAuthor, MClassifierAuthor), 
                                             (ClassifierFeed, MClassifierFeed),
                                             (ClassifierTag, MClassifierTag)):
        collection = mongo_classifier.meta['collection']
        print "Mongo DB classifiers: %s - %s" % (collection, mongo_classifier.objects().count())
        # db[collection].drop()
        print "Dropped! Mongo DB classifiers: %s - %s" % (collection, mongo_classifier.objects().count())

        print "%s: %s" % (sql_classifier._meta.object_name, sql_classifier.objects.all().count())
        pprint(db[collection].index_information())
        
        for userclassifier in sql_classifier.objects.all().values():
            del userclassifier['id']
            if sql_classifier._meta.object_name == 'ClassifierAuthor':
                author = StoryAuthor.objects.get(pk=userclassifier['author_id'])
                userclassifier['author'] = author.author_name
                del userclassifier['author_id']
            if sql_classifier._meta.object_name == 'ClassifierTag':
                tag = Tag.objects.get(pk=userclassifier['tag_id'])
                userclassifier['tag'] = tag.name
                del userclassifier['tag_id']
            print '.',
            try:
                mongo_classifier(**userclassifier).save()
            except:
                print '\n\n!\n\n'
                continue
            
        print "\nMongo DB classifiers: %s - %s" % (collection, mongo_classifier.objects().count())
    
def bootstrap_feedpages():
    print "Mongo DB feed_pages: %s" % MFeedPage.objects().count()
    # db.feed_pages.drop()
    print "Dropped! Mongo DB feed_pages: %s" % MFeedPage.objects().count()

    print "FeedPages: %s" % FeedPage.objects.count()
    pprint(db.feed_pages.index_information())

    feeds = Feed.objects.all().order_by('-average_stories_per_month')
    feed_count = feeds.count()
    i = 0
    for feed in feeds:
        i += 1
        print "%s/%s: %s" % (i, feed_count, feed,)
        sys.stdout.flush()
        
        if not MFeedPage.objects(feed_id=feed.pk):
            feed_page = FeedPage.objects.filter(feed=feed).values()
            if feed_page:
                del feed_page[0]['id']
                feed_page[0]['feed_id'] = feed.pk
                try:
                    MFeedPage(**feed_page[0]).save()
                except:
                    print '\n\n!\n\n'
                    continue
        

    print "\nMongo DB feed_pages: %s" % MFeedPage.objects().count()

def bootstrap_feedicons():
    print "Mongo DB feed_icons: %s" % MFeedIcon.objects().count()
    db.feed_icons.drop()
    print "Dropped! Mongo DB feed_icons: %s" % MFeedIcon.objects().count()

    print "FeedIcons: %s" % FeedIcon.objects.count()
    pprint(db.feed_icons.index_information())

    feeds = Feed.objects.all().order_by('-average_stories_per_month')
    feed_count = feeds.count()
    i = 0
    for feed in feeds:
        i += 1
        print "%s/%s: %s" % (i, feed_count, feed,)
        sys.stdout.flush()
        
        if not MFeedIcon.objects(feed_id=feed.pk):
            feed_icon = FeedIcon.objects.filter(feed=feed).values()
            if feed_icon:
                try:
                    MFeedIcon(**feed_icon[0]).save()
                except:
                    print '\n\n!\n\n'
                    continue
        

    print "\nMongo DB feed_icons: %s" % MFeedIcon.objects().count()

def compress_stories():
    count = MStory.objects().count()
    print "Mongo DB stories: %s" % count
    p = 0.0
    i = 0

    feeds = Feed.objects.all().order_by('-average_stories_per_month')
    feed_count = feeds.count()
    f = 0
    for feed in feeds:
        f += 1
        print "%s/%s: %s" % (f, feed_count, feed,)
        sys.stdout.flush()
    
        for story in MStory.objects(story_feed_id=feed.pk):
            i += 1.0
            if round(i / count * 100) != p:
                p = round(i / count * 100)
                print '%s%%' % p
            story.save()
        
def reindex_stories():
    db = pymongo.Connection().newsblur
    count = MStory.objects().count()
    print "Mongo DB stories: %s" % count
    p = 0.0
    i = 0

    feeds = Feed.objects.all().order_by('-average_stories_per_month')
    feed_count = feeds.count()
    f = 0
    for feed in feeds:
        f += 1
        print "%s/%s: %s" % (f, feed_count, feed,)
        sys.stdout.flush()
        for story in MStory.objects(story_feed_id=feed.pk):
            i += 1.0
            if round(i / count * 100) != p:
                p = round(i / count * 100)
                print '%s%%' % p
            if isinstance(story.id, unicode):
                story.story_guid = story.id
                story.id = pymongo.objectid.ObjectId()
                try:
                    story.save()
                except OperationError, e:
                    print " ***> OperationError: %s" % e
                except e:
                    print ' ***> Unknown Error: %s' % e
                db.stories.remove({"_id": story.story_guid})
    
if __name__ == '__main__':
    # bootstrap_stories()
    # bootstrap_userstories()
    # bootstrap_classifiers()
    # bootstrap_feedpages()
    # compress_stories()
    # reindex_stories()
    bootstrap_feedicons()