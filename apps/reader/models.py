import datetime
import mongoengine as mongo
from utils import log as logging
from utils import json_functions as json
from django.db import models, IntegrityError
from django.conf import settings
from django.contrib.auth.models import User
from django.core.cache import cache
from apps.reader.managers import UserSubscriptionManager
from apps.rss_feeds.models import Feed, MStory, DuplicateFeed
from apps.analyzer.models import MClassifierFeed, MClassifierAuthor, MClassifierTag, MClassifierTitle
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds, apply_classifier_authors, apply_classifier_tags
from utils.feed_functions import add_object_to_folder

class UserSubscription(models.Model):
    """
    A feed which a user has subscrubed to. Carries all of the cached information
    about the subscription, including unread counts of the three primary scores.
    
    Also has a dirty flag (needs_unread_recalc) which means that the unread counts
    are not accurate and need to be calculated with `self.calculate_feed_scores()`.
    """
    UNREAD_CUTOFF = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
    
    user = models.ForeignKey(User, related_name='subscriptions')
    feed = models.ForeignKey(Feed, related_name='subscribers')
    user_title = models.CharField(max_length=255, null=True, blank=True)
    active = models.BooleanField(default=False)
    last_read_date = models.DateTimeField(default=UNREAD_CUTOFF)
    mark_read_date = models.DateTimeField(default=UNREAD_CUTOFF)
    unread_count_neutral = models.IntegerField(default=0)
    unread_count_positive = models.IntegerField(default=0)
    unread_count_negative = models.IntegerField(default=0)
    unread_count_updated = models.DateTimeField(default=datetime.datetime.now)
    oldest_unread_story_date = models.DateTimeField(default=datetime.datetime.now)
    needs_unread_recalc = models.BooleanField(default=False)
    feed_opens = models.IntegerField(default=0)
    is_trained = models.BooleanField(default=False)
    
    objects = UserSubscriptionManager()

    def __unicode__(self):
        return '[' + self.feed.feed_title + '] '
    
    def canonical(self, full=False, include_favicon=True):
        feed               = self.feed.canonical(full=full, include_favicon=include_favicon)
        feed['feed_title'] = self.user_title or feed['feed_title']
        feed['ps']         = self.unread_count_positive
        feed['nt']         = self.unread_count_neutral
        feed['ng']         = self.unread_count_negative
        feed['active']     = self.active
        feed['feed_opens'] = self.feed_opens
        if not self.active and self.user.profile.is_premium:
            feed['active'] = True
            self.active = True
            self.save()

        return feed
            
    def save(self, *args, **kwargs):
        if not self.active and self.user.profile.is_premium:
            self.active = True
        try:
            super(UserSubscription, self).save(*args, **kwargs)
        except IntegrityError:
            duplicate_feed = DuplicateFeed.objects.filter(duplicate_feed_id=self.feed.pk)
            if duplicate_feed:
                self.feed = duplicate_feed[0].feed
                super(UserSubscription, self).save(*args, **kwargs)
                
    @classmethod
    def add_subscription(cls, user, feed_address, folder=None, bookmarklet=False):
        feed = None
        us = None
    
        logging.user(user, "~FRAdding URL: ~SB%s (in %s)" % (feed_address, folder))
    
        feed = Feed.get_feed_from_url(feed_address)

        if not feed:    
            code = -1
            if bookmarklet:
                message = "This site does not have an RSS feed. Nothing is linked to from this page."
            else:
                message = "This address does not point to an RSS feed or a website with an RSS feed."
        else:
            us, subscription_created = cls.objects.get_or_create(
                feed=feed, 
                user=user,
                defaults={
                    'needs_unread_recalc': True,
                    'active': True,
                }
            )
            code = 1
            message = ""
    
        if us:
            user_sub_folders_object, created = UserSubscriptionFolders.objects.get_or_create(
                user=user,
                defaults={'folders': '[]'}
            )
            if created:
                user_sub_folders = []
            else:
                user_sub_folders = json.decode(user_sub_folders_object.folders)
            user_sub_folders = add_object_to_folder(feed.pk, folder, user_sub_folders)
            user_sub_folders_object.folders = json.encode(user_sub_folders)
            user_sub_folders_object.save()
        
            feed.setup_feed_for_premium_subscribers()
        
            if feed.last_update < datetime.datetime.utcnow() - datetime.timedelta(days=1):
                feed.update()

        return code, message, us

    def mark_feed_read(self):
        now = datetime.datetime.utcnow()
        
        # Use the latest story to get last read time.
        if MStory.objects(story_feed_id=self.feed.pk).first():
            latest_story_date = MStory.objects(story_feed_id=self.feed.pk).order_by('-story_date').only('story_date')[0]['story_date']\
                                + datetime.timedelta(seconds=1)
        else:
            latest_story_date = now

        self.last_read_date = latest_story_date
        self.mark_read_date = latest_story_date
        self.unread_count_negative = 0
        self.unread_count_positive = 0
        self.unread_count_neutral = 0
        self.unread_count_updated = latest_story_date
        self.needs_unread_recalc = False
        MUserStory.delete_marked_as_read_stories(self.user.pk, self.feed.pk)
        
        self.save()
    
    def calculate_feed_scores(self, silent=False, stories_db=None):
        now = datetime.datetime.utcnow()
        UNREAD_CUTOFF = now - datetime.timedelta(days=settings.DAYS_OF_UNREAD)

        if self.user.profile.last_seen_on < UNREAD_CUTOFF:
            # if not silent:
            #     logging.info(' ---> [%s] SKIPPING Computing scores: %s (1 week+)' % (self.user, self.feed))
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
        date_delta = UNREAD_CUTOFF
        if date_delta < self.mark_read_date:
            date_delta = self.mark_read_date
        else:
            self.mark_read_date = date_delta
            
        read_stories = MUserStory.objects(user_id=self.user.pk,
                                          feed_id=self.feed.pk,
                                          read_date__gte=self.mark_read_date)
        # if not silent:
        #     logging.info(' ---> [%s]    Read stories: %s' % (self.user, datetime.datetime.now() - now))
        read_stories_ids = []
        for us in read_stories:
            if hasattr(us.story, 'story_guid') and isinstance(us.story.story_guid, unicode):
                read_stories_ids.append(us.story.story_guid)
            elif hasattr(us.story, 'id') and isinstance(us.story.id, unicode):
                read_stories_ids.append(us.story.id) # TODO: Remove me after migration from story.id->guid
        stories_db = stories_db or MStory.objects(story_feed_id=self.feed.pk,
                                                  story_date__gte=date_delta)
        # if not silent:
        #     logging.info(' ---> [%s]    MStory: %s' % (self.user, datetime.datetime.now() - now))
        oldest_unread_story_date = now
        unread_stories_db = []
        for story in stories_db:
            if story.story_date < date_delta:
                continue
            if hasattr(story, 'story_guid') and story.story_guid not in read_stories_ids:
                unread_stories_db.append(story)
                if story.story_date < oldest_unread_story_date:
                    oldest_unread_story_date = story.story_date
        stories = Feed.format_stories(unread_stories_db, self.feed.pk)
        # if not silent:
        #     logging.info(' ---> [%s]    Format stories: %s' % (self.user, datetime.datetime.now() - now))
        
        classifier_feeds   = list(MClassifierFeed.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_authors = list(MClassifierAuthor.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_titles  = list(MClassifierTitle.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_tags    = list(MClassifierTag.objects(user_id=self.user.pk, feed_id=self.feed.pk))

        # if not silent:
        #     logging.info(' ---> [%s]    Classifiers: %s (%s)' % (self.user, datetime.datetime.now() - now, classifier_feeds.count() + classifier_authors.count() + classifier_tags.count() + classifier_titles.count()))
            
        scores = {
            'feed': apply_classifier_feeds(classifier_feeds, self.feed),
        }
        
        for story in stories:
            scores.update({
                'author' : apply_classifier_authors(classifier_authors, story),
                'tags'   : apply_classifier_tags(classifier_tags, story),
                'title'  : apply_classifier_titles(classifier_titles, story),
            })
            
            max_score = max(scores['author'], scores['tags'], scores['title'])
            min_score = min(scores['author'], scores['tags'], scores['title'])
            if max_score > 0:
                feed_scores['positive'] += 1
            elif min_score < 0:
                feed_scores['negative'] += 1
            else:
                if scores['feed'] > 0:
                    feed_scores['positive'] += 1
                elif scores['feed'] < 0:
                    feed_scores['negative'] += 1
                else:
                    feed_scores['neutral'] += 1
                
        
        # if not silent:
        #     logging.info(' ---> [%s]    End classifiers: %s' % (self.user, datetime.datetime.now() - now))
            
        self.unread_count_positive = feed_scores['positive']
        self.unread_count_neutral = feed_scores['neutral']
        self.unread_count_negative = feed_scores['negative']
        self.unread_count_updated = datetime.datetime.now()
        self.oldest_unread_story_date = oldest_unread_story_date
        self.needs_unread_recalc = False
        
        self.save()

        # if (self.unread_count_positive == 0 and 
        #     self.unread_count_neutral == 0):
        #     self.mark_feed_read()
        
        cache.delete('usersub:%s' % self.user.id)
        
        return
        
    class Meta:
        unique_together = ("user", "feed")
        
        
class MUserStory(mongo.Document):
    """
    Stories read by the user. These are deleted as the mark_read_date for the
    UserSubscription passes the UserStory date.
    """
    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    read_date = mongo.DateTimeField()
    story_date = mongo.DateTimeField()
    story = mongo.ReferenceField(MStory, unique_with=('user_id', 'feed_id'))
    
    meta = {
        'collection': 'userstories',
        'indexes': [('user_id', 'feed_id'), ('feed_id', 'read_date'), ('feed_id', 'story_date')],
        'allow_inheritance': False,
    }
    
    @classmethod
    def delete_old_stories(cls, feed_id):
        UNREAD_CUTOFF = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
        cls.objects(feed_id=feed_id, read_date__lte=UNREAD_CUTOFF).delete()
        
    @classmethod
    def delete_marked_as_read_stories(cls, user_id, feed_id, mark_read_date=None):
        if not mark_read_date:
            usersub = UserSubscription.objects.get(user__pk=user_id, feed__pk=feed_id)
            mark_read_date = usersub.mark_read_date
        cls.objects(user_id=user_id, feed_id=feed_id, read_date__lte=usersub.mark_read_date).delete()
    
        
class UserSubscriptionFolders(models.Model):
    """
    A JSON list of folders and feeds for while a user has subscribed. The list
    is a recursive descent of feeds and folders in folders. Used to layout
    the feeds and folders in the Reader's feed navigation pane.
    """
    user = models.ForeignKey(User, unique=True)
    folders = models.TextField(default="[]")
    
    def __unicode__(self):
        return "[%s]: %s" % (self.user, len(self.folders),)
        
    class Meta:
        verbose_name_plural = "folders"
        verbose_name = "folder"
    
    def add_folder(self, parent_folder, folder):
        if self.folders:
            user_sub_folders = json.decode(self.folders)
        else:
            user_sub_folders = []
        obj = {folder: []}
        user_sub_folders = add_object_to_folder(obj, parent_folder, user_sub_folders)
        self.folders = json.encode(user_sub_folders)
        self.save()
        
    def delete_feed(self, feed_id, in_folder):
        def _find_feed_in_folders(old_folders, folder_name='', multiples_found=False, deleted=False):
            new_folders = []
            for k, folder in enumerate(old_folders):
                if isinstance(folder, int):
                    if (folder == feed_id and (
                        (folder_name != in_folder) or
                        (folder_name == in_folder and deleted))):
                        multiples_found = True
                        logging.user(self.user, "~FB~SBDeleting feed, and a multiple has been found in '%s'" % (folder_name))
                    if folder == feed_id and (folder_name == in_folder or not folder_name) and not deleted:
                        logging.user(self.user, "~FBDelete feed: %s'th item: %s folders/feeds" % (
                            k, len(old_folders)
                        ))
                        deleted = True
                    else:
                        new_folders.append(folder)
                elif isinstance(folder, dict):
                    for f_k, f_v in folder.items():
                        nf, multiples_found, deleted = _find_feed_in_folders(f_v, f_k, multiples_found, deleted)
                        new_folders.append({f_k: nf})
    
            return new_folders, multiples_found, deleted
        
        user_sub_folders = json.decode(self.folders)
        user_sub_folders, multiples_found, deleted = _find_feed_in_folders(user_sub_folders)
        self.folders = json.encode(user_sub_folders)
        self.save()

        if not multiples_found and deleted:
            try:
                user_sub = UserSubscription.objects.get(user=self.user, feed=feed_id)
            except Feed.DoesNotExist:
                duplicate_feed = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
                if duplicate_feed:
                    try:
                        user_sub = UserSubscription.objects.get(user=self.user, 
                                                                feed=duplicate_feed[0].feed)
                    except Feed.DoesNotExist:
                        return
            user_sub.delete()
            MUserStory.objects(user_id=self.user.pk, feed_id=feed_id).delete()

    def delete_folder(self, folder_to_delete, in_folder, feed_ids_in_folder):
        def _find_folder_in_folders(old_folders, folder_name, feeds_to_delete):
            new_folders = []
            for k, folder in enumerate(old_folders):
                if isinstance(folder, int):
                    new_folders.append(folder)
                    if folder in feeds_to_delete:
                        feeds_to_delete.remove(folder)
                elif isinstance(folder, dict):
                    for f_k, f_v in folder.items():
                        if f_k == folder_to_delete and folder_name == in_folder:
                            logging.user(self.user, "~FBDeleting folder '~SB%s~SN' in '%s': %s" % (f_k, folder_name, folder))
                        else:
                            nf, feeds_to_delete = _find_folder_in_folders(f_v, f_k, feeds_to_delete)
                            new_folders.append({f_k: nf})
    
            return new_folders, feeds_to_delete
            
        user_sub_folders = json.decode(self.folders)
        user_sub_folders, feeds_to_delete = _find_folder_in_folders(user_sub_folders, '', feed_ids_in_folder)
        self.folders = json.encode(user_sub_folders)
        self.save()
        
        UserSubscription.objects.filter(user=self.user, feed__in=feeds_to_delete).delete()
        
    def rename_folder(self, folder_to_rename, new_folder_name, in_folder):
        def _find_folder_in_folders(old_folders, folder_name):
            new_folders = []
            for k, folder in enumerate(old_folders):
                if isinstance(folder, int):
                    new_folders.append(folder)
                elif isinstance(folder, dict):
                    for f_k, f_v in folder.items():
                        nf = _find_folder_in_folders(f_v, f_k)
                        if f_k == folder_to_rename and folder_name == in_folder:
                            logging.user(self.user, "~FBRenaming folder '~SB%s~SN' in '%s' to: ~SB%s" % (
                                         f_k, folder_name, new_folder_name))
                            f_k = new_folder_name
                        new_folders.append({f_k: nf})
    
            return new_folders
            
        user_sub_folders = json.decode(self.folders)
        user_sub_folders = _find_folder_in_folders(user_sub_folders, '')
        self.folders = json.encode(user_sub_folders)
        self.save()

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
