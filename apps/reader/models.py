import datetime
import time
import redis
import hashlib
import mongoengine as mongo
from utils import log as logging
from utils import json_functions as json
from django.db import models, IntegrityError
from django.conf import settings
from django.contrib.auth.models import User
from mongoengine.queryset import OperationError
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
        return '[%s (%s): %s (%s)] ' % (self.user.username, self.user.pk, 
                                        self.feed.feed_title, self.feed.pk)
        
    class Meta:
        unique_together = ("user", "feed")
    
    def canonical(self, full=False, include_favicon=True, classifiers=None):
        feed               = self.feed.canonical(full=full, include_favicon=include_favicon)
        feed['feed_title'] = self.user_title or feed['feed_title']
        feed['ps']         = self.unread_count_positive
        feed['nt']         = self.unread_count_neutral
        feed['ng']         = self.unread_count_negative
        feed['active']     = self.active
        feed['feed_opens'] = self.feed_opens
        feed['subscribed'] = True
        if classifiers:
            feed['classifiers'] = classifiers
        if not self.active and self.user.profile.is_premium:
            feed['active'] = True
            self.active = True
            self.save()

        return feed
            
    def save(self, *args, **kwargs):
        user_title_max = self._meta.get_field('user_title').max_length
        if self.user_title and len(self.user_title) > user_title_max:
            self.user_title = self.user_title[:user_title_max]
        if not self.active and self.user.profile.is_premium:
            self.active = True
        try:
            super(UserSubscription, self).save(*args, **kwargs)
        except IntegrityError:
            duplicate_feeds = DuplicateFeed.objects.filter(duplicate_feed_id=self.feed_id)
            for duplicate_feed in duplicate_feeds:
                already_subscribed = UserSubscription.objects.filter(user=self.user, feed=duplicate_feed.feed)
                if not already_subscribed:
                    self.feed = duplicate_feed.feed
                    super(UserSubscription, self).save(*args, **kwargs)
                    break
            else:
                self.delete()
    
    @classmethod
    def sync_all_redis(cls, user_id, skip_feed=False):
        us = cls.objects.filter(user=user_id)

        for sub in us:
            print " ---> Syncing usersub: %s" % sub
            sub.sync_redis(skip_feed=skip_feed)
        
    def sync_redis(self, skip_feed=False):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)
        
        if not skip_feed:
            self.feed.sync_redis()
        
        userstories = MUserStory.objects.filter(feed_id=self.feed_id, user_id=self.user_id)
        for userstory in userstories:
            userstory.sync_redis(r=r)
        
    def get_stories(self, offset=0, limit=6, order='newest', read_filter='all', withscores=False):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)
        ignore_user_stories = False
    
        stories_key         = 'F:%s' % (self.feed_id)
        read_stories_key    = 'RS:%s:%s' % (self.user_id, self.feed_id)
        unread_stories_key  = 'U:%s:%s' % (self.user_id, self.feed_id)

        unread_ranked_stories_key  = 'zU:%s:%s' % (self.user_id, self.feed_id)
        if offset and not withscores and r.exists(unread_ranked_stories_key):
            pass
        else:
            r.delete(unread_ranked_stories_key)
            if not r.exists(stories_key):
                print " ---> No stories on feed: %s" % self
                return []
            elif read_filter != 'unread' or not r.exists(read_stories_key):
                ignore_user_stories = True
                unread_stories_key = stories_key
            else:
                r.sdiffstore(unread_stories_key, stories_key, read_stories_key)
            sorted_stories_key          = 'zF:%s' % (self.feed_id)
            unread_ranked_stories_key   = 'zU:%s:%s' % (self.user_id, self.feed_id)
            r.zinterstore(unread_ranked_stories_key, [sorted_stories_key, unread_stories_key])
        
        current_time    = int(time.time() + 60*60*24)
        if order == 'oldest':
            byscorefunc = r.zrangebyscore
            if read_filter == 'unread':
                min_score = int(time.mktime(self.mark_read_date.timetuple())) + 1
            else:
                now = datetime.datetime.now()
                two_weeks_ago = now - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
                min_score = int(time.mktime(two_weeks_ago.timetuple()))-1000
            max_score = current_time
        else:
            byscorefunc = r.zrevrangebyscore
            min_score = current_time
            if read_filter == 'unread':
                # +1 for the intersection b/w zF and F, which carries an implicit score of 1.
                max_score = int(time.mktime(self.mark_read_date.timetuple())) + 1
            else:
                max_score = 0

        if settings.DEBUG:
            debug_stories = r.zrevrange(unread_ranked_stories_key, 0, -1, withscores=True)
            print " ---> Unread all stories (%s - %s) %s stories: %s" % (
                min_score,
                max_score,
                len(debug_stories),
                debug_stories)
        story_ids = byscorefunc(unread_ranked_stories_key, min_score, 
                                  max_score, start=offset, num=500,
                                  withscores=withscores)[:limit]
        r.expire(unread_ranked_stories_key, 24*60*60)
        if not ignore_user_stories:
            r.delete(unread_stories_key)
        
        # XXX TODO: Remove below line after combing redis for these None's.
        story_ids = [s for s in story_ids if s and s != 'None'] # ugh, hack
        
        if withscores:
            return story_ids
        elif story_ids:
            story_date_order = "%sstory_date" % ('' if order == 'oldest' else '-')
            mstories = MStory.objects(id__in=story_ids).order_by(story_date_order)
            stories = Feed.format_stories(mstories)
            return stories
        else:
            return []
        
    @classmethod
    def feed_stories(cls, user_id, feed_ids, offset=0, limit=6, order='newest', read_filter='all'):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)
        
        if order == 'oldest':
            range_func = r.zrange
        else:
            range_func = r.zrevrange
            
        if not isinstance(feed_ids, list):
            feed_ids = [feed_ids]

        unread_ranked_stories_keys  = 'zU:%s:feeds' % (user_id)
        if offset and r.exists(unread_ranked_stories_keys):
            story_guids = range_func(unread_ranked_stories_keys, offset, limit)
            return story_guids
        else:
            r.delete(unread_ranked_stories_keys)

        for feed_id in feed_ids:
            try:
                us = cls.objects.get(user=user_id, feed=feed_id)
            except cls.DoesNotExist:
                continue
            story_guids = us.get_stories(offset=0, limit=200, 
                                         order=order, read_filter=read_filter, 
                                         withscores=True)

            if story_guids:
                r.zadd(unread_ranked_stories_keys, **dict(story_guids))
            
        story_guids = range_func(unread_ranked_stories_keys, offset, limit)
        r.expire(unread_ranked_stories_keys, 24*60*60)
        
        return story_guids
        
    @classmethod
    def add_subscription(cls, user, feed_address, folder=None, bookmarklet=False, auto_active=True,
                         skip_fetch=False):
        feed = None
        us = None
    
        logging.user(user, "~FRAdding URL: ~SB%s (in %s) %s" % (feed_address, folder, 
                                                                "~FCAUTO-ADD" if not auto_active else ""))
    
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
                    'active': auto_active,
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
            
            if auto_active or user.profile.is_premium:
                us.active = True
                us.save()
        
            if not skip_fetch and feed.last_update < datetime.datetime.utcnow() - datetime.timedelta(days=1):
                feed = feed.update()
            
            from apps.social.models import MActivity
            MActivity.new_feed_subscription(user_id=user.pk, feed_id=feed.pk, feed_title=feed.title)
                
            feed.setup_feed_for_premium_subscribers()
        
        return code, message, us
    
    @classmethod
    def feeds_with_updated_counts(cls, user, feed_ids=None, check_fetch_status=False):
        feeds = {}
        
        # Get subscriptions for user
        user_subs = cls.objects.select_related('feed').filter(user=user, active=True)
        feed_ids = [f for f in feed_ids if f and not f.startswith('river')]
        if feed_ids:
            user_subs = user_subs.filter(feed__in=feed_ids)
        
        
        UNREAD_CUTOFF = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)

        for i, sub in enumerate(user_subs):
            # Count unreads if subscription is stale.
            if (sub.needs_unread_recalc or 
                sub.unread_count_updated < UNREAD_CUTOFF or 
                sub.oldest_unread_story_date < UNREAD_CUTOFF):
                sub = sub.calculate_feed_scores(silent=True)
            if not sub: continue # TODO: Figure out the correct sub and give it a new feed_id

            feed_id = sub.feed_id
            feeds[feed_id] = {
                'ps': sub.unread_count_positive,
                'nt': sub.unread_count_neutral,
                'ng': sub.unread_count_negative,
                'id': feed_id,
            }
            if not sub.feed.fetched_once or check_fetch_status:
                feeds[feed_id]['fetched_once'] = sub.feed.fetched_once
                feeds[feed_id]['not_yet_fetched'] = not sub.feed.fetched_once # Legacy. Dammit.
            if sub.feed.favicon_fetching:
                feeds[feed_id]['favicon_fetching'] = True
            if sub.feed.has_feed_exception or sub.feed.has_page_exception:
                feeds[feed_id]['has_exception'] = True
                feeds[feed_id]['exception_type'] = 'feed' if sub.feed.has_feed_exception else 'page'
                feeds[feed_id]['feed_address'] = sub.feed.feed_address
                feeds[feed_id]['exception_code'] = sub.feed.exception_code

        return feeds
        
    def mark_feed_read(self):
        now = datetime.datetime.utcnow()
        
        # Use the latest story to get last read time.
        latest_story = MStory.objects(story_feed_id=self.feed.pk).order_by('-story_date').only('story_date').limit(1)
        if latest_story and len(latest_story) >= 1:
            latest_story_date = latest_story[0]['story_date']\
                                + datetime.timedelta(seconds=1)
        else:
            latest_story_date = now
        
        self.last_read_date = latest_story_date
        self.mark_read_date = latest_story_date
        self.unread_count_negative = 0
        self.unread_count_positive = 0
        self.unread_count_neutral = 0
        self.unread_count_updated = now
        self.oldest_unread_story_date = now
        self.needs_unread_recalc = False
        
        # No longer removing old user read stories, since they're needed for social,
        # and they get cleaned up automatically when new stories come in.
        # MUserStory.delete_old_stories(self.user_id, self.feed_id)
        
        self.save()
        
    def mark_story_ids_as_read(self, story_ids, request=None):
        data = dict(code=0, payload=story_ids)
        
        if not request:
            request = self.user
    
        if not self.needs_unread_recalc:
            self.needs_unread_recalc = True
            self.save()
    
        if len(story_ids) > 1:
            logging.user(request, "~FYRead %s stories in feed: %s" % (len(story_ids), self.feed))
        else:
            logging.user(request, "~FYRead story in feed: %s" % (self.feed))
        
        for story_id in set(story_ids):
            try:
                story = MStory.objects.get(story_feed_id=self.feed_id, story_guid=story_id)
            except MStory.DoesNotExist:
                # Story has been deleted, probably by feed_fetcher.
                continue
            except MStory.MultipleObjectsReturned:
                story = MStory.objects.filter(story_feed_id=self.feed_id, story_guid=story_id)[0]
            now = datetime.datetime.utcnow()
            date = now if now > story.story_date else story.story_date # For handling future stories
            m, _ = MUserStory.objects.get_or_create(story_id=story_id, user_id=self.user_id, 
                                                    feed_id=self.feed_id, defaults={
                'read_date': date, 
                'story': story, 
                'story_date': story.story_date,
            })
                
        return data
    
    def calculate_feed_scores(self, silent=False, stories=None):
        # now = datetime.datetime.strptime("2009-07-06 22:30:03", "%Y-%m-%d %H:%M:%S")
        now = datetime.datetime.now()
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
            
        feed_scores = dict(negative=0, neutral=0, positive=0)
        
        # Two weeks in age. If mark_read_date is older, mark old stories as read.
        date_delta = UNREAD_CUTOFF
        if date_delta < self.mark_read_date:
            date_delta = self.mark_read_date
        else:
            self.mark_read_date = date_delta
        
        if not stories:
            stories_db = MStory.objects(story_feed_id=self.feed_id,
                                        story_date__gte=date_delta)
            stories = Feed.format_stories(stories_db, self.feed_id)
        
        story_ids = [s['id'] for s in stories]
        read_stories = MUserStory.objects(user_id=self.user_id,
                                          feed_id=self.feed_id,
                                          story_id__in=story_ids)
        read_stories_ids = [us.story_id for us in read_stories]

        oldest_unread_story_date = now
        unread_stories = []
        for story in stories:
            if story['story_date'] < date_delta:
                continue
            if story['id'] not in read_stories_ids:
                unread_stories.append(story)
                if story['story_date'] < oldest_unread_story_date:
                    oldest_unread_story_date = story['story_date']

        # if not silent:
        #     logging.info(' ---> [%s]    Format stories: %s' % (self.user, datetime.datetime.now() - now))
        
        classifier_feeds   = list(MClassifierFeed.objects(user_id=self.user_id, feed_id=self.feed_id, social_user_id=0))
        classifier_authors = list(MClassifierAuthor.objects(user_id=self.user_id, feed_id=self.feed_id))
        classifier_titles  = list(MClassifierTitle.objects(user_id=self.user_id, feed_id=self.feed_id))
        classifier_tags    = list(MClassifierTag.objects(user_id=self.user_id, feed_id=self.feed_id))

        # if not silent:
        #     logging.info(' ---> [%s]    Classifiers: %s (%s)' % (self.user, datetime.datetime.now() - now, classifier_feeds.count() + classifier_authors.count() + classifier_tags.count() + classifier_titles.count()))
            
        scores = {
            'feed': apply_classifier_feeds(classifier_feeds, self.feed),
        }
        
        for story in unread_stories:
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

        if (self.unread_count_positive == 0 and 
            self.unread_count_neutral == 0 and
            self.unread_count_negative == 0):
            self.mark_feed_read()
        
        if not silent:
            logging.user(self.user, '~FC~SNComputing scores: %s (~SB%s~SN/~SB%s~SN/~SB%s~SN)' % (self.feed, feed_scores['negative'], feed_scores['neutral'], feed_scores['positive']))
            
        return self
    
    def switch_feed(self, new_feed, old_feed):
        # Rewrite feed in subscription folders
        try:
            user_sub_folders = UserSubscriptionFolders.objects.get(user=self.user)
        except Exception, e:
            logging.info(" *** ---> UserSubscriptionFolders error: %s" % e)
            return
    
        # Switch to original feed for the user subscription
        logging.info("      ===> %s " % self.user)
        self.feed = new_feed
        self.needs_unread_recalc = True
        try:
            self.save()
            user_sub_folders.rewrite_feed(new_feed, old_feed)
        except (IntegrityError, OperationError):
            logging.info("      !!!!> %s already subscribed" % self.user)
            self.delete()
            return
        
        # Switch read stories
        user_stories = MUserStory.objects(user_id=self.user_id, feed_id=old_feed.pk)
        if user_stories.count() > 0:
            logging.info(" ---> %s read stories" % user_stories.count())

        for user_story in user_stories:
            user_story.feed_id = new_feed.pk
            duplicate_story = user_story.story
            if duplicate_story:
                story_guid = duplicate_story.story_guid if hasattr(duplicate_story, 'story_guid') else duplicate_story.id
                original_story = MStory.objects(story_feed_id=new_feed.pk,
                                                story_guid=story_guid)
        
                if original_story:
                    user_story.story = original_story[0]
                    try:
                        user_story.save()
                    except OperationError:
                        # User read the story in the original feed, too. Ugh, just ignore it.
                        pass
                else:
                    user_story.delete()
            else:
                user_story.delete()
            
        def switch_feed_for_classifier(model):
            duplicates = model.objects(feed_id=old_feed.pk, user_id=self.user_id)
            if duplicates.count():
                logging.info(" ---> Switching %s %s" % (duplicates.count(), model))
            for duplicate in duplicates:
                duplicate.feed_id = new_feed.pk
                if duplicate.social_user_id is None:
                    duplicate.social_user_id = 0
                try:
                    duplicate.save()
                    pass
                except (IntegrityError, OperationError):
                    logging.info("      !!!!> %s already exists" % duplicate)
                    duplicate.delete()
        
        switch_feed_for_classifier(MClassifierTitle)
        switch_feed_for_classifier(MClassifierAuthor)
        switch_feed_for_classifier(MClassifierFeed)
        switch_feed_for_classifier(MClassifierTag)
    
    @classmethod
    def collect_orphan_feeds(cls, user):
        us = cls.objects.filter(user=user)
        try:
            usf = UserSubscriptionFolders.objects.get(user=user)
        except UserSubscriptionFolders.DoesNotExist:
            return
        us_feed_ids = set([sub.feed_id for sub in us])
        folders = json.decode(usf.folders)
        
        def collect_ids(folders, found_ids):
            for item in folders:
                # print ' --> %s' % item
                if isinstance(item, int):
                    # print ' --> Adding feed: %s' % item
                    found_ids.add(item)
                elif isinstance(item, dict):
                    # print ' --> Descending folder dict: %s' % item.values()
                    found_ids.update(collect_ids(item.values(), found_ids))
                elif isinstance(item, list):
                    # print ' --> Descending folder list: %s' % len(item)
                    found_ids.update(collect_ids(item, found_ids))
            # print ' --> Returning: %s' % found_ids
            return found_ids
        found_ids = collect_ids(folders, set())
        diff = len(us_feed_ids) - len(found_ids)
        if diff > 0:
            logging.info(" ---> Collecting orphans on %s. %s feeds with %s orphans" % (user.username, len(us_feed_ids), diff))
            orphan_ids = us_feed_ids - found_ids
            folders.extend(list(orphan_ids))
            usf.folders = json.encode(folders)
            usf.save()
            

class MUserStory(mongo.Document):
    """
    Stories read by the user. These are deleted as the mark_read_date for the
    UserSubscription passes the UserStory date.
    """
    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    read_date = mongo.DateTimeField()
    story_id = mongo.StringField()
    story_date = mongo.DateTimeField()
    story = mongo.ReferenceField(MStory, dbref=True)
    found_story = mongo.GenericReferenceField()
    shared = mongo.BooleanField()
    
    meta = {
        'collection': 'userstories',
        'indexes': [
            {'fields': ('user_id', 'feed_id', 'story_id'), 'unique': True},
            ('feed_id', 'story_id'),   # Updating stories with new guids
            ('feed_id', 'story_date'), # Trimming feeds
            ('feed_id', '-read_date'), # Trimming feeds
        ],
        'allow_inheritance': False,
        'index_drop_dups': True,
        'cascade': False,
    }
    
    def save(self, *args, **kwargs):
        self.sync_redis()
        
        super(MUserStory, self).save(*args, **kwargs)
        
    def delete(self, *args, **kwargs):
        self.remove_from_redis()
        
        super(MUserStory, self).delete(*args, **kwargs)
        
    @property
    def guid_hash(self):
        return hashlib.sha1(self.story_id).hexdigest()
        
    @classmethod
    def delete_old_stories(cls, feed_id):
        UNREAD_CUTOFF = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD*5)
        read_stories = cls.objects(feed_id=feed_id, read_date__lte=UNREAD_CUTOFF)
        read_stories_count = read_stories.count()
        if read_stories_count:
            feed = Feed.objects.get(pk=feed_id)
            total = cls.objects(feed_id=feed_id).count()    
            logging.info(" ---> ~SN~FCTrimming ~SB%s~SN/~SB%s~SN read stories from %s..." %
                         (read_stories_count, total, feed.title[:30]))
            read_stories.delete()
        
    @classmethod
    def delete_marked_as_read_stories(cls, user_id, feed_id, mark_read_date=None):
        if not mark_read_date:
            usersub = UserSubscription.objects.get(user__pk=user_id, feed__pk=feed_id)
            mark_read_date = usersub.mark_read_date
        
        # Next line forces only old read stories to be removed, just in case newer stories
        # come in as unread because they're being shared.
        mark_read_date = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)

        cls.objects(user_id=user_id, feed_id=feed_id, read_date__lte=mark_read_date).delete()
    
    @property
    def story_db_id(self):
        if self.story:
            return self.story.id
        elif self.found_story:
            if '_ref' in self.found_story:
                return self.found_story['_ref'].id
            elif hasattr(self.found_story, 'id'):
                return self.found_story.id
        
        story, found_original = MStory.find_story(self.feed_id, self.story_id)
        if story:
            if found_original:
                self.story = story
            else:
                self.found_story = story
            self.save()
            
            return story.id
            
    def sync_redis(self, r=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)

        if self.story_db_id:
            all_read_stories_key = 'RS:%s' % (self.user_id)
            r.sadd(all_read_stories_key, self.story_db_id)

            read_story_key = 'RS:%s:%s' % (self.user_id, self.feed_id)
            r.sadd(read_story_key, self.story_db_id)
            r.expire(read_story_key, settings.DAYS_OF_UNREAD*24*60*60)

    def remove_from_redis(self):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)
        if self.story_db_id:
            r.srem('RS:%s' % self.user_id, self.story_db_id)
            r.srem('RS:%s:%s' % (self.user_id, self.feed_id), self.story_db_id)
        
    @classmethod
    def sync_all_redis(cls, user_id=None, feed_id=None, force=False):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)
        UNREAD_CUTOFF = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD*2)

        if feed_id:
            read_stories = cls.objects.filter(feed_id=feed_id, read_date__gte=UNREAD_CUTOFF)
            keys = r.keys("RS:*:%s" % feed_id)
            print " ---> Deleting %s redis keys: %s" % (len(keys), keys)
            for key in keys:
                r.delete(key)
        elif user_id:
            read_stories = cls.objects.filter(user_id=user_id, read_date__gte=UNREAD_CUTOFF)
            keys = r.keys("RS:%s:*" % user_id)
            r.delete("RS:%s" % user_id)
            print " ---> Deleting %s redis keys: %s" % (len(keys), keys)
            for key in keys:
                r.delete(key)            
        elif force:
            read_stories = cls.objects.all(read_date__gte=UNREAD_CUTOFF)
        else:
            raise "Specify user_id, feed_id, or force."

        total = read_stories.count()
        print " ---> Syncing %s stories (%s)" % (total, user_id or feed_id)
        for i, read_story in enumerate(read_stories):
            if (i+1) % 1000 == 0: 
                print " ---> %s/%s" % (i+1, total)
            read_story.sync_redis(r)
        
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
    
    def compact(self):
        folders = json.decode(self.folders)
        
        def _compact(folder):
            new_folder = []
            for item in folder:
                if isinstance(item, int) and item not in new_folder:
                    new_folder.append(item)
                elif isinstance(item, dict):
                    for f_k, f_v in item.items():
                        new_folder.append({f_k: _compact(f_v)})
            return new_folder
        
        new_folders = _compact(folders)
        logging.info(" ---> Compacting from %s to %s" % (folders, new_folders))
        new_folders = json.encode(new_folders)
        logging.info(" ---> Compacting from %s to %s" % (len(self.folders), len(new_folders)))
        self.folders = new_folders
        self.save()
        
    def add_folder(self, parent_folder, folder):
        if self.folders:
            user_sub_folders = json.decode(self.folders)
        else:
            user_sub_folders = []
        obj = {folder: []}
        user_sub_folders = add_object_to_folder(obj, parent_folder, user_sub_folders)
        self.folders = json.encode(user_sub_folders)
        self.save()
        
    def delete_feed(self, feed_id, in_folder, commit_delete=True):
        def _find_feed_in_folders(old_folders, folder_name='', multiples_found=False, deleted=False):
            new_folders = []
            for k, folder in enumerate(old_folders):
                if isinstance(folder, int):
                    if (folder == feed_id and (
                        (folder_name != in_folder) or
                        (folder_name == in_folder and deleted))):
                        multiples_found = True
                        logging.user(self.user, "~FB~SBDeleting feed, and a multiple has been found in '%s'" % (folder_name))
                    if folder == feed_id and (folder_name == in_folder) and not deleted:
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

        if not multiples_found and deleted and commit_delete:
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
            if user_sub:
                user_sub.delete()
            MUserStory.objects(user_id=self.user_id, feed_id=feed_id).delete()

    def delete_folder(self, folder_to_delete, in_folder, feed_ids_in_folder, commit_delete=True):
        def _find_folder_in_folders(old_folders, folder_name, feeds_to_delete, deleted_folder=None):
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
                            deleted_folder = folder
                        else:
                            nf, feeds_to_delete, deleted_folder = _find_folder_in_folders(f_v, f_k, feeds_to_delete, deleted_folder)
                            new_folders.append({f_k: nf})
    
            return new_folders, feeds_to_delete, deleted_folder
            
        user_sub_folders = json.decode(self.folders)
        user_sub_folders, feeds_to_delete, deleted_folder = _find_folder_in_folders(user_sub_folders, '', feed_ids_in_folder)
        self.folders = json.encode(user_sub_folders)
        self.save()

        if commit_delete:
            UserSubscription.objects.filter(user=self.user, feed__in=feeds_to_delete).delete()
          
        return deleted_folder
        
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
        
    def move_feed_to_folder(self, feed_id, in_folder=None, to_folder=None):
        logging.user(self.user, "~FBMoving feed '~SB%s~SN' in '%s' to: ~SB%s" % (
                     feed_id, in_folder, to_folder))
        user_sub_folders = json.decode(self.folders)
        self.delete_feed(feed_id, in_folder, commit_delete=False)
        user_sub_folders = json.decode(self.folders)
        user_sub_folders = add_object_to_folder(int(feed_id), to_folder, user_sub_folders)
        self.folders = json.encode(user_sub_folders)
        self.save()
        
        return self

    def move_folder_to_folder(self, folder_name, in_folder=None, to_folder=None):
        logging.user(self.user, "~FBMoving folder '~SB%s~SN' in '%s' to: ~SB%s" % (
                     folder_name, in_folder, to_folder))
        user_sub_folders = json.decode(self.folders)
        deleted_folder = self.delete_folder(folder_name, in_folder, [], commit_delete=False)
        user_sub_folders = json.decode(self.folders)
        user_sub_folders = add_object_to_folder(deleted_folder, to_folder, user_sub_folders)
        self.folders = json.encode(user_sub_folders)
        self.save()
        
        return self
    
    def rewrite_feed(self, original_feed, duplicate_feed):
        def rewrite_folders(folders, original_feed, duplicate_feed):
            new_folders = []
    
            for k, folder in enumerate(folders):
                if isinstance(folder, int):
                    if folder == duplicate_feed.pk:
                        # logging.info("              ===> Rewrote %s'th item: %s" % (k+1, folders))
                        new_folders.append(original_feed.pk)
                    else:
                        new_folders.append(folder)
                elif isinstance(folder, dict):
                    for f_k, f_v in folder.items():
                        new_folders.append({f_k: rewrite_folders(f_v, original_feed, duplicate_feed)})

            return new_folders
            
        folders = json.decode(self.folders)
        folders = rewrite_folders(folders, original_feed, duplicate_feed)
        self.folders = json.encode(folders)
        self.save()
    
    def flat(self):
        folders = json.decode(self.folders)
        
        def _flat(folder, feeds=None):
            if not feeds:
                feeds = []
            for item in folder:
                if isinstance(item, int) and item not in feeds:
                    feeds.append(item)
                elif isinstance(item, dict):
                    for f_k, f_v in item.items():
                        feeds.extend(_flat(f_v))
            return feeds

        return _flat(folders)
    
    @classmethod
    def add_all_missing_feeds(cls):
        usf = cls.objects.all().order_by('pk')
        total = usf.count()
        
        for i, f in enumerate(usf):
            print "%s/%s: %s" % (i, total, f)
            f.add_missing_feeds()
        
    def add_missing_feeds(self):
        all_feeds = self.flat()
        subs = [us.feed_id for us in
                UserSubscription.objects.filter(user=self.user).only('feed')]
        
        missing_feeds = set(all_feeds) - set(subs)
        if missing_feeds:
            logging.debug(" ---> %s is missing %s feeds. Adding %s..." % (
                          self.user, len(missing_feeds), missing_feeds))
            for feed_id in missing_feeds:
                feed = Feed.get_by_id(feed_id)
                if feed:
                    UserSubscription.objects.get_or_create(user=self.user, feed=feed)


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
