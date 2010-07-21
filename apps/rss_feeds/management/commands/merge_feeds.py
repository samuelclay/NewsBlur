from django.core.management.base import BaseCommand
from apps.rss_feeds.models import Feed, Story, Tag, StoryAuthor
from apps.reader.models import UserSubscription, UserStory, UserSubscriptionFolders
from apps.analyzer.models import FeatureCategory, Category, ClassifierTitle
from apps.analyzer.models import ClassifierAuthor, ClassifierFeed, ClassifierTag
from optparse import make_option
from django.db import connection
from django.db.utils import IntegrityError
from utils import json

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", dest="feed", default=None),
        make_option("-V", "--verbose", dest="verbose", action="store_true"),
    )

    def handle(self, *args, **options):
        cursor = connection.cursor()
        cursor.execute("""SELECT DISTINCT f.id AS original_id, f2.id AS duplicate_id, 
                              f.feed_address AS original_feed_address,
                              f2.feed_address AS duplicate_feed_address
                          """
                              # f.feed_title AS original_feed_title,
                              # f2.feed_title AS duplicate_feed_title, 
                              # f.feed_link AS original_feed_link,
                              # f2.feed_link AS duplicate_feed_link, 
                              # f2.feed_tagline AS original_feed_tagline,
                              # f.feed_tagline AS duplicate_feed_tagline 
                          """
                          FROM stories s1
                          INNER JOIN stories s2 ON s1.story_guid_hash = s2.story_guid_hash
                          INNER JOIN feeds f ON f.id = s1.story_feed_id
                          INNER JOIN feeds f2 ON f2.id = s2.story_feed_id
                          WHERE s1.story_feed_id != s2.story_feed_id
                              AND f2.id > f.id
                              AND f.feed_tagline = f2.feed_tagline 
                              AND f.feed_link = f2.feed_link 
                              AND f.feed_title = f2.feed_title;""")
        
        feed_fields = ('original_id', 'duplicate_id', 'original_feed_address', 'duplicate_feed_address')
        for feeds_values in cursor.fetchall():
            feeds = dict(zip(feed_fields, feeds_values))
            original_feed = Feed.objects.get(pk=feeds['original_id'])
            duplicate_feed = Feed.objects.get(pk=feeds['duplicate_id'])
            
            print " ---> Feed: [%s - %s] %s - %s" % (feeds['original_id'], feeds['duplicate_id'],
                                                     original_feed, original_feed.feed_link)
            print "            --> %s" % feeds['original_feed_address']
            print "            --> %s" % feeds['duplicate_feed_address']

            user_subs = UserSubscription.objects.filter(feed=duplicate_feed)
            for user_sub in user_subs:
                # Rewrite feed in subscription folders
                user_sub_folders = UserSubscriptionFolders.objects.get(user=user_sub.user)
                folders = json.decode(user_sub_folders.folders)
                folders = self.rewrite_folders(folders, original_feed, duplicate_feed)
                user_sub_folders.folders = json.encode(folders)
                # user_sub_folders.save()
                
                # Switch to original feed for the user subscription
                print "      ===> %s " % user_sub.user
                user_sub.feed = original_feed
                try:
                    # user_sub.save()
                    pass
                except IntegrityError:
                    print "      !!!!> %s already subscribed" % user_sub.user
                    # user_sub.delete()
            
            # Switch read stories
            user_stories = UserStory.objects.filter(feed=duplicate_feed)
            print " ---> %s read stories" % user_stories.count()
            for user_story in user_stories:
                user_story.feed = original_feed
                duplicate_story = user_story.story
                original_story = Story.objects.filter(story_guid_hash=duplicate_story.story_guid_hash,
                                                      story_feed=original_feed)
                if original_story:
                    user_story.story = original_story[0]
                else:
                    print " ***> Can't find original story: %s" % duplicate_story
                # user_story.save()
            
            def delete_story_feed(model, feed_field='feed'):
                duplicate_stories = model.objects.filter(**{feed_field: duplicate_feed})
                if duplicate_stories.count():
                    print " ---> Deleting %s %s" % (duplicate_stories.count(), model)
                # duplicate_stories.delete()
            def switch_feed(model):
                duplicates = model.objects.filter(feed=duplicate_feed)
                if duplicates.count():
                    print " ---> Switching %s %s" % (duplicates.count(), model)
                for duplicate in duplicates:
                    duplicate.feed = original_feed
                    try:
                        # duplicate.save()
                        pass
                    except IntegrityError:
                        print "      !!!!> %s already exists" % duplicate
                        # duplicates.delete()
            delete_story_feed(Story, 'story_feed')
            delete_story_feed(Tag)
            delete_story_feed(StoryAuthor)
            switch_feed(FeatureCategory)
            switch_feed(Category)
            switch_feed(ClassifierTitle)
            switch_feed(ClassifierAuthor)
            switch_feed(ClassifierFeed)
            switch_feed(ClassifierTag)
            # duplicate_authors.delete()
            # duplicate_feed.delete()
    
    def rewrite_folders(self, folders, original_feed, duplicate_feed):
        new_folders = []
        
        for k, folder in enumerate(folders):
            if isinstance(folder, int):
                if folder == duplicate_feed.pk:
                    print "              ===> Rewrote %s'th item: %s" % (k+1, folders)
                    new_folders.append(original_feed.pk)
                else:
                    new_folders.append(folder)
            elif isinstance(folder, dict):
                for f_k, f_v in folder.items():
                    new_folders.append({f_k: self.rewrite_folders(f_v, original_feed, duplicate_feed)})

        return new_folders
        