from django.db import models
from django.contrib.auth.models import User
import datetime
import random
from django.core.cache import cache
from apps.rss_feeds.models import Feed, Story, Tag
from utils import feedparser, object_manager, json
from apps.analyzer.models import ClassifierFeed, ClassifierAuthor, ClassifierTag, ClassifierTitle
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds, apply_classifier_authors, apply_classifier_tags

DAYS_OF_UNREAD = 14

class UserSubscription(models.Model):
    user = models.ForeignKey(User)
    feed = models.ForeignKey(Feed)
    last_read_date = models.DateTimeField(default=datetime.datetime.now()
                                                  - datetime.timedelta(days=DAYS_OF_UNREAD))
    mark_read_date = models.DateTimeField(default=datetime.datetime.now()
                                                 - datetime.timedelta(days=DAYS_OF_UNREAD))
    unread_count_neutral = models.IntegerField(default=0)
    unread_count_positive = models.IntegerField(default=0)
    unread_count_negative = models.IntegerField(default=0)
    unread_count_updated = models.DateTimeField(default=datetime.datetime(2000,1,1))

    def __unicode__(self):
        return '[' + self.feed.feed_title + '] '

    def save(self, force_insert=False, force_update=False, *args, **kwargs):
        self.unread_count_updated = datetime.datetime.now()
        super(UserSubscription, self).save(force_insert, force_update, *args, **kwargs)
        
    def get_user_feeds(self):
        return Feed.objects.get(user=self.user, feed=feeds)
        
    def mark_read(self):
        self.last_read_date = datetime.datetime.now()
        self.unread_count -= 1
        self.unread_count_updated = datetime.datetime.now()
        self.save()
        
    def mark_feed_read(self):
        self.last_read_date = datetime.datetime.now()
        self.mark_read_date = datetime.datetime.now()
        self.unread_count = 0
        self.unread_count_updated = datetime.datetime.now()
        self.save()
        # readstories = ReadStories.objects.filter(user=self.user, feed=self.feed)
        # readstories.delete()
        
    def stories_newer_lastread(self):
        return self.feed.new_stories_since_date(self.last_read_date).count()
        
    def stories_between_lastread_allread(self):
        story_count =   Story.objects.filter(
                            story_date__gte=self.mark_read_date,
                            story_date__lte=self.last_read_date,
                            story_feed=self.feed
                        ).count()
        read_count =    UserStory.objects.filter(
                            feed=self.feed, 
                            read_date__gte=self.mark_read_date,
                            read_date__lte=self.last_read_date
                        ).count()
        return story_count - read_count
        
    def subscribe_to_feed(self, feed_id):
        feed = Feed.objects.get(id=feed_id)
        new_subscription = UserSubscription(user=self.user, feed=feed)
        new_subscription.save()
    
    def calculate_feed_scores(self):
        print '[%s]: %s' % (self.feed, self.user)
        feed_scores = dict(negative=0, neutral=0, positive=0)
        
        # Two weeks in age. If mark_read_date is older, mark old stories as read.
        date_delta = datetime.datetime.now()-datetime.timedelta(days=DAYS_OF_UNREAD)
        if date_delta < self.mark_read_date:
            date_delta = self.mark_read_date
        else:
            self.mark_read_date = date_delta
            
        read_stories = UserStory.objects.filter(user=self.user,
                                                feed=self.feed,
                                                story__story_date__gte=date_delta)
        read_stories_ids = [rs.story.id for rs in read_stories]
        # print "Read Stories IDs: %s" % read_stories_ids
        # print "Date delta: %s" % date_delta
        from django.db import connection
        connection.queries = []
        stories_db = Story.objects.select_related('story_author')\
                                  .exclude(id__in=read_stories_ids)\
                                  .filter(story_feed=self.feed,
                                          story_date__gte=date_delta)
        # print "Stories_db: %s" % stories_db.count()
        stories = self.feed.format_stories(stories_db)
        # print '  Stories: %s\t' % stories_db.count(),
        # if read_stories.count(): print '(%s read)' % (read_stories.count())
        # else: print ''
        classifier_feeds = ClassifierFeed.objects.filter(user=self.user, feed=self.feed)
        classifier_authors = ClassifierAuthor.objects.filter(user=self.user, feed=self.feed)
        classifier_titles = ClassifierTitle.objects.filter(user=self.user, feed=self.feed)
        classifier_tags = ClassifierTag.objects.filter(user=self.user, feed=self.feed)
        
        scores = {
            'feed': apply_classifier_feeds(classifier_feeds, self.feed),
        }
        
        for story in stories:
            scores.update({
                'author': apply_classifier_authors(classifier_authors, story),
                'tags': apply_classifier_tags(classifier_tags, story),
                'title': apply_classifier_titles(classifier_titles, story),
            })
            
            max_score = max(scores['feed'], scores['author'], scores['tags'], scores['title'])
            min_score = min(scores['feed'], scores['author'], scores['tags'], scores['title'])
            if max_score > 0:
                feed_scores['positive'] += 1
            if min_score < 0:
                feed_scores['negative'] += 1
            if max_score == 0 and min_score == 0:
                feed_scores['neutral'] += 1
        
        # print '  Feed scores: %s' % feed_scores
        self.unread_count_positive = feed_scores['positive']
        self.unread_count_neutral = feed_scores['neutral']
        self.unread_count_negative = feed_scores['negative']
        
        self.save()
        
        cache.delete('usersub:%s' % self.user.id)
        
        return
        
    def get_scores(self):
        scores = json.decode(self.scores)
        return scores
        
    class Meta:
        unique_together = ("user", "feed")
        
        
class UserStory(models.Model):
    user = models.ForeignKey(User)
    feed = models.ForeignKey(Feed)
    story = models.ForeignKey(Story)
    read_date = models.DateTimeField(auto_now=True)
    opinion = models.IntegerField(default=0)
    
    def __unicode__(self):
        return ('[' + self.feed.feed_title + '] '
                + self.story.story_title)
        
    class Meta:
        verbose_name_plural = "user stories"
        verbose_name = "user story"
        unique_together = ("user", "feed", "story")
        
class UserSubscriptionFolders(models.Model):
    user = models.ForeignKey(User)
    folders = models.TextField(default="{}")
    
    def __unicode__(self):
        return "[%s]: %s" % (self.user, len(self.folders),)
        
    class Meta:
        verbose_name_plural = "folders"
        verbose_name = "folder"