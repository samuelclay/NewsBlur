import datetime
import mongoengine as mongo
from utils import log as logging
from django.db import models
from django.contrib.auth.models import User
from django.core.cache import cache
from apps.rss_feeds.models import Feed, Story, MStory
from apps.analyzer.models import MClassifierFeed, MClassifierAuthor, MClassifierTag, MClassifierTitle
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds, apply_classifier_authors, apply_classifier_tags

DAYS_OF_UNREAD = 14
MONTH_AGO = datetime.datetime.now() - datetime.timedelta(days=30)

class UserSubscription(models.Model):
    """
    A feed which a user has subscrubed to. Carries all of the cached information
    about the subscription, including unread counts of the three primary scores.
    
    Also has a dirty flag (needs_unread_recalc) which means that the unread counts
    are not accurate and need to be calculated with `self.calculate_feed_scores()`.
    """
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
    needs_unread_recalc = models.BooleanField(default=False)
    feed_opens = models.IntegerField(default=0)
    is_trained = models.BooleanField(default=False)

    def __unicode__(self):
        return '[' + self.feed.feed_title + '] '

    def save(self, force_insert=False, force_update=False, *args, **kwargs):
        self.unread_count_updated = datetime.datetime.now()
        super(UserSubscription, self).save(force_insert, force_update, *args, **kwargs)
        
    def mark_feed_read(self):
        now = datetime.datetime.now()
        if MStory.objects(story_feed_id=self.feed.pk).first():
            latest_story_date = MStory.objects(story_feed_id=self.feed.pk).order_by('-story_date')[0].story_date\
                                + datetime.timedelta(minutes=1)
        else:
            latest_story_date = now
        self.last_read_date = max(now, latest_story_date)
        self.mark_read_date = max(now, latest_story_date)
        self.unread_count_negative = 0
        self.unread_count_positive = 0
        self.unread_count_neutral = 0
        self.unread_count_updated = max(now, latest_story_date)
        self.needs_unread_relcalc = False
        self.save()
    
    def calculate_feed_scores(self, silent=False):
        if self.user.profile.last_seen_on < MONTH_AGO:
            if not silent:
                logging.info(' ---> [%s] SKIPPING Computing scores: %s (1 month+)' % (self.user, self.feed))
            return
        
        if not self.feed.fetched_once:
            if not silent:
                logging.info(' ---> [%s] NOT Computing scores: %s' % (self.user, self.feed))
            self.needs_unread_recalc = False
            self.save()
            return

        if not silent:
            logging.info(' ---> [%s] Computing scores: %s' % (self.user, self.feed))
        feed_scores = dict(negative=0, neutral=0, positive=0)
        
        # Two weeks in age. If mark_read_date is older, mark old stories as read.
        date_delta = datetime.datetime.now()-datetime.timedelta(days=DAYS_OF_UNREAD)
        if date_delta < self.mark_read_date:
            date_delta = self.mark_read_date
        else:
            self.mark_read_date = date_delta
            
        read_stories = MUserStory.objects(user_id=self.user.pk,
                                          feed_id=self.feed.pk)
        read_stories_ids = [rs.story.id for rs in read_stories]
        from django.db import connection
        connection.queries = []
        stories_db = MStory.objects(story_feed_id=self.feed.pk,
                                    story_date__gte=date_delta)
        stories_db = [story for story in stories_db if story.id not in read_stories_ids]
        stories = self.feed.format_stories(stories_db)
        
        classifier_feeds = MClassifierFeed.objects(user_id=self.user.pk, feed_id=self.feed.pk)
        classifier_authors = MClassifierAuthor.objects(user_id=self.user.pk, feed_id=self.feed.pk)
        classifier_titles = MClassifierTitle.objects(user_id=self.user.pk, feed_id=self.feed.pk)
        classifier_tags = MClassifierTag.objects(user_id=self.user.pk, feed_id=self.feed.pk)
        
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
        
        self.unread_count_positive = feed_scores['positive']
        self.unread_count_neutral = feed_scores['neutral']
        self.unread_count_negative = feed_scores['negative']
        self.needs_unread_recalc = False
        
        self.save()
        
        if (self.unread_count_positive == 0 and 
            self.unread_count_neutral == 0):
            self.mark_feed_read()
        
        cache.delete('usersub:%s' % self.user.id)
        
        return
        
    class Meta:
        unique_together = ("user", "feed")
        
        
class UserStory(models.Model):
    """
    Stories read by the user. These are deleted as the mark_read_date for the
    UserSubscription passes the UserStory date.
    """
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
        
        
class MUserStory(mongo.Document):
    """
    Stories read by the user. These are deleted as the mark_read_date for the
    UserSubscription passes the UserStory date.
    """
    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    read_date = mongo.DateTimeField()
    story = mongo.ReferenceField(MStory, unique_with=('user_id', 'feed_id'))
    
    meta = {
        'collection': 'userstories',
        'indexes': [('user_id', 'feed_id')],
        'allow_inheritance': False,
    }
    
        
class UserSubscriptionFolders(models.Model):
    """
    A JSON list of folders and feeds for while a user has subscribed. The list
    is a recursive descent of feeds and folders in folders. Used to layout
    the feeds and folders in the Reader's feed navigation pane.
    """
    user = models.ForeignKey(User)
    folders = models.TextField(default="[]")
    
    def __unicode__(self):
        return "[%s]: %s" % (self.user, len(self.folders),)
        
    class Meta:
        verbose_name_plural = "folders"
        verbose_name = "folder"


class Feature(models.Model):
    """
    Simple blog-like feature board shown to all users on the home page.
    """
    description = models.TextField(default="")
    date = models.DateTimeField(default=datetime.datetime.now)
    
    def __unicode__(self):
        return "[%s] %s" % (self.date, self.description[:50])
    
    class Meta:
        ordering = ["-date"]
        