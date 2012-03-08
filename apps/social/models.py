import datetime
import zlib
import hashlib
import redis
import re
import mongoengine as mongo
from collections import defaultdict
# from mongoengine.queryset import OperationError
from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.core.urlresolvers import reverse
from apps.reader.models import UserSubscription, MUserStory
from apps.analyzer.models import MClassifierFeed, MClassifierAuthor, MClassifierTag, MClassifierTitle
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds, apply_classifier_authors, apply_classifier_tags
from apps.rss_feeds.models import Feed
from vendor import facebook
from vendor import tweepy
from utils import log as logging
from utils.feed_functions import relative_timesince
from utils import json_functions as json


class MSocialProfile(mongo.Document):
    user_id              = mongo.IntField()
    username             = mongo.StringField(max_length=30)
    email                = mongo.StringField()
    bio                  = mongo.StringField(max_length=80)
    blog_title           = mongo.StringField(max_length=256)
    custom_css           = mongo.StringField()
    photo_url            = mongo.StringField()
    photo_service        = mongo.StringField()
    location             = mongo.StringField(max_length=40)
    website              = mongo.StringField(max_length=200)
    subscription_count   = mongo.IntField(default=0)
    shared_stories_count = mongo.IntField(default=0)
    following_count      = mongo.IntField(default=0)
    follower_count       = mongo.IntField(default=0)
    following_user_ids   = mongo.ListField(mongo.IntField())
    follower_user_ids    = mongo.ListField(mongo.IntField())
    unfollowed_user_ids  = mongo.ListField(mongo.IntField())
    popular_publishers   = mongo.StringField()
    stories_last_month   = mongo.IntField(default=0)
    average_stories_per_month = mongo.IntField(default=0)
    story_count_history  = mongo.ListField()
    feed_classifier_counts = mongo.DictField()
    favicon_color        = mongo.StringField(max_length=6)
    
    meta = {
        'collection': 'social_profile',
        'indexes': ['user_id', 'following_user_ids', 'follower_user_ids', 'unfollowed_user_ids'],
        'allow_inheritance': False,
    }
    
    def __unicode__(self):
        return "%s [%s] %s/%s" % (self.username, self.user_id, 
                                  self.subscription_count, self.shared_stories_count)
    
    def save(self, *args, **kwargs):
        if not self.username:
            self.import_user_fields()
        if not self.subscription_count:
            self.count(skip_save=True)
        if self.bio and len(self.bio) > MSocialProfile.bio.max_length:
            self.bio = self.bio[:80]
        super(MSocialProfile, self).save(*args, **kwargs)
        if self.user_id not in self.following_user_ids:
            self.follow_user(self.user_id)
            self.count()
    
    def count_stories(self):
        # Popular Publishers
        self.save_popular_publishers()
        
    def save_popular_publishers(self, feed_publishers=None):
        if not feed_publishers:
            publishers = defaultdict(int)
            for story in MSharedStory.objects(user_id=self.user_id).only('story_feed_id')[:500]:
                publishers[story.story_feed_id] += 1
            feed_titles = dict((f.id, f.feed_title) 
                               for f in Feed.objects.filter(pk__in=publishers.keys()).only('id', 'feed_title'))
            feed_publishers = sorted([{'id': k, 'feed_title': feed_titles[k], 'story_count': v} 
                                      for k, v in publishers.items()],
                                     key=lambda f: f['story_count'],
                                     reverse=True)[:20]

        popular_publishers = json.encode(feed_publishers)
        if len(popular_publishers) < 1023:
            self.popular_publishers = popular_publishers
            self.save()
            return

        if len(popular_publishers) > 1:
            self.save_popular_publishers(feed_publishers=feed_publishers[:-1])
        
    @classmethod
    def user_statistics(cls, user):
        try:
            profile = cls.objects.get(user_id=user.pk)
        except cls.DoesNotExist:
            return None
        
        values = {
            'followers': profile.follower_count,
            'following': profile.following_count,
            'shared_stories': profile.shared_stories_count,
        }
        return values
        
    @classmethod
    def profiles(cls, user_ids):
        profiles = cls.objects.filter(user_id__in=user_ids)
        return profiles

    @classmethod
    def profile_feeds(cls, user_ids):
        profiles = cls.objects.filter(user_id__in=user_ids, shared_stories_count__gte=1)
        profiles = dict((p.user_id, p.feed()) for p in profiles)
        return profiles
        
    @classmethod
    def sync_all_redis(cls):
        for profile in cls.objects.all():
            profile.sync_redis()
    
    def sync_redis(self):
        for user_id in self.following_user_ids:
            self.follow_user(user_id)
        
        self.follow_user(self.user_id)
    
    @property
    def title(self):
        return self.blog_title if self.blog_title else self.username + "'s blurblog"
        
    def feed(self):
        params = self.to_json(compact=True)
        params.update({
            'feed_title': self.title,
            'page_url': reverse('load-social-page', kwargs={'user_id': self.user_id, 'username': self.username})
        })
        return params
        
    def page(self):
        params = self.to_json(full=True)
        params.update({
            'feed_title': self.title,
            'custom_css': self.custom_css,
        })
        return params
        
    def to_json(self, compact=False, full=False):
        domain = Site.objects.get_current().domain
        params = {
            'id': 'social:%s' % self.user_id,
            'user_id': self.user_id,
            'username': self.username,
            'photo_url': self.photo_url,
            'num_subscribers': self.follower_count,
            'feed_address': "http://%s%s" % (domain, reverse('shared-stories-rss-feed', 
                                    kwargs={'user_id': self.user_id, 'username': self.username})),
            'feed_link': "http://%s%s" % (domain, reverse('load-social-page', 
                                 kwargs={'user_id': self.user_id, 'username': self.username})),
        }
        if not compact:
            params.update({
                'bio': self.bio,
                'location': self.location,
                'website': self.website,
                'subscription_count': self.subscription_count,
                'shared_stories_count': self.shared_stories_count,
                'following_count': self.following_count,
                'follower_count': self.follower_count,
                'popular_publishers': json.decode(self.popular_publishers),
                'stories_last_month': self.stories_last_month,
                'average_stories_per_month': self.average_stories_per_month,
            })
        if full:
            params.update({
                'photo_service': self.photo_service,
                'following_user_ids': self.following_user_ids,
                'follower_user_ids': self.follower_user_ids,
                'unfollowed_user_ids': self.unfollowed_user_ids,
            })
        return params
    
    def import_user_fields(self, skip_save=False):
        user = User.objects.get(pk=self.user_id)
        self.username = user.username
        self.email = user.email

    def count(self, skip_save=False):
        self.subscription_count = UserSubscription.objects.filter(user__pk=self.user_id).count()
        self.shared_stories_count = MSharedStory.objects.filter(user_id=self.user_id).count()
        self.following_count = len(self.following_user_ids)
        self.follower_count = len(self.follower_user_ids)
        if not skip_save:
            self.save()
        
    def follow_user(self, user_id, check_unfollowed=False):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        
        if check_unfollowed and user_id in self.unfollowed_user_ids:
            return
            
        if user_id not in self.following_user_ids:
            self.following_user_ids.append(user_id)
            if user_id in self.unfollowed_user_ids:
                self.unfollowed_user_ids.remove(user_id)
            self.count()
            self.save()
            
            if self.user_id == user_id:
                followee = self
            else:
                followee, _ = MSocialProfile.objects.get_or_create(user_id=user_id)
            if self.user_id not in followee.follower_user_ids:
                followee.follower_user_ids.append(self.user_id)
                followee.count()
                followee.save()
        
        following_key = "F:%s:F" % (self.user_id)
        r.sadd(following_key, user_id)
        follower_key = "F:%s:f" % (user_id)
        r.sadd(follower_key, self.user_id)
        
        MSocialSubscription.objects.get_or_create(user_id=self.user_id, subscription_user_id=user_id)
    
    def is_following_user(self, user_id):
        return user_id in self.following_user_ids
        
    def unfollow_user(self, user_id):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        
        # import pdb; pdb.set_trace()
        if user_id in self.following_user_ids:
            self.following_user_ids.remove(user_id)
        if user_id not in self.unfollowed_user_ids:
            self.unfollowed_user_ids.append(user_id)
        self.count()
        self.save()
        
        followee = MSocialProfile.objects.get(user_id=user_id)
        if self.user_id in followee.follower_user_ids:
            followee.follower_user_ids.remove(self.user_id)
            followee.count()
            followee.save()
        
        if user_id != self.user_id:
            # Only unfollow other people, not yourself.
            following_key = "F:%s:F" % (self.user_id)
            r.srem(following_key, user_id)
            follower_key = "F:%s:f" % (user_id)
            r.srem(follower_key, self.user_id)
        
        MSocialSubscription.objects.get(user_id=self.user_id, subscription_user_id=user_id).delete()
    
    def common_follows(self, user_id, direction='followers'):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        
        my_followers = "F:%s:%s" % (self.user_id, 'f' if direction == 'followers' else 'F')
        their_followers = "F:%s:%s" % (user_id, 'F' if direction == 'followers' else 'f')
        follows_inter = r.sinter(my_followers, their_followers)
        follows_diff = r.sdiff(my_followers, their_followers)
        
        return list(follows_inter), list(follows_diff)
        
    def save_feed_story_history_statistics(self):
        """
        Fills in missing months between earlier occurances and now.
        
        Save format: [('YYYY-MM, #), ...]
        Example output: [(2010-12, 123), (2011-01, 146)]
        """
        now = datetime.datetime.utcnow()
        min_year = now.year
        total = 0
        month_count = 0

        # Count stories, aggregate by year and month. Map Reduce!
        map_f = """
            function() {
                var date = (this.shared_date.getFullYear()) + "-" + (this.shared_date.getMonth()+1);
                emit(date, 1);
            }
        """
        reduce_f = """
            function(key, values) {
                var total = 0;
                for (var i=0; i < values.length; i++) {
                    total += values[i];
                }
                return total;
            }
        """
        dates = {}
        res = MSharedStory.objects(user_id=self.user_id).map_reduce(map_f, reduce_f, output='inline')
        for r in res:
            dates[r.key] = r.value
            year = int(re.findall(r"(\d{4})-\d{1,2}", r.key)[0])
            if year < min_year:
                min_year = year
        
        # Assemble a list with 0's filled in for missing months, 
        # trimming left and right 0's.
        months = []
        start = False
        for year in range(min_year, now.year+1):
            for month in range(1, 12+1):
                if datetime.datetime(year, month, 1) < now:
                    key = u'%s-%s' % (year, month)
                    if dates.get(key) or start:
                        start = True
                        months.append((key, dates.get(key, 0)))
                        total += dates.get(key, 0)
                        month_count += 1

        self.story_count_history = months
        self.average_stories_per_month = total / month_count
        self.save()
    
    def save_classifier_counts(self):
        
        def calculate_scores(cls, facet):
            map_f = """
                function() {
                    emit(this["%s"], {
                        pos: this.score>0 ? this.score : 0, 
                        neg: this.score<0 ? Math.abs(this.score) : 0
                    });
                }
            """ % (facet)
            reduce_f = """
                function(key, values) {
                    var result = {pos: 0, neg: 0};
                    values.forEach(function(value) {
                        result.pos += value.pos;
                        result.neg += value.neg;
                    });
                    return result;
                }
            """
            scores = []
            res = cls.objects(social_user_id=self.user_id).map_reduce(map_f, reduce_f, output='inline')
            for r in res:
                facet_values = dict([(k, int(v)) for k,v in r.value.iteritems()])
                facet_values[facet] = r.key
                scores.append(facet_values)
            scores = sorted(scores, key=lambda v: v['neg'] - v['pos'])

            return scores
        
        scores = {}
        for cls, facet in [(MClassifierTitle, 'title'), 
                           (MClassifierAuthor, 'author'), 
                           (MClassifierTag, 'tag'), 
                           (MClassifierFeed, 'feed_id')]:
            scores[facet] = calculate_scores(cls, facet)
            if facet == 'feed_id' and scores[facet]:
                scores['feed'] = scores[facet]
                del scores['feed_id']
            elif not scores[facet]:
                del scores[facet]
                
        if scores:
            self.feed_classifier_counts = scores
            self.save()

class MSocialSubscription(mongo.Document):
    UNREAD_CUTOFF = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)

    user_id = mongo.IntField()
    subscription_user_id = mongo.IntField(unique_with='user_id')
    last_read_date = mongo.DateTimeField(default=UNREAD_CUTOFF)
    mark_read_date = mongo.DateTimeField(default=UNREAD_CUTOFF)
    unread_count_neutral = mongo.IntField(default=0)
    unread_count_positive = mongo.IntField(default=0)
    unread_count_negative = mongo.IntField(default=0)
    unread_count_updated = mongo.DateTimeField()
    oldest_unread_story_date = mongo.DateTimeField()
    needs_unread_recalc = mongo.BooleanField(default=False)
    feed_opens = mongo.IntField(default=0)
    is_trained = mongo.BooleanField(default=False)
    
    meta = {
        'collection': 'social_subscription',
        'indexes': [('user_id', 'subscription_user_id')],
        'allow_inheritance': False,
    }

    def __unicode__(self):
        return "%s:%s" % (self.user_id, self.subscription_user_id)
    
    @classmethod
    def feeds(cls, *args, **kwargs):
        user_id = kwargs['user_id']
        params = dict(user_id=user_id)
        if 'subscription_user_id' in kwargs:
            params["subscription_user_id"] = kwargs["subscription_user_id"]
        social_subs = cls.objects.filter(**params)
        for sub in social_subs:
            sub.calculate_feed_scores()
        social_feeds = []
        if social_subs:
            social_subs = dict((s.subscription_user_id, s.to_json()) for s in social_subs)
            social_user_ids = social_subs.keys()
            social_profiles = MSocialProfile.profile_feeds(social_user_ids)
            for user_id, social_sub in social_subs.items():
                # Check if the social feed has any stories, otherwise they aren't active.
                if user_id in social_profiles:
                    social_feeds.append(dict(social_sub.items() + social_profiles[user_id].items()))

        return social_feeds
    
    def to_json(self):
        return {
            'user_id': self.user_id,
            'subscription_user_id': self.subscription_user_id,
            'nt': self.unread_count_neutral,
            'ps': self.unread_count_positive,
            'ng': self.unread_count_negative,
            'is_trained': self.is_trained,
        }
    
    def mark_story_ids_as_read(self, story_ids, feed_id, request=None):
        data = dict(code=0, payload=story_ids)
        
        if not request:
            request = self.user
    
        if not self.needs_unread_recalc:
            self.needs_unread_recalc = True
            self.save()
    
        sub_username = MSocialProfile.objects.get(user_id=self.subscription_user_id).username

        if len(story_ids) > 1:
            logging.user(request, "~FYRead %s stories in social subscription: %s" % (len(story_ids), sub_username))
        else:
            logging.user(request, "~FYRead story in social subscription: %s" % (sub_username))
        
        for story_id in set(story_ids):
            story = MSharedStory.objects.get(user_id=self.subscription_user_id, story_guid=story_id)
            now = datetime.datetime.utcnow()
            date = now if now > story.story_date else story.story_date # For handling future stories
            m = MUserStory(user_id=self.user_id, 
                           feed_id=feed_id, read_date=date, 
                           story_id=story.story_guid, story_date=story.story_date)
            m.save()
                
        return data
        
    def mark_feed_read(self):
        latest_story_date = datetime.datetime.utcnow()
        
        # Use the latest story to get last read time.
        if MSharedStory.objects(user_id=self.subscription_user_id).first():
            latest_story_date = MSharedStory.objects(user_id=self.subscription_user_id)\
                                .order_by('-shared_date').only('shared_date')[0]['shared_date']\
                                + datetime.timedelta(seconds=1)

        self.last_read_date = latest_story_date
        self.mark_read_date = latest_story_date
        self.unread_count_negative = 0
        self.unread_count_positive = 0
        self.unread_count_neutral = 0
        self.unread_count_updated = latest_story_date
        self.oldest_unread_story_date = latest_story_date
        self.needs_unread_recalc = False

        # Cannot delete these stories, since the original feed may not be read. 
        # Just go 2 weeks back.
        # UNREAD_CUTOFF = now - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
        # MUserStory.delete_marked_as_read_stories(self.user_id, self.feed_id, mark_read_date=UNREAD_CUTOFF)
                
        self.save()
    
    def calculate_feed_scores(self, silent=False):
        # if not self.needs_unread_recalc:
        #     return
            
        now = datetime.datetime.now()
        UNREAD_CUTOFF = now - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
        user = User.objects.get(pk=self.user_id)

        if user.profile.last_seen_on < UNREAD_CUTOFF:
            # if not silent:
            #     logging.info(' ---> [%s] SKIPPING Computing scores: %s (1 week+)' % (self.user, self.feed))
            return
            
        feed_scores = dict(negative=0, neutral=0, positive=0)
        
        # Two weeks in age. If mark_read_date is older, mark old stories as read.
        date_delta = UNREAD_CUTOFF
        if date_delta < self.mark_read_date:
            date_delta = self.mark_read_date
        else:
            self.mark_read_date = date_delta

        stories_db = MSharedStory.objects(user_id=self.subscription_user_id,
                                          shared_date__gte=date_delta)
        story_feed_ids = []
        story_ids = []
        for s in stories_db:
            story_feed_ids.append(s['story_feed_id'])
            story_ids.append(s['story_guid'])
        if not story_feed_ids: return

        # usersubs = UserSubscription.objects.filter(user__pk=user.pk, feed__pk__in=story_feed_ids)
        # usersubs_map = dict((sub.feed_id, sub) for sub in usersubs)
        read_stories = MUserStory.objects(user_id=self.user_id,
                                          feed_id__in=story_feed_ids,
                                          story_id__in=story_ids)
        read_stories_ids = [rs.story_id for rs in read_stories]

        oldest_unread_story_date = now
        unread_stories_db = []
        for story in stories_db:
            if (hasattr(story, 'story_guid') and 
                story.story_guid not in read_stories_ids):
                unread_stories_db.append(story)
                if story.story_date < oldest_unread_story_date:
                    oldest_unread_story_date = story.story_date
        stories = Feed.format_stories(unread_stories_db)
        
        classifier_feeds   = list(MClassifierFeed.objects(user_id=self.user_id, social_user_id=self.subscription_user_id))
        classifier_authors = list(MClassifierAuthor.objects(user_id=self.user_id, social_user_id=self.subscription_user_id))
        classifier_titles  = list(MClassifierTitle.objects(user_id=self.user_id, social_user_id=self.subscription_user_id))
        classifier_tags    = list(MClassifierTag.objects(user_id=self.user_id, social_user_id=self.subscription_user_id))

        for story in stories:
            scores = {
                'feed'   : apply_classifier_feeds(classifier_feeds, story['story_feed_id'],
                                                  social_user_id=self.subscription_user_id),
                'author' : apply_classifier_authors(classifier_authors, story),
                'tags'   : apply_classifier_tags(classifier_tags, story),
                'title'  : apply_classifier_titles(classifier_titles, story),
            }
            
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
            logging.info(' ---> [%s] Computing social scores: %s (%s/%s/%s)' % (user.username, self.subscription_user_id, feed_scores['negative'], feed_scores['neutral'], feed_scores['positive']))
            
        return self
        
    
class MSharedStory(mongo.Document):
    user_id                  = mongo.IntField()
    shared_date              = mongo.DateTimeField()
    comments                 = mongo.StringField()
    has_comments             = mongo.BooleanField(default=False)
    story_feed_id            = mongo.IntField()
    story_date               = mongo.DateTimeField()
    story_title              = mongo.StringField(max_length=1024)
    story_content            = mongo.StringField()
    story_content_z          = mongo.BinaryField()
    story_original_content   = mongo.StringField()
    story_original_content_z = mongo.BinaryField()
    story_content_type       = mongo.StringField(max_length=255)
    story_author_name        = mongo.StringField()
    story_permalink          = mongo.StringField()
    story_guid               = mongo.StringField(unique_with=('user_id',))
    story_tags               = mongo.ListField(mongo.StringField(max_length=250))
    
    meta = {
        'collection': 'shared_stories',
        'indexes': [('user_id', '-shared_date'), ('user_id', 'story_feed_id'), 'story_feed_id'],
        'index_drop_dups': True,
        'ordering': ['-shared_date'],
        'allow_inheritance': False,
    }
    
    @property
    def guid_hash(self):
        return hashlib.sha1(self.story_guid).hexdigest()
    
    def save(self, *args, **kwargs):
        if self.story_content:
            self.story_content_z = zlib.compress(self.story_content)
            self.story_content = None
        if self.story_original_content:
            self.story_original_content_z = zlib.compress(self.story_original_content)
            self.story_original_content = None
        
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        share_key = "S:%s:%s" % (self.story_feed_id, self.guid_hash)
        r.sadd(share_key, self.user_id)
        comment_key = "C:%s:%s" % (self.story_feed_id, self.guid_hash)
        if self.has_comments:
            r.sadd(comment_key, self.user_id)
        else:
            r.srem(comment_key, self.user_id)
        
        self.shared_date = datetime.datetime.utcnow()
        
        super(MSharedStory, self).save(*args, **kwargs)
        
        author, _ = MSocialProfile.objects.get_or_create(user_id=self.user_id)
        author.count()
        
    def delete(self, *args, **kwargs):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        share_key = "S:%s:%s" % (self.story_feed_id, self.guid_hash)
        r.srem(share_key, self.user_id)

        super(MSharedStory, self).delete(*args, **kwargs)
        
    @classmethod
    def sync_all_redis(cls):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        for story in cls.objects.all():
            story.sync_redis(redis_conn=r)
            
    def sync_redis(self, redis_conn=None):
        if not redis_conn:
            redis_conn = redis.Redis(connection_pool=settings.REDIS_POOL)
        
        share_key = "S:%s:%s" % (self.story_feed_id, self.guid_hash)
        comment_key = "C:%s:%s" % (self.story_feed_id, self.guid_hash)
        redis_conn.sadd(share_key, self.user_id)
        if self.has_comments:
            redis_conn.sadd(comment_key, self.user_id)
        else:
            redis_conn.srem(comment_key, self.user_id)
        
    def comments_with_author(self, compact=False, full=False):
        comments = {
            'user_id': self.user_id,
            'comments': self.comments,
            'shared_date': relative_timesince(self.shared_date),
        }
        if full or compact:
            author = MSocialProfile.objects.get(user_id=self.user_id)
            comments['author'] = author.to_json(compact=compact, full=full)
        return comments
    
    @classmethod
    def stories_with_comments_and_profiles(cls, stories, user, check_all=False):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        friend_key = "F:%s:F" % (user.pk)
        profile_user_ids = set()
        for story in stories: 
            if check_all or story['comment_count']:
                comment_key = "C:%s:%s" % (story['story_feed_id'], story['guid_hash'])
                if check_all:
                    story['comment_count'] = r.scard(comment_key)
                friends_with_comments = r.sinter(comment_key, friend_key)
                shared_stories = []
                if friends_with_comments:
                    params = {
                        'story_guid': story['id'],
                        'story_feed_id': story['story_feed_id'],
                        'user_id__in': friends_with_comments,
                    }
                    shared_stories = cls.objects.filter(**params)
                story['comments'] = []
                for shared_story in shared_stories:
                    story['comments'].append(shared_story.comments_with_author(compact=True))
                story['comment_count_public'] = story['comment_count'] - len(shared_stories)
                story['comment_count_friends'] = len(shared_stories)
                
            if check_all or story['share_count']:
                share_key = "S:%s:%s" % (story['story_feed_id'], story['guid_hash'])
                if check_all:
                    story['share_count'] = r.scard(share_key)
                friends_with_shares = [int(f) for f in r.sinter(share_key, friend_key)]
                nonfriend_user_ids = list(set(story['share_user_ids']).difference(friends_with_shares))
                profile_user_ids.update(nonfriend_user_ids)
                profile_user_ids.update(friends_with_shares)
                story['shared_by_public'] = nonfriend_user_ids
                story['shared_by_friends'] = friends_with_shares
                story['share_count_public'] = story['share_count'] - len(friends_with_shares)
                story['share_count_friends'] = len(friends_with_shares)

        profiles = MSocialProfile.objects.filter(user_id__in=list(profile_user_ids))
        profiles = [profile.to_json(compact=True) for profile in profiles]
        
        return stories, profiles
        

class MSocialServices(mongo.Document):
    user_id               = mongo.IntField()
    autofollow            = mongo.BooleanField(default=True)
    twitter_uid           = mongo.StringField()
    twitter_access_key    = mongo.StringField()
    twitter_access_secret = mongo.StringField()
    twitter_friend_ids    = mongo.ListField(mongo.StringField())
    twitter_picture_url   = mongo.StringField()
    twitter_username      = mongo.StringField()
    twitter_refresh_date  = mongo.DateTimeField()
    facebook_uid          = mongo.StringField()
    facebook_access_token = mongo.StringField()
    facebook_friend_ids   = mongo.ListField(mongo.StringField())
    facebook_picture_url  = mongo.StringField()
    facebook_refresh_date = mongo.DateTimeField()
    upload_picture_url    = mongo.StringField()
    
    meta = {
        'collection': 'social_services',
        'indexes': ['user_id', 'twitter_friend_ids', 'facebook_friend_ids', 'twitter_uid', 'facebook_uid'],
        'allow_inheritance': False,
    }
    
    def __unicode__(self):
        user = User.objects.get(pk=self.user_id)
        return "%s (Twitter: %s, FB: %s)" % (user.username, self.twitter_uid, self.facebook_uid)
        
    def to_json(self):
        user = User.objects.get(pk=self.user_id)
        return {
            'twitter': {
                'twitter_username': self.twitter_username,
                'twitter_picture_url': self.twitter_picture_url,
                'twitter_uid': self.twitter_uid,
            },
            'facebook': {
                'facebook_uid': self.facebook_uid,
                'facebook_picture_url': self.facebook_picture_url,
            },
            'gravatar': {
                'gravatar_picture_url': "http://www.gravatar.com/avatar/" + \
                                        hashlib.md5(user.email).hexdigest()
            },
            'upload': {
                'upload_picture_url': self.upload_picture_url
            }
        }
    
    def twitter_api(self):
        twitter_consumer_key = settings.TWITTER_CONSUMER_KEY
        twitter_consumer_secret = settings.TWITTER_CONSUMER_SECRET
        auth = tweepy.OAuthHandler(twitter_consumer_key, twitter_consumer_secret)
        auth.set_access_token(self.twitter_access_key, self.twitter_access_secret)
        api = tweepy.API(auth)
        return api
    
    def facebook_api(self):
        graph = facebook.GraphAPI(self.facebook_access_token)
        return graph

    def sync_twitter_friends(self):
        api = self.twitter_api()
        if not api:
            return
            
        friend_ids = list(unicode(friend.id) for friend in tweepy.Cursor(api.friends).items())
        if not friend_ids:
            return
        
        twitter_user = api.me()
        self.twitter_picture_url = twitter_user.profile_image_url
        self.twitter_username = twitter_user.screen_name
        self.twitter_friend_ids = friend_ids
        self.twitter_refreshed_date = datetime.datetime.utcnow()
        self.save()
        
        self.follow_twitter_friends()
        
        profile, _ = MSocialProfile.objects.get_or_create(user_id=self.user_id)
        profile.location = profile.location or twitter_user.location
        profile.bio = profile.bio or twitter_user.description
        profile.website = profile.website or twitter_user.url
        profile.save()
        profile.count()
        if not profile.photo_url or not profile.photo_service:
            self.set_photo('twitter')
        
    def sync_facebook_friends(self):
        graph = self.facebook_api()
        if not graph:
            return

        friends = graph.get_connections("me", "friends")
        if not friends:
            return

        facebook_friend_ids = [unicode(friend["id"]) for friend in friends["data"]]
        self.facebook_friend_ids = facebook_friend_ids
        self.facebook_refresh_date = datetime.datetime.utcnow()
        self.facebook_picture_url = "//graph.facebook.com/%s/picture" % self.facebook_uid
        self.save()
        
        self.follow_facebook_friends()
        
        facebook_user = graph.request('me', args={'fields':'website,bio,location'})
        profile, _ = MSocialProfile.objects.get_or_create(user_id=self.user_id)
        profile.location = profile.location or (facebook_user.get('location') and facebook_user['location']['name'])
        profile.bio = profile.bio or facebook_user.get('bio')
        profile.website = profile.website or facebook_user.get('website')
        profile.save()
        profile.count()
        if not profile.photo_url or not profile.photo_service:
            self.set_photo('facebook')
        
    def follow_twitter_friends(self):
        social_profile, _ = MSocialProfile.objects.get_or_create(user_id=self.user_id)
        following = []
        followers = 0
        
        if self.autofollow:
            # Follow any friends already on NewsBlur
            user_social_services = MSocialServices.objects.filter(twitter_uid__in=self.twitter_friend_ids)
            for user_social_service in user_social_services:
                followee_user_id = user_social_service.user_id
                social_profile.follow_user(followee_user_id)
                following.append(followee_user_id)
        
            # Follow any friends already on NewsBlur
            following_users = MSocialServices.objects.filter(twitter_friend_ids__contains=self.twitter_uid)
            for following_user in following_users:
                if following_user.autofollow:
                    following_user_profile = MSocialProfile.objects.get(user_id=following_user.user_id)
                    following_user_profile.follow_user(self.user_id, check_unfollowed=True)
                    followers += 1
        
        user = User.objects.get(pk=self.user_id)
        logging.user(user, "~BB~FRTwitter import: following ~SB%s~SN with ~SB%s~SN follower-backs" % (following, followers))
        
        return following
        
    def follow_facebook_friends(self):
        social_profile, _ = MSocialProfile.objects.get_or_create(user_id=self.user_id)
        following = []
        followers = 0
        
        if self.autofollow:
            # Follow any friends already on NewsBlur
            user_social_services = MSocialServices.objects.filter(facebook_uid__in=self.facebook_friend_ids)
            for user_social_service in user_social_services:
                followee_user_id = user_social_service.user_id
                social_profile.follow_user(followee_user_id)
                following.append(followee_user_id)
        
            # Friends already on NewsBlur should follow back
            following_users = MSocialServices.objects.filter(facebook_friend_ids__contains=self.facebook_uid)
            for following_user in following_users:
                if following_user.autofollow:
                    following_user_profile = MSocialProfile.objects.get(user_id=following_user.user_id)
                    following_user_profile.follow_user(self.user_id, check_unfollowed=True)
                    followers += 1
        
        user = User.objects.get(pk=self.user_id)
        logging.user(user, "~BB~FRFacebook import: following ~SB%s~SN with ~SB%s~SN follower-backs" % (len(following), followers))
        
        return following
        
    def disconnect_twitter(self):
        self.twitter_uid = None
        self.save()
        
    def disconnect_facebook(self):
        self.facebook_uid = None
        self.save()
        
    def set_photo(self, service):
        profile, _ = MSocialProfile.objects.get_or_create(user_id=self.user_id)
        profile.photo_service = service
        if service == 'twitter':
            profile.photo_url = self.twitter_picture_url
        elif service == 'facebook':
            profile.photo_url = self.facebook_picture_url
        elif service == 'upload':
            profile.photo_url = self.upload_picture_url
        elif service == 'gravatar':
            user = User.objects.get(pk=self.user_id)
            profile.photo_url = "http://www.gravatar.com/avatar/" + \
                                hashlib.md5(user.email).hexdigest()
        profile.save()
