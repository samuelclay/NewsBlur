import datetime
import time
import zlib
import hashlib
import redis
import re
import math
import mongoengine as mongo
import random
from collections import defaultdict
from mongoengine.queryset import OperationError
from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.core.urlresolvers import reverse
from django.template.loader import render_to_string
from django.template.defaultfilters import slugify
from django.core.mail import EmailMultiAlternatives
from apps.reader.models import UserSubscription, MUserStory
from apps.analyzer.models import MClassifierFeed, MClassifierAuthor, MClassifierTag, MClassifierTitle
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds, apply_classifier_authors, apply_classifier_tags
from apps.rss_feeds.models import Feed, MStory
from apps.profile.models import Profile, MSentEmail
from vendor import facebook
from vendor import tweepy
from vendor import pynliner
from utils import log as logging
from utils.feed_functions import relative_timesince
from utils.story_functions import truncate_chars, strip_tags, linkify
from utils import json_functions as json

RECOMMENDATIONS_LIMIT = 5
    
class MSocialProfile(mongo.Document):
    user_id              = mongo.IntField(unique=True)
    username             = mongo.StringField(max_length=30, unique=True)
    email                = mongo.StringField()
    bio                  = mongo.StringField(max_length=160)
    blurblog_title       = mongo.StringField(max_length=256)
    custom_bgcolor       = mongo.StringField(max_length=50)
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
        'index_drop_dups': True,
    }
    
    def __unicode__(self):
        return "%s [%s] following %s/%s, shared %s" % (self.username, self.user_id, 
                                  self.following_count, self.follower_count, self.shared_stories_count)
    
    @classmethod
    def get_user(cls, user_id):
        profile, created = cls.objects.get_or_create(user_id=user_id)
        if created:
            profile.save()
        return profile
        
    def save(self, *args, **kwargs):
        if not self.username:
            self.import_user_fields()
        if not self.subscription_count:
            self.count_follows(skip_save=True)
        if self.bio and len(self.bio) > MSocialProfile.bio.max_length:
            self.bio = self.bio[:80]
        if self.bio:
            self.bio = strip_tags(self.bio)
        if self.website:
            self.website = strip_tags(self.website)
        if self.location:
            self.location = strip_tags(self.location)
        if self.custom_css:
            self.custom_css = strip_tags(self.custom_css)
            
        super(MSocialProfile, self).save(*args, **kwargs)
        if self.user_id not in self.following_user_ids:
            self.follow_user(self.user_id)
            self.count_follows()
            
    @property
    def blurblog_url(self):
        return "http://%s.%s" % (
            self.username_slug,
            Site.objects.get_current().domain.replace('www.', ''))
    
    def recommended_users(self):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        following_key = "F:%s:F" % (self.user_id)
        social_follow_key = "FF:%s:F" % (self.user_id)
        profile_user_ids = []
        
        # Find potential twitter/fb friends
        services = MSocialServices.objects.get(user_id=self.user_id)
        facebook_user_ids = [u.user_id for u in 
                            MSocialServices.objects.filter(facebook_uid__in=services.facebook_friend_ids).only('user_id')]
        twitter_user_ids = [u.user_id for u in 
                            MSocialServices.objects.filter(twitter_uid__in=services.twitter_friend_ids).only('user_id')]
        social_user_ids = facebook_user_ids + twitter_user_ids
        # Find users not currently followed by this user
        r.delete(social_follow_key)
        nonfriend_user_ids = []
        if social_user_ids:
            r.sadd(social_follow_key, *social_user_ids)
            nonfriend_user_ids = r.sdiff(social_follow_key, following_key)
            profile_user_ids = [int(f) for f in nonfriend_user_ids]
            r.delete(social_follow_key)
        
        # Not enough? Grab popular users.
        if len(nonfriend_user_ids) < RECOMMENDATIONS_LIMIT:
            homepage_user = User.objects.get(username=settings.HOMEPAGE_USERNAME)
            suggested_users_list = r.sdiff("F:%s:F" % homepage_user.pk, following_key)
            suggested_users_list = [int(f) for f in suggested_users_list]
            suggested_user_ids = []
            slots_left = min(len(suggested_users_list), RECOMMENDATIONS_LIMIT - len(nonfriend_user_ids))
            for slot in range(slots_left):
                suggested_user_ids.append(random.choice(suggested_users_list))
            profile_user_ids.extend(suggested_user_ids)
        
        # Sort by shared story count
        profiles = MSocialProfile.profiles(profile_user_ids).order_by('-shared_stories_count')
        
        return profiles[:RECOMMENDATIONS_LIMIT]
    
    @property
    def username_slug(self):
        return slugify(self.username)
        
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
                                      for k, v in publishers.items()
                                      if k in feed_titles],
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
    def profile(cls, user_id, include_follows=True):
        try:
            profile = cls.objects.get(user_id=user_id)
        except cls.DoesNotExist:
            return {}
        return profile.to_json(include_follows=True)
        
    @classmethod
    def profiles(cls, user_ids):
        profiles = cls.objects.filter(user_id__in=user_ids)
        return profiles

    @classmethod
    def profile_feeds(cls, user_ids):
        profiles = cls.objects.filter(user_id__in=user_ids)
        profiles = dict((p.user_id, p.feed()) for p in profiles)
        return profiles
        
    @classmethod
    def sync_all_redis(cls):
        for profile in cls.objects.all():
            profile.sync_redis(force=True)
    
    def sync_redis(self, force=False):
        self.following_user_ids = list(set(self.following_user_ids))
        self.save()
        
        for user_id in self.following_user_ids:
            self.follow_user(user_id, force=force)
        
        self.follow_user(self.user_id)
    
    @property
    def title(self):
        return self.blurblog_title if self.blurblog_title else self.username + "'s blurblog"
        
    def feed(self):
        params = self.to_json(compact=True)
        params.update({
            'feed_title': self.title,
            'page_url': reverse('load-social-page', kwargs={'user_id': self.user_id, 'username': self.username_slug}),
            'shared_stories_count': self.shared_stories_count,
        })
        return params
        
    def page(self):
        params = self.to_json(include_follows=True)
        params.update({
            'feed_title': self.title,
            'custom_css': self.custom_css,
        })
        return params
    
    @property
    def profile_photo_url(self):
        if self.photo_url:
            return self.photo_url
        return settings.MEDIA_URL + 'img/reader/default_profile_photo.png'
    
    @property
    def large_photo_url(self):
        photo_url = self.email_photo_url
        if 'graph.facebook.com' in photo_url:
            return photo_url + '?type=large'
        elif 'twimg' in photo_url:
            return photo_url.replace('_normal', '')
        return photo_url
            
    @property
    def email_photo_url(self):
        if self.photo_url:
            if self.photo_url.startswith('//'):
                self.photo_url = 'http:' + self.photo_url
            return self.photo_url
        domain = Site.objects.get_current().domain
        return 'http://' + domain + settings.MEDIA_URL + 'img/reader/default_profile_photo.png'
        
    def to_json(self, compact=False, include_follows=False, common_follows_with_user=None,
                include_settings=False, include_following_user=None):
        domain = Site.objects.get_current().domain
        params = {
            'id': 'social:%s' % self.user_id,
            'user_id': self.user_id,
            'username': self.username,
            'photo_url': self.email_photo_url,
            'location': self.location,
            'num_subscribers': self.follower_count,
            'feed_title': self.title,
            'feed_address': "http://%s%s" % (domain, reverse('shared-stories-rss-feed', 
                                    kwargs={'user_id': self.user_id, 'username': self.username_slug})),
            'feed_link': self.blurblog_url,
        }
        if not compact:
            params.update({
                'bio': self.bio,
                'website': self.website,
                'shared_stories_count': self.shared_stories_count,
                'following_count': self.following_count,
                'follower_count': self.follower_count,
                'popular_publishers': json.decode(self.popular_publishers),
                'stories_last_month': self.stories_last_month,
                'average_stories_per_month': self.average_stories_per_month,
            })
        if include_settings:
            params.update({
                'custom_css': self.custom_css,
                'custom_bgcolor': self.custom_bgcolor,
            })
        if include_follows:
            params.update({
                'photo_service': self.photo_service,
                'following_user_ids': self.following_user_ids_without_self[:48],
                'follower_user_ids': self.follower_user_ids_without_self[:48],
            })
        if common_follows_with_user:
            with_user = MSocialProfile.get_user(common_follows_with_user)
            followers_youknow, followers_everybody = with_user.common_follows(self.user_id, direction='followers')
            following_youknow, following_everybody = with_user.common_follows(self.user_id, direction='following')
            params['followers_youknow'] = followers_youknow[:48]
            params['followers_everybody'] = followers_everybody[:48]
            params['following_youknow'] = following_youknow[:48]
            params['following_everybody'] = following_everybody[:48]
        if include_following_user or common_follows_with_user:
            if not include_following_user:
                include_following_user = common_follows_with_user
            params['followed_by_you'] = bool(self.is_followed_by_user(include_following_user))
            params['following_you'] = bool(self.is_following_user(include_following_user))

        return params
    
    @property
    def following_user_ids_without_self(self):
        if self.user_id in self.following_user_ids:
            return [u for u in self.following_user_ids if u != self.user_id]
        return self.following_user_ids
        
    @property
    def follower_user_ids_without_self(self):
        if self.user_id in self.follower_user_ids:
            return [u for u in self.follower_user_ids if u != self.user_id]
        return self.follower_user_ids
        
    def import_user_fields(self, skip_save=False):
        user = User.objects.get(pk=self.user_id)
        self.username = user.username
        self.email = user.email

    def count_follows(self, skip_save=False):
        self.subscription_count = UserSubscription.objects.filter(user__pk=self.user_id).count()
        self.shared_stories_count = MSharedStory.objects.filter(user_id=self.user_id).count()
        self.following_count = len(self.following_user_ids_without_self)
        self.follower_count = len(self.follower_user_ids_without_self)
        if not skip_save:
            self.save()
        
    def follow_user(self, user_id, check_unfollowed=False, force=False):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        
        if check_unfollowed and user_id in self.unfollowed_user_ids:
            return
        
        logging.debug(" ---> ~FB~SB%s~SN (%s) following %s" % (self.username, self.user_id, user_id))

        if user_id not in self.following_user_ids:
            self.following_user_ids.append(user_id)
        elif not force:
            return
            
        if user_id in self.unfollowed_user_ids:
            self.unfollowed_user_ids.remove(user_id)
        self.count_follows()
        self.save()
        
        if self.user_id == user_id:
            followee = self
        else:
            followee = MSocialProfile.get_user(user_id)
        if self.user_id not in followee.follower_user_ids:
            followee.follower_user_ids.append(self.user_id)
            followee.count_follows()
            followee.save()
        
        following_key = "F:%s:F" % (self.user_id)
        r.sadd(following_key, user_id)
        follower_key = "F:%s:f" % (user_id)
        r.sadd(follower_key, self.user_id)
        
        if self.user_id != user_id:
            MInteraction.new_follow(follower_user_id=self.user_id, followee_user_id=user_id)
            MActivity.new_follow(follower_user_id=self.user_id, followee_user_id=user_id)
        socialsub, _ = MSocialSubscription.objects.get_or_create(user_id=self.user_id, 
                                                                 subscription_user_id=user_id)
        socialsub.needs_unread_recalc = True
        socialsub.save()
        
        if not force:
            from apps.social.tasks import EmailNewFollower
            EmailNewFollower.apply_async(kwargs=dict(follower_user_id=self.user_id,
                                                     followee_user_id=user_id),
                                         countdown=settings.SECONDS_TO_DELAY_CELERY_EMAILS)
        
        return socialsub
    
    def is_following_user(self, user_id):
        return user_id in self.following_user_ids
    
    def is_followed_by_user(self, user_id):
        return user_id in self.follower_user_ids
        
    def unfollow_user(self, user_id):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        
        if not isinstance(user_id, int):
            user_id = int(user_id)
        
        if user_id == self.user_id:
            # Only unfollow other people, not yourself.
            return

        if user_id in self.following_user_ids:
            self.following_user_ids.remove(user_id)
        if user_id not in self.unfollowed_user_ids:
            self.unfollowed_user_ids.append(user_id)
        self.count_follows()
        self.save()
        
        followee = MSocialProfile.get_user(user_id)
        if self.user_id in followee.follower_user_ids:
            followee.follower_user_ids.remove(self.user_id)
            followee.count_follows()
            followee.save()
        
        following_key = "F:%s:F" % (self.user_id)
        r.srem(following_key, user_id)
        follower_key = "F:%s:f" % (user_id)
        r.srem(follower_key, self.user_id)
        
        try:
            MSocialSubscription.objects.get(user_id=self.user_id, subscription_user_id=user_id).delete()
        except MSocialSubscription.DoesNotExist:
            return False
    
    def common_follows(self, user_id, direction='followers'):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        
        my_followers    = "F:%s:%s" % (self.user_id, 'F' if direction == 'followers' else 'F')
        their_followers = "F:%s:%s" % (user_id, 'f' if direction == 'followers' else 'F')
        follows_inter   = r.sinter(their_followers, my_followers)
        follows_diff    = r.sdiff(their_followers, my_followers)
        follows_inter   = [int(f) for f in follows_inter]
        follows_diff    = [int(f) for f in follows_diff]
        
        if user_id in follows_inter:
            follows_inter.remove(user_id)
        if user_id in follows_diff:
            follows_diff.remove(user_id)
        
        return follows_inter, follows_diff
    
    def send_email_for_new_follower(self, follower_user_id):
        user = User.objects.get(pk=self.user_id)
        if follower_user_id not in self.follower_user_ids:
            logging.user(user, "~BB~FMNo longer being followed by %s" % follower_user_id)
            return
        if not user.email:
            logging.user(user, "~BB~FMNo email to send to, skipping.")
            return
        elif not user.profile.send_emails:
            logging.user(user, "~BB~FMDisabled emails, skipping.")
            return
        if self.user_id == follower_user_id:
            logging.user(user, "~BB~FMDisabled emails, skipping.")
            return
        
        emails_sent = MSentEmail.objects.filter(receiver_user_id=user.pk,
                                                sending_user_id=follower_user_id,
                                                email_type='new_follower')
        day_ago = datetime.datetime.now() - datetime.timedelta(days=1)
        for email in emails_sent:
            if email.date_sent > day_ago:
                logging.user(user, "~BB~SK~FMNot sending new follower email, already sent before. NBD.")
                return
        
        follower_profile = MSocialProfile.get_user(follower_user_id)
        common_followers, _ = self.common_follows(follower_user_id, direction='followers')
        common_followings, _ = self.common_follows(follower_user_id, direction='following')
        if self.user_id in common_followers:
            common_followers.remove(self.user_id)
        if self.user_id in common_followings:
            common_followings.remove(self.user_id)
        common_followers = MSocialProfile.profiles(common_followers)
        common_followings = MSocialProfile.profiles(common_followings)
        
        data = {
            'user': user,
            'follower_profile': follower_profile,
            'common_followers': common_followers,
            'common_followings': common_followings,
        }
        
        text    = render_to_string('mail/email_new_follower.txt', data)
        html    = render_to_string('mail/email_new_follower.xhtml', data)
        subject = "%s is now following your Blurblog on NewsBlur!" % follower_profile.username
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user.username, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send()
        
        MSentEmail.record(receiver_user_id=user.pk, sending_user_id=follower_user_id,
                          email_type='new_follower')
                
        logging.user(user, "~BB~FM~SBSending email for new follower: %s" % follower_profile.username)
            
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
        self.average_stories_per_month = total / max(1, month_count)
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
    follow_date = mongo.DateTimeField(default=datetime.datetime.utcnow())
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
    def feeds(cls, user_id=None, subscription_user_id=None, calculate_all_scores=False,
              update_counts=False, *args, **kwargs):
        print locals()
        params = {
            'user_id': user_id,
        }
        if subscription_user_id:
            params["subscription_user_id"] = subscription_user_id
        social_subs = cls.objects.filter(**params)

        social_feeds = []
        if social_subs:
            if calculate_all_scores:
                for s in social_subs: s.calculate_feed_scores()

            # Fetch user profiles of subscriptions
            social_user_ids = [sub.subscription_user_id for sub in social_subs]
            social_profiles = MSocialProfile.profile_feeds(social_user_ids)
            for social_sub in social_subs:
                user_id = social_sub.subscription_user_id
                if social_profiles[user_id]['shared_stories_count'] <= 0:
                    continue
                if update_counts and social_sub.needs_unread_recalc:
                    social_sub.calculate_feed_scores()
                    
                # Combine subscription read counts with feed/user info
                feed = dict(social_sub.to_json().items() + social_profiles[user_id].items())
                social_feeds.append(feed)

        return social_feeds
    
    @classmethod
    def feeds_with_updated_counts(cls, user, social_feed_ids=None):
        feeds = {}
        
        # Get social subscriptions for user
        user_subs = cls.objects.filter(user_id=user.pk)
        if social_feed_ids:
            social_user_ids = [int(f.replace('social:', '')) for f in social_feed_ids]
            user_subs = user_subs.filter(subscription_user_id__in=social_user_ids)
            profiles = MSocialProfile.objects.filter(user_id__in=social_user_ids)
            profiles = dict((p.user_id, p) for p in profiles)
        
        UNREAD_CUTOFF = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)

        for i, sub in enumerate(user_subs):
            # Count unreads if subscription is stale.
            if (sub.needs_unread_recalc or 
                (sub.unread_count_updated and
                 sub.unread_count_updated < UNREAD_CUTOFF) or 
                (sub.oldest_unread_story_date and
                 sub.oldest_unread_story_date < UNREAD_CUTOFF)):
                sub = sub.calculate_feed_scores(silent=True)

            feed_id = "social:%s" % sub.subscription_user_id
            feeds[feed_id] = {
                'ps': sub.unread_count_positive,
                'nt': sub.unread_count_neutral,
                'ng': sub.unread_count_negative,
                'id': feed_id,
            }
            if social_feed_ids and sub.subscription_user_id in profiles:
                feeds[feed_id]['shared_stories_count'] = profiles[sub.subscription_user_id].shared_stories_count

        return feeds
        
    def to_json(self):
        return {
            'user_id': self.user_id,
            'subscription_user_id': self.subscription_user_id,
            'nt': self.unread_count_neutral,
            'ps': self.unread_count_positive,
            'ng': self.unread_count_negative,
            'is_trained': self.is_trained,
            'feed_opens': self.feed_opens,
        }
    
    def get_stories(self, offset=0, limit=6, order='newest', read_filter='all', withscores=False):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)
        ignore_user_stories = False
        
        stories_key         = 'B:%s' % (self.subscription_user_id)
        read_stories_key    = 'RS:%s' % (self.user_id)
        unread_stories_key  = 'UB:%s:%s' % (self.user_id, self.subscription_user_id)

        if not r.exists(stories_key):
            return []
        elif read_filter != 'unread' or not r.exists(read_stories_key):
            ignore_user_stories = True
            unread_stories_key = stories_key
        else:
            r.sdiffstore(unread_stories_key, stories_key, read_stories_key)

        sorted_stories_key          = 'zB:%s' % (self.subscription_user_id)
        unread_ranked_stories_key   = 'zUB:%s:%s' % (self.user_id, self.subscription_user_id)
        r.zinterstore(unread_ranked_stories_key, [sorted_stories_key, unread_stories_key])
        
        current_time    = int(time.time() + 60*60*24)
        mark_read_time  = int(time.mktime(self.mark_read_date.timetuple()))
        if order == 'oldest':
            byscorefunc = r.zrangebyscore
            min_score = mark_read_time
            max_score = current_time
        else:
            byscorefunc = r.zrevrangebyscore
            min_score = current_time
            now = datetime.datetime.now()
            two_weeks_ago = now - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
            max_score = int(time.mktime(two_weeks_ago.timetuple()))-1000
        story_ids = byscorefunc(unread_ranked_stories_key, min_score, 
                                  max_score, start=offset, num=limit,
                                  withscores=withscores)

        r.expire(unread_ranked_stories_key, 24*60*60)

        if not ignore_user_stories:
            r.delete(unread_stories_key)
        print "User_id: %s, sub user: %s, order: %s, filter: %s, stories: %s, min: %s, max: %s" % (self.user_id, self.subscription_user_id, order, read_filter, story_ids, min_score, max_score)
        return [story_id for story_id in story_ids if story_id and story_id != 'None']
        
    @classmethod
    def feed_stories(cls, user_id, social_user_ids, offset=0, limit=6, order='newest', read_filter='all'):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)
        
        if order == 'oldest':
            range_func = r.zrange
        else:
            range_func = r.zrevrange
            
        if not isinstance(social_user_ids, list):
            social_user_ids = [social_user_ids]

        unread_ranked_stories_keys  = 'zU:%s' % (user_id)
        if offset and r.exists(unread_ranked_stories_keys):
            story_guids = range_func(unread_ranked_stories_keys, offset, limit, withscores=True)
            if story_guids:
                return zip(*story_guids)
            else:
                return [], []
        else:
            r.delete(unread_ranked_stories_keys)

        for social_user_id in social_user_ids:
            us = cls.objects.get(user_id=user_id, subscription_user_id=social_user_id)
            story_guids = us.get_stories(offset=0, limit=100, 
                                         # order=order, read_filter=read_filter, 
                                         withscores=True)
            if story_guids:
                r.zadd(unread_ranked_stories_keys, **dict(story_guids))
            
        story_guids = range_func(unread_ranked_stories_keys, offset, limit, withscores=True)
        r.expire(unread_ranked_stories_keys, 24*60*60)
        
        if story_guids:
            return zip(*story_guids)
        else:
            return [], []
        
    def mark_story_ids_as_read(self, story_ids, feed_id=None, request=None):
        data = dict(code=0, payload=story_ids)
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        
        if not request:
            request = User.objects.get(pk=self.user_id)
    
        if not self.needs_unread_recalc:
            self.needs_unread_recalc = True
            self.save()
    
        sub_username = MSocialProfile.get_user(self.subscription_user_id).username

        if len(story_ids) > 1:
            logging.user(request, "~FYRead %s stories in social subscription: %s" % (len(story_ids), sub_username))
        else:
            logging.user(request, "~FYRead story in social subscription: %s" % (sub_username))
        
        for story_id in set(story_ids):
            story = MSharedStory.objects.get(user_id=self.subscription_user_id, story_guid=story_id)
            now = datetime.datetime.utcnow()
            date = now if now > story.story_date else story.story_date # For handling future stories
            if not feed_id:
                feed_id = story.story_feed_id
            m = MUserStory(user_id=self.user_id, 
                           feed_id=feed_id, read_date=date, 
                           story_id=story.story_guid, story_date=story.story_date)
            try:
                m.save()
            except OperationError:
                logging.user(request, "~FRAlready saved read story: %s" % story.story_guid)
                continue
            
            # Find other social feeds with this story to update their counts
            friend_key = "F:%s:F" % (self.user_id)
            share_key = "S:%s:%s" % (feed_id, story.guid_hash)
            friends_with_shares = [int(f) for f in r.sinter(share_key, friend_key)]
            if self.user_id in friends_with_shares:
                friends_with_shares.remove(self.user_id)
            if friends_with_shares:
                socialsubs = MSocialSubscription.objects.filter(user_id=self.user_id,
                                                                subscription_user_id__in=friends_with_shares)
                for socialsub in socialsubs:
                    if not socialsub.needs_unread_recalc:
                        socialsub.needs_unread_recalc = True
                        socialsub.save()
                    # XXX TODO: Real-time notification, just for this user
            
            # Also count on original subscription
            usersubs = UserSubscription.objects.filter(user=self.user_id, feed=feed_id)
            if usersubs:
                usersub = usersubs[0]
                if not usersub.needs_unread_recalc:
                    usersub.needs_unread_recalc = True
                    usersub.save()
                # XXX TODO: Real-time notification, just for this user
        return data
        
    def mark_feed_read(self):
        latest_story_date = datetime.datetime.utcnow()
        UNREAD_CUTOFF     = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)

        # Use the latest story to get last read time.
        latest_shared_story = MSharedStory.objects(user_id=self.subscription_user_id,
                                                   shared_date__gte=UNREAD_CUTOFF
                              ).order_by('shared_date').only('shared_date').first()
        if latest_shared_story:
            latest_story_date = latest_shared_story['shared_date'] + datetime.timedelta(seconds=1)
                
        self.last_read_date = latest_story_date
        self.mark_read_date = UNREAD_CUTOFF
        self.unread_count_negative = 0
        self.unread_count_positive = 0
        self.unread_count_neutral = 0
        self.unread_count_updated = datetime.datetime.utcnow()
        self.oldest_unread_story_date = latest_story_date
        self.needs_unread_recalc = False
        
        # Manually mark all shared stories as read.
        stories = MSharedStory.objects.filter(user_id=self.subscription_user_id,
                                              shared_date__gte=UNREAD_CUTOFF).only('story_guid')
        story_ids = [s.story_guid for s in stories]
        self.mark_story_ids_as_read(story_ids)
        
        # Cannot delete these stories, since the original feed may not be read. 
        # Just go 2 weeks back.
        # UNREAD_CUTOFF = now - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
        # MUserStory.delete_marked_as_read_stories(self.user_id, self.feed_id, mark_read_date=UNREAD_CUTOFF)
                
        self.save()
    
    def calculate_feed_scores(self, silent=False):
        if not self.needs_unread_recalc:
            return self
            
        now = datetime.datetime.now()
        UNREAD_CUTOFF = now - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
        user = User.objects.get(pk=self.user_id)

        if user.profile.last_seen_on < UNREAD_CUTOFF:
            # if not silent:
            #     logging.info(' ---> [%s] SKIPPING Computing scores: %s (1 week+)' % (self.user, self.feed))
            return self
            
        feed_scores = dict(negative=0, neutral=0, positive=0)
        
        # Two weeks in age. If mark_read_date is older, mark old stories as read.
        date_delta = UNREAD_CUTOFF
        if date_delta < self.mark_read_date:
            date_delta = self.mark_read_date
        else:
            self.mark_read_date = date_delta

        stories_db = MSharedStory.objects(user_id=self.subscription_user_id,
                                          shared_date__gte=date_delta)
        story_feed_ids = set()
        story_ids = []
        for s in stories_db:
            story_feed_ids.add(s['story_feed_id'])
            story_ids.append(s['story_guid'])
        story_feed_ids = list(story_feed_ids)
        usersubs = UserSubscription.objects.filter(user__pk=self.user_id, feed__pk__in=story_feed_ids)
        usersubs_map = dict((sub.feed_id, sub) for sub in usersubs)

        # usersubs = UserSubscription.objects.filter(user__pk=user.pk, feed__pk__in=story_feed_ids)
        # usersubs_map = dict((sub.feed_id, sub) for sub in usersubs)
        read_stories_ids = []
        if story_feed_ids:
            read_stories = MUserStory.objects(user_id=self.user_id,
                                              feed_id__in=story_feed_ids,
                                              story_id__in=story_ids)
            read_stories_ids = [rs.story_id for rs in read_stories]

        oldest_unread_story_date = now
        unread_stories_db = []
        for story in stories_db:
            if getattr(story, 'story_guid', None) in read_stories_ids:
                continue
            feed_id = story.story_feed_id
            if usersubs_map.get(feed_id) and story.story_date < usersubs_map[feed_id].mark_read_date:
                continue
                
            unread_stories_db.append(story)
            if story.story_date < oldest_unread_story_date:
                oldest_unread_story_date = story.story_date
        stories = Feed.format_stories(unread_stories_db)
        
        classifier_feeds   = list(MClassifierFeed.objects(user_id=self.user_id, social_user_id=self.subscription_user_id))
        classifier_authors = list(MClassifierAuthor.objects(user_id=self.user_id, social_user_id=self.subscription_user_id))
        classifier_titles  = list(MClassifierTitle.objects(user_id=self.user_id, social_user_id=self.subscription_user_id))
        classifier_tags    = list(MClassifierTag.objects(user_id=self.user_id, social_user_id=self.subscription_user_id))
        # Merge with feed specific classifiers
        if story_feed_ids:
            classifier_feeds   = classifier_feeds + list(MClassifierFeed.objects(user_id=self.user_id,
                                                                                 feed_id__in=story_feed_ids))
            classifier_authors = classifier_authors + list(MClassifierAuthor.objects(user_id=self.user_id,
                                                                                     feed_id__in=story_feed_ids))
            classifier_titles  = classifier_titles + list(MClassifierTitle.objects(user_id=self.user_id,
                                                                                   feed_id__in=story_feed_ids))
            classifier_tags    = classifier_tags + list(MClassifierTag.objects(user_id=self.user_id,
                                                                               feed_id__in=story_feed_ids))

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
    
    @classmethod
    def mark_dirty_sharing_story(cls, user_id, story_feed_id, story_guid_hash):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        
        friends_key = "F:%s:F" % (user_id)
        share_key = "S:%s:%s" % (story_feed_id, story_guid_hash)
        following_user_ids = r.sinter(friends_key, share_key)
        following_user_ids = [int(f) for f in following_user_ids]
        if not following_user_ids:
            return None

        social_subs = cls.objects.filter(user_id=user_id, subscription_user_id__in=following_user_ids)
        for social_sub in social_subs:
            social_sub.needs_unread_recalc = True
            social_sub.save()
        return social_subs

class MCommentReply(mongo.EmbeddedDocument):
    reply_id      = mongo.ObjectIdField()
    user_id       = mongo.IntField()
    publish_date  = mongo.DateTimeField()
    comments      = mongo.StringField()
    email_sent    = mongo.BooleanField(default=False)
    liking_users  = mongo.ListField(mongo.IntField())
    
    def to_json(self):
        reply = {
            'reply_id': self.reply_id,
            'user_id': self.user_id,
            'publish_date': relative_timesince(self.publish_date),
            'date': self.publish_date,
            'comments': self.comments,
        }
        return reply
        
    meta = {
        'ordering': ['publish_date'],
        'id_field': 'reply_id',
        'allow_inheritance': False,
    }


class MSharedStory(mongo.Document):
    user_id                  = mongo.IntField()
    shared_date              = mongo.DateTimeField()
    comments                 = mongo.StringField()
    has_comments             = mongo.BooleanField(default=False)
    has_replies              = mongo.BooleanField(default=False)
    replies                  = mongo.ListField(mongo.EmbeddedDocumentField(MCommentReply))
    source_user_id           = mongo.IntField()
    story_db_id              = mongo.ObjectIdField()
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
    posted_to_services       = mongo.ListField(mongo.StringField(max_length=20))
    mute_email_users         = mongo.ListField(mongo.IntField())
    liking_users             = mongo.ListField(mongo.IntField())
    emailed_reshare          = mongo.BooleanField(default=False)
    emailed_replies          = mongo.ListField(mongo.ObjectIdField())
    
    meta = {
        'collection': 'shared_stories',
        'indexes': [('user_id', '-shared_date'), ('user_id', 'story_feed_id'), 
                    ('user_id', 'story_db_id'),
                    'shared_date', 'story_guid', 'story_feed_id'],
        'index_drop_dups': True,
        'ordering': ['shared_date'],
        'allow_inheritance': False,
    }

    def __unicode__(self):
        user = User.objects.get(pk=self.user_id)
        return "%s: %s (%s)%s%s" % (user.username, self.story_title[:20], self.story_feed_id, ': ' if self.has_comments else '', self.comments[:20])

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
        
        self.comments = linkify(strip_tags(self.comments))
        for reply in self.replies:
            reply.comments = linkify(strip_tags(reply.comments))
        
        self.shared_date = self.shared_date or datetime.datetime.utcnow()
        self.has_replies = bool(len(self.replies))

        super(MSharedStory, self).save(*args, **kwargs)
        
        author = MSocialProfile.get_user(self.user_id)
        author.count_follows()
        
        self.sync_redis()
        
        MActivity.new_shared_story(user_id=self.user_id, source_user_id=self.source_user_id, 
                                   story_title=self.story_title, 
                                   comments=self.comments, story_feed_id=self.story_feed_id,
                                   story_id=self.story_guid, share_date=self.shared_date)
        
    def delete(self, *args, **kwargs):
        MActivity.remove_shared_story(user_id=self.user_id, story_feed_id=self.story_feed_id,
                                      story_id=self.story_guid)

        self.remove_from_redis()

        super(MSharedStory, self).delete(*args, **kwargs)
    
    def ensure_story_db_id(self, save=True):
        if not self.story_db_id:
            story, _ = MStory.find_story(self.story_feed_id, self.story_guid)
            if story:
                logging.debug(" ***> Shared story didn't have story_db_id. Adding found id: %s" % story.id)
                self.story_db_id = story.id
                if save:
                    self.save()
                
    def set_source_user_id(self, source_user_id):
        if source_user_id == self.user_id:
            return
            
        def find_source(source_user_id, seen_user_ids):
            parent_shared_story = MSharedStory.objects.filter(user_id=source_user_id, 
                                                              story_guid=self.story_guid, 
                                                              story_feed_id=self.story_feed_id).limit(1)
            if parent_shared_story and parent_shared_story[0].source_user_id:
                user_id = parent_shared_story[0].source_user_id
                if user_id in seen_user_ids:
                    return source_user_id
                else:
                    seen_user_ids.append(user_id)
                    return find_source(user_id, seen_user_ids)
            else:
                return source_user_id
        
        if source_user_id:
            source_user_id = find_source(source_user_id, [])
            if source_user_id == self.user_id:
                return
            elif not self.source_user_id or source_user_id != self.source_user_id:
                self.source_user_id = source_user_id
                logging.debug("   ---> Re-share from %s." % source_user_id)
                self.save()
                
                MInteraction.new_reshared_story(user_id=self.source_user_id,
                                                reshare_user_id=self.user_id,
                                                comments=self.comments,
                                                story_title=self.story_title,
                                                story_feed_id=self.story_feed_id,
                                                story_id=self.story_guid)
    
    def mute_for_user(self, user_id):
        if user_id not in self.mute_email_users:
            self.mute_email_users.append(user_id)
            self.save()
        
    @classmethod
    def switch_feed(cls, original_feed_id, duplicate_feed_id):
        shared_stories = cls.objects.filter(story_feed_id=duplicate_feed_id)
        logging.info(" ---> %s shared stories" % shared_stories.count())
        for story in shared_stories:
            story.story_feed_id = original_feed_id
            story.save()
        
    @classmethod
    def collect_popular_stories(cls, cutoff=None):
        from apps.statistics.models import MStatistics
        shared_stories_count = sum(json.decode(MStatistics.get('stories_shared')))
        cutoff = cutoff or max(math.floor(.05 * shared_stories_count), 3)
        today = datetime.datetime.now() - datetime.timedelta(days=1)
        
        map_f = """
            function() {
                emit(this.story_guid, {
                    'guid': this.story_guid, 
                    'feed_id': this.story_feed_id, 
                    'count': 1
                });
            }
        """
        reduce_f = """
            function(key, values) {
                var r = {'guid': key, 'count': 0};
                for (var i=0; i < values.length; i++) {
                    r.feed_id = values[i].feed_id;
                    r.count += 1;
                }
                return r;
            }
        """
        finalize_f = """
            function(key, value) {
                if (value.count >= %(cutoff)s) {
                    return value;
                }
            }
        """ % {'cutoff': cutoff}
        res = cls.objects(shared_date__gte=today).map_reduce(map_f, reduce_f, 
                                                             finalize_f=finalize_f, 
                                                             output='inline')
        stories = dict([(r.key, r.value) for r in res if r.value])
        return stories, cutoff
        
    @classmethod
    def share_popular_stories(cls, cutoff=None, verbose=True):
        publish_new_stories = False
        popular_profile = MSocialProfile.objects.get(username='popular')
        popular_user = User.objects.get(pk=popular_profile.user_id)
        shared_stories_today, cutoff = cls.collect_popular_stories(cutoff=cutoff)
        for guid, story_info in shared_stories_today.items():
            story, _ = MStory.find_story(story_info['feed_id'], story_info['guid'])
            if not story:
                logging.user(popular_user, "~FRPopular stories, story not found: %s" % story_info)
                continue

            story_db = dict([(k, v) for k, v in story._data.items() 
                                if k is not None and v is not None])
            story_values = {
                'user_id': popular_profile.user_id,
                'story_guid': story_db['story_guid'],
                'story_feed_id': story_db['story_feed_id'],
                'defaults': story_db,
            }
            shared_story, created = MSharedStory.objects.get_or_create(**story_values)
            if created:
                publish_new_stories = True
            if verbose and created:
                logging.user(popular_user, "~FCSharing: ~SB~FM%s (%s shares, %s min)" % (
                    story.story_title[:50],
                    story_info['count'],
                    cutoff))

        if publish_new_stories:
            socialsubs = MSocialSubscription.objects.filter(subscription_user_id=popular_user.pk)
            for socialsub in socialsubs:
                socialsub.needs_unread_recalc = True
                socialsub.save()
            shared_story.publish_update_to_subscribers()
            
    @classmethod
    def sync_all_redis(cls):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        s = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)
        for story in cls.objects.all():
            story.sync_redis_shares(redis_conn=r)
            story.sync_redis_story(redis_conn=s)
    
    def sync_redis(self):
        self.sync_redis_shares()
        self.sync_redis_story()

    def sync_redis_shares(self, redis_conn=None):
        if not redis_conn:
            redis_conn = redis.Redis(connection_pool=settings.REDIS_POOL)
        
        share_key   = "S:%s:%s" % (self.story_feed_id, self.guid_hash)
        comment_key = "C:%s:%s" % (self.story_feed_id, self.guid_hash)
        redis_conn.sadd(share_key, self.user_id)
        if self.has_comments:
            redis_conn.sadd(comment_key, self.user_id)
        else:
            redis_conn.srem(comment_key, self.user_id)

    def sync_redis_story(self, redis_conn=None):
        if not redis_conn:
            redis_conn = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)
        
        if not self.story_db_id:
            self.ensure_story_db_id(save=True)
            
        if self.story_db_id:
            redis_conn.sadd('B:%s' % self.user_id, self.story_db_id)
            redis_conn.zadd('zB:%s' % self.user_id, self.story_db_id,
                            time.mktime(self.shared_date.timetuple()))
    
    def remove_from_redis(self):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        share_key = "S:%s:%s" % (self.story_feed_id, self.guid_hash)
        r.srem(share_key, self.user_id)

        comment_key = "C:%s:%s" % (self.story_feed_id, self.guid_hash)
        r.srem(comment_key, self.user_id)

        s = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)
        s.srem('B:%s' % self.user_id, self.story_db_id)
        s.zrem('zB:%s' % self.user_id, self.story_db_id)

    def publish_update_to_subscribers(self):
        try:
            r = redis.Redis(connection_pool=settings.REDIS_POOL)
            feed_id = "social:%s" % self.user_id
            listeners_count = r.publish(feed_id, 'story:new')
            if listeners_count:
                logging.debug("   ---> ~FMPublished to %s subscribers" % (listeners_count))
        except redis.ConnectionError:
            logging.debug("   ***> ~BMRedis is unavailable for real-time.")

    def comments_with_author(self):
        comments = {
            'id': self.id,
            'user_id': self.user_id,
            'comments': self.comments,
            'shared_date': relative_timesince(self.shared_date),
            'date': self.shared_date,
            'replies': [reply.to_json() for reply in self.replies],
            'liking_users': self.liking_users,
            'source_user_id': self.source_user_id,
        }
        return comments
    
    def comment_with_author_and_profiles(self):
        comment = self.comments_with_author()
        profile_user_ids = set([comment['user_id']])
        reply_user_ids = [reply['user_id'] for reply in comment['replies']]
        profile_user_ids = profile_user_ids.union(reply_user_ids)
        profile_user_ids = profile_user_ids.union(comment['liking_users'])
        if comment['source_user_id']:
            profile_user_ids.add(comment['source_user_id'])
        profiles = MSocialProfile.objects.filter(user_id__in=list(profile_user_ids))
        profiles = [profile.to_json(compact=True) for profile in profiles]

        return comment, profiles
        
    @classmethod
    def stories_with_comments_and_profiles(cls, stories, user_id, check_all=False, public=False):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        friend_key = "F:%s:F" % (user_id)
        profile_user_ids = set()
        for story in stories: 
            story['friend_comments'] = []
            story['public_comments'] = []
            story['reply_count'] = 0
            if check_all or story['comment_count']:
                comment_key = "C:%s:%s" % (story['story_feed_id'], story['guid_hash'])
                story['comment_count'] = r.scard(comment_key)
                friends_with_comments = [int(f) for f in r.sinter(comment_key, friend_key)]
                sharer_user_ids = [int(f) for f in r.smembers(comment_key)]
                shared_stories = []
                if sharer_user_ids:
                    params = {
                        'story_guid': story['id'],
                        'story_feed_id': story['story_feed_id'],
                        'user_id__in': sharer_user_ids,
                    }
                    shared_stories = cls.objects.filter(**params)
                for shared_story in shared_stories:
                    comments = shared_story.comments_with_author()
                    story['reply_count'] += len(comments['replies'])
                    if shared_story.user_id in friends_with_comments:
                        story['friend_comments'].append(comments)
                    else:
                        story['public_comments'].append(comments)
                    if comments.get('source_user_id'):
                        profile_user_ids.add(comments['source_user_id'])
                    if comments.get('liking_users'):
                        profile_user_ids = profile_user_ids.union(comments['liking_users'])
                all_comments = story['friend_comments'] + story['public_comments']
                profile_user_ids = profile_user_ids.union([reply['user_id'] 
                                                           for c in all_comments
                                                           for reply in c['replies']])
                if story.get('source_user_id'):
                    profile_user_ids.add(story['source_user_id'])
                story['comment_count_friends'] = len(friends_with_comments)
                story['comment_count_public'] = story['comment_count'] - len(friends_with_comments)
                
            if check_all or story['share_count']:
                share_key = "S:%s:%s" % (story['story_feed_id'], story['guid_hash'])
                story['share_count'] = r.scard(share_key)
                friends_with_shares = [int(f) for f in r.sinter(share_key, friend_key)]
                nonfriend_user_ids = [int(f) for f in r.sdiff(share_key, friend_key)]
                profile_user_ids.update(nonfriend_user_ids)
                profile_user_ids.update(friends_with_shares)
                story['commented_by_public']  = [c['user_id'] for c in story['public_comments']]
                story['commented_by_friends'] = [c['user_id'] for c in story['friend_comments']]
                story['shared_by_public']     = list(set(nonfriend_user_ids) - 
                                                    set(story['commented_by_public']))
                story['shared_by_friends']    = list(set(friends_with_shares) - 
                                                     set(story['commented_by_friends']))
                story['share_count_public']  = story['share_count'] - len(friends_with_shares)
                story['share_count_friends'] = len(friends_with_shares)
                story['friend_user_ids'] = list(set(story['commented_by_friends'] + story['shared_by_friends']))
                story['public_user_ids'] = list(set(story['commented_by_public'] + story['shared_by_public']))
                if story.get('source_user_id'):
                    profile_user_ids.add(story['source_user_id'])
            
        profiles = MSocialProfile.objects.filter(user_id__in=list(profile_user_ids))
        profiles = [profile.to_json(compact=True) for profile in profiles]

        return stories, profiles
    
    @staticmethod
    def attach_users_to_stories(stories, profiles):
        profiles = dict([(p['user_id'], p) for p in profiles])
        for s, story in enumerate(stories):
            for u, user_id in enumerate(story['shared_by_friends']):
                stories[s]['shared_by_friends'][u] = profiles[user_id]
            for u, user_id in enumerate(story['shared_by_public']):
                stories[s]['shared_by_public'][u] = profiles[user_id]
            for comment_set in ['friend_comments', 'public_comments']:
                for c, comment in enumerate(story[comment_set]):
                    stories[s][comment_set][c]['user'] = profiles[comment['user_id']]
                    if comment['source_user_id']:
                        stories[s][comment_set][c]['source_user'] = profiles[comment['source_user_id']]
                    for r, reply in enumerate(comment['replies']):
                        if reply['user_id'] in profiles:
                            stories[s][comment_set][c]['replies'][r]['user'] = profiles[reply['user_id']]

        return stories
    
    @staticmethod
    def attach_users_to_comment(comment, profiles):
        profiles = dict([(p['user_id'], p) for p in profiles])
        comment['user'] = profiles[comment['user_id']]
        if comment['source_user_id']:
            comment['source_user'] = profiles[comment['source_user_id']]
        for r, reply in enumerate(comment['replies']):
            comment['replies'][r]['user'] = profiles[reply['user_id']]

        return comment
        
    def add_liking_user(self, user_id):
        if user_id not in self.liking_users:
            self.liking_users.append(user_id)
            self.save()

    def remove_liking_user(self, user_id):
        if user_id in self.liking_users:
            self.liking_users.remove(user_id)
            self.save()
        
    def blurblog_permalink(self):
        profile = MSocialProfile.get_user(self.user_id)
        return "%s/story/%s" % (
            profile.blurblog_url,
            self.guid_hash[:6]
        )
    
    def generate_post_to_service_message(self):
        message = self.comments
        if not message or len(message) < 1:
            message = self.story_title
        
        message = truncate_chars(message, 116)
        message += " " + self.blurblog_permalink()
        
        return message
        
    def post_to_service(self, service):
        if service in self.posted_to_services:
            return

        posted = False
        message = self.generate_post_to_service_message()
        social_service = MSocialServices.objects.get(user_id=self.user_id)
        user = User.objects.get(pk=self.user_id)
        
        logging.user(user, "~BM~FBPosting to %s: ~SB%s" % (service, message))
        
        if service == 'twitter':
            posted = social_service.post_to_twitter(message)
        elif service == 'facebook':
            posted = social_service.post_to_facebook(message)
        
        if posted:
            self.posted_to_services.append(service)
            self.save()
            
    def notify_user_ids(self, include_parent=True):
        user_ids = set()
        for reply in self.replies:
            if reply.user_id not in self.mute_email_users:
                user_ids.add(reply.user_id)
            
        if include_parent and self.user_id not in self.mute_email_users:
            user_ids.add(self.user_id)
        
        return list(user_ids)
    
    def reply_for_id(self, reply_id):
        for reply in self.replies:
            if reply.reply_id == reply_id:
                return reply
                
    def send_emails_for_new_reply(self, reply_id):
        if reply_id in self.emailed_replies:
            logging.debug(" ***> Already sent reply email: %s on %s" % (reply_id, self))
            return

        reply = self.reply_for_id(reply_id)
        if not reply:
            logging.debug(" ***> Reply doesn't exist: %s on %s" % (reply_id, self))
            return
            
        notify_user_ids = self.notify_user_ids()
        if reply.user_id in notify_user_ids:
            notify_user_ids.remove(reply.user_id)
        reply_user = User.objects.get(pk=reply.user_id)
        reply_user_profile = MSocialProfile.get_user(reply.user_id)
        sent_emails = 0

        story_feed = Feed.objects.get(pk=self.story_feed_id)
        comment = self.comments_with_author()
        profile_user_ids = set([comment['user_id']])
        reply_user_ids = list(r['user_id'] for r in comment['replies'])
        profile_user_ids = profile_user_ids.union(reply_user_ids)
        if self.source_user_id:
            profile_user_ids.add(self.source_user_id)
        profiles = MSocialProfile.objects.filter(user_id__in=list(profile_user_ids))
        profiles = [profile.to_json(compact=True) for profile in profiles]
        comment = MSharedStory.attach_users_to_comment(comment, profiles)
        
        for user_id in notify_user_ids:
            user = User.objects.get(pk=user_id)

            if not user.email or not user.profile.send_emails:
                if not user.email:
                    logging.user(user, "~BB~FMNo email to send to, skipping.")
                elif not user.profile.send_emails:
                    logging.user(user, "~BB~FMDisabled emails, skipping.")
                continue
            
            mute_url = "http://%s%s" % (
                Site.objects.get_current().domain,
                reverse('social-mute-story', kwargs={
                    'secret_token': user.profile.secret_token,
                    'shared_story_id': self.id,
                })
            )
            data = {
                'reply_user_profile': reply_user_profile,
                'comment': comment,
                'shared_story': self,
                'story_feed': story_feed,
                'mute_url': mute_url,
            }
        
            text    = render_to_string('mail/email_reply.txt', data)
            html    = pynliner.fromString(render_to_string('mail/email_reply.xhtml', data))
            subject = "%s replied to you on \"%s\" on NewsBlur" % (reply_user.username, self.story_title)
            msg     = EmailMultiAlternatives(subject, text, 
                                             from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                             to=['%s <%s>' % (user.username, user.email)])
            msg.attach_alternative(html, "text/html")
            msg.send()
            sent_emails += 1
                
        logging.user(reply_user, "~BB~FM~SBSending %s/%s email%s for new reply: %s" % (
            sent_emails, len(notify_user_ids), 
            '' if len(notify_user_ids) == 1 else 's', 
            self.story_title[:30]))
        
        self.emailed_replies.append(reply.reply_id)
        self.save()
    
    def send_email_for_reshare(self):
        if self.emailed_reshare:
            logging.debug(" ***> Already sent reply email: %s" % self)
            return
            
        reshare_user = User.objects.get(pk=self.user_id)
        reshare_user_profile = MSocialProfile.get_user(self.user_id)
        original_user = User.objects.get(pk=self.source_user_id)
        original_shared_story = MSharedStory.objects.get(user_id=self.source_user_id,
                                                         story_guid=self.story_guid)
                                                         
        if not original_user.email or not original_user.profile.send_emails:
            if not original_user.email:
                logging.user(original_user, "~BB~FMNo email to send to, skipping.")
            elif not original_user.profile.send_emails:
                logging.user(original_user, "~BB~FMDisabled emails, skipping.")
            return
            
        story_feed = Feed.objects.get(pk=self.story_feed_id)
        comment = self.comments_with_author()
        profile_user_ids = set([comment['user_id']])
        reply_user_ids = [reply['user_id'] for reply in comment['replies']]
        profile_user_ids = profile_user_ids.union(reply_user_ids)
        if self.source_user_id:
            profile_user_ids.add(self.source_user_id)
        profiles = MSocialProfile.objects.filter(user_id__in=list(profile_user_ids))
        profiles = [profile.to_json(compact=True) for profile in profiles]
        comment = MSharedStory.attach_users_to_comment(comment, profiles)
        
        mute_url = "http://%s%s" % (
            Site.objects.get_current().domain,
            reverse('social-mute-story', kwargs={
                'secret_token': original_user.profile.secret_token,
                'shared_story_id': original_shared_story.id,
            })
        )
        data = {
            'comment': comment,
            'shared_story': self,
            'reshare_user_profile': reshare_user_profile,
            'original_shared_story': original_shared_story,
            'story_feed': story_feed,
            'mute_url': mute_url,
        }
    
        text    = render_to_string('mail/email_reshare.txt', data)
        html    = pynliner.fromString(render_to_string('mail/email_reshare.xhtml', data))
        subject = "%s re-shared \"%s\" from you on NewsBlur" % (reshare_user.username, self.story_title)
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (original_user.username, original_user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send()
        
        self.emailed_reshare = True
        self.save()
            
        logging.user(reshare_user, "~BB~FM~SBSending %s email for story re-share: %s" % (
            original_user.username,
            self.story_title[:30]))
        
        

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
    syncing_twitter       = mongo.BooleanField(default=False)
    syncing_facebook      = mongo.BooleanField(default=False)
    
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
                'syncing': self.syncing_twitter,
            },
            'facebook': {
                'facebook_uid': self.facebook_uid,
                'facebook_picture_url': self.facebook_picture_url,
                'syncing': self.syncing_facebook,
            },
            'gravatar': {
                'gravatar_picture_url': "http://www.gravatar.com/avatar/" + \
                                        hashlib.md5(user.email).hexdigest()
            },
            'upload': {
                'upload_picture_url': self.upload_picture_url
            }
        }
    
    @classmethod
    def profile(cls, user_id):
        try:
            profile = cls.objects.get(user_id=user_id)
        except cls.DoesNotExist:
            return {}
        return profile.to_json()

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
        
        profile = MSocialProfile.get_user(self.user_id)
        profile.location = profile.location or twitter_user.location
        profile.bio = profile.bio or twitter_user.description
        profile.website = profile.website or twitter_user.url
        profile.save()
        profile.count_follows()
        if not profile.photo_url or not profile.photo_service:
            self.set_photo('twitter')
        
    def sync_facebook_friends(self):
        self.syncing_facebook = False
        self.save()
        
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
        profile = MSocialProfile.get_user(self.user_id)
        profile.location = profile.location or (facebook_user.get('location') and facebook_user['location']['name'])
        profile.bio = profile.bio or facebook_user.get('bio')
        profile.website = profile.website or facebook_user.get('website')
        profile.save()
        profile.count_follows()
        if not profile.photo_url or not profile.photo_service:
            self.set_photo('facebook')
        
    def follow_twitter_friends(self):
        self.syncing_twitter = False
        self.save()
        
        social_profile = MSocialProfile.get_user(self.user_id)
        following = []
        followers = 0
        
        if not self.autofollow:
            return following

        # Follow any friends already on NewsBlur
        user_social_services = MSocialServices.objects.filter(twitter_uid__in=self.twitter_friend_ids)
        for user_social_service in user_social_services:
            followee_user_id = user_social_service.user_id
            socialsub = social_profile.follow_user(followee_user_id)
            if socialsub:
                following.append(followee_user_id)
    
        # Follow any friends already on NewsBlur
        following_users = MSocialServices.objects.filter(twitter_friend_ids__contains=self.twitter_uid)
        for following_user in following_users:
            if following_user.autofollow:
                following_user_profile = MSocialProfile.get_user(following_user.user_id)
                following_user_profile.follow_user(self.user_id, check_unfollowed=True)
                followers += 1
        
        user = User.objects.get(pk=self.user_id)
        logging.user(user, "~BB~FRTwitter import: %s users, now following ~SB%s~SN with ~SB%s~SN follower-backs" % (len(self.twitter_friend_ids), len(following), followers))
        
        return following
        
    def follow_facebook_friends(self):
        social_profile = MSocialProfile.get_user(self.user_id)
        following = []
        followers = 0
        
        if not self.autofollow:
            return following

        # Follow any friends already on NewsBlur
        user_social_services = MSocialServices.objects.filter(facebook_uid__in=self.facebook_friend_ids)
        for user_social_service in user_social_services:
            followee_user_id = user_social_service.user_id
            socialsub = social_profile.follow_user(followee_user_id)
            if socialsub:
                following.append(followee_user_id)
    
        # Friends already on NewsBlur should follow back
        following_users = MSocialServices.objects.filter(facebook_friend_ids__contains=self.facebook_uid)
        for following_user in following_users:
            if following_user.autofollow:
                following_user_profile = MSocialProfile.get_user(following_user.user_id)
                following_user_profile.follow_user(self.user_id, check_unfollowed=True)
                followers += 1
        
        user = User.objects.get(pk=self.user_id)
        logging.user(user, "~BB~FRFacebook import: %s users, now following ~SB%s~SN with ~SB%s~SN follower-backs" % (len(self.facebook_friend_ids), len(following), followers))
        
        return following
        
    def disconnect_twitter(self):
        self.twitter_uid = None
        self.save()
        
    def disconnect_facebook(self):
        self.facebook_uid = None
        self.save()
        
    def set_photo(self, service):
        profile = MSocialProfile.get_user(self.user_id)
        if service == 'nothing':
            service = None

        profile.photo_service = service
        if not service:
            profile.photo_url = None
        elif service == 'twitter':
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
        return profile
    
    def post_to_twitter(self, message):
        try:
            api = self.twitter_api()
            api.update_status(status=message)
        except tweepy.TweepError, e:
            print e
            return

        return True
            
    def post_to_facebook(self, message):
        try:
            api = self.facebook_api()
            api.put_wall_post(message=message)
        except facebook.GraphAPIError, e:
            print e
            return

        return True

class MInteraction(mongo.Document):
    user_id      = mongo.IntField()
    date         = mongo.DateTimeField(default=datetime.datetime.now)
    category     = mongo.StringField()
    title        = mongo.StringField()
    content      = mongo.StringField()
    with_user_id = mongo.IntField()
    feed_id      = mongo.DynamicField()
    story_feed_id= mongo.IntField()
    content_id   = mongo.StringField()
    
    meta = {
        'collection': 'interactions',
        'indexes': [('user_id', '-date'), 'category'],
        'allow_inheritance': False,
        'index_drop_dups': True,
        'ordering': ['-date'],
    }
    
    def __unicode__(self):
        user = User.objects.get(pk=self.user_id)
        with_user = self.with_user_id and User.objects.get(pk=self.with_user_id)
        return "<%s> %s on %s: %s - %s" % (user.username, with_user and with_user.username, self.date, 
                                           self.category, self.content and self.content[:20])
    
    def to_json(self):
        return {
            'date': self.date,
            'category': self.category,
            'title': self.title,
            'content': self.content,
            'with_user_id': self.with_user_id,
            'feed_id': self.feed_id,
            'story_feed_id': self.story_feed_id,
            'content_id': self.content_id,
        }
        
    @classmethod
    def user(cls, user_id, page=1, limit=None):
        user_profile = Profile.objects.get(user=user_id)
        dashboard_date = user_profile.dashboard_date or user_profile.last_seen_on
        page = max(1, page)
        limit = int(limit) if limit else 4
        offset = (page-1) * limit
        interactions_db = cls.objects.filter(user_id=user_id)[offset:offset+limit+1]
        has_next_page = len(interactions_db) > limit
        interactions_db = interactions_db[offset:offset+limit]
        with_user_ids = [i.with_user_id for i in interactions_db if i.with_user_id]
        social_profiles = dict((p.user_id, p) for p in MSocialProfile.objects.filter(user_id__in=with_user_ids))
        
        interactions = []
        for interaction_db in interactions_db:
            interaction = interaction_db.to_json()
            social_profile = social_profiles.get(interaction_db.with_user_id)
            if social_profile:
                interaction['photo_url'] = social_profile.profile_photo_url
            interaction['with_user'] = social_profiles.get(interaction_db.with_user_id)
            interaction['time_since'] = relative_timesince(interaction_db.date)
            interaction['date'] = interaction_db.date
            interaction['is_new'] = interaction_db.date > dashboard_date
            interactions.append(interaction)

        return interactions, has_next_page
        
    @classmethod
    def new_follow(cls, follower_user_id, followee_user_id):
        params = {
            'user_id': followee_user_id, 
            'with_user_id': follower_user_id,
            'category': 'follow',
        }
        try:
            cls.objects.get_or_create(**params)
        except cls.MultipleObjectsReturned:
            dupes = cls.objects.filter(**params).order_by('-date')
            logging.debug(" ---> ~FRDeleting dupe follow interactions. %s found." % dupes.count())
            for dupe in dupes[1:]:
                dupe.delete()
    
    @classmethod
    def new_comment_reply(cls, user_id, reply_user_id, reply_content, story_id, story_feed_id, story_title=None, original_message=None):
        params = {
            'user_id': user_id,
            'with_user_id': reply_user_id,
            'category': 'comment_reply',
            'content': reply_content,
            'feed_id': "social:%s" % user_id,
            'story_feed_id': story_feed_id,
            'title': story_title,
            'content_id': story_id,
        }
        if original_message:
            params['content'] = original_message
            original = cls.objects.filter(**params).limit(1)
            if original:
                original = original[0]
                original.content = reply_content
                original.save()
            else:
                original_message = None

        if not original_message:
            cls.objects.create(**params)
            
    @classmethod
    def remove_comment_reply(cls, user_id, reply_user_id, reply_content, story_id, story_feed_id):
        params = {
            'user_id': user_id,
            'with_user_id': reply_user_id,
            'category': 'comment_reply',
            'content': reply_content,
            'feed_id': "social:%s" % user_id,
            'story_feed_id': story_feed_id,
            'content_id': story_id,
        }
        original = cls.objects.filter(**params)
        original.delete()
    
    @classmethod
    def new_comment_like(cls, liking_user_id, comment_user_id, story_id, story_title, comments):
        cls.objects.get_or_create(user_id=comment_user_id,
                                  with_user_id=liking_user_id,
                                  category="comment_like",
                                  feed_id="social:%s" % comment_user_id,
                                  content_id=story_id,
                                  defaults={
                                    "title": story_title,
                                    "content": comments,
                                  })

    @classmethod
    def new_reply_reply(cls, user_id, comment_user_id, reply_user_id, reply_content, story_id, story_feed_id, story_title=None, original_message=None):
        params = {
            'user_id': user_id,
            'with_user_id': reply_user_id,
            'category': 'reply_reply',
            'content': reply_content,
            'feed_id': "social:%s" % comment_user_id,
            'story_feed_id': story_feed_id,
            'title': story_title,
            'content_id': story_id,
        }
        if original_message:
            params['content'] = original_message
            original = cls.objects.filter(**params).limit(1)
            if original:
                original = original[0]
                original.content = reply_content
                original.save()
            else:
                original_message = None

        if not original_message:
            cls.objects.create(**params)
            
    @classmethod
    def remove_reply_reply(cls, user_id, comment_user_id, reply_user_id, reply_content, story_id, story_feed_id):
        params = {
            'user_id': user_id,
            'with_user_id': reply_user_id,
            'category': 'reply_reply',
            'content': reply_content,
            'feed_id': "social:%s" % comment_user_id,
            'story_feed_id': story_feed_id,
            'content_id': story_id,
        }
        original = cls.objects.filter(**params)
        original.delete()
        
    @classmethod
    def new_reshared_story(cls, user_id, reshare_user_id, comments, story_title, story_feed_id, story_id, original_comments=None):
        params = {
            'user_id': user_id,
            'with_user_id': reshare_user_id,
            'category': 'story_reshare',
            'content': comments,
            'title': story_title,
            'feed_id': "social:%s" % reshare_user_id,
            'story_feed_id': story_feed_id,
            'content_id': story_id,
        }
        if original_comments:
            params['content'] = original_comments
            original = cls.objects.filter(**params).limit(1)
            if original:
                original = original[0]
                original.content = comments
                original.save()
            else:
                original_comments = None

        if not original_comments:
            cls.objects.create(**params)

class MActivity(mongo.Document):
    user_id      = mongo.IntField()
    date         = mongo.DateTimeField(default=datetime.datetime.now)
    category     = mongo.StringField()
    title        = mongo.StringField()
    content      = mongo.StringField()
    with_user_id = mongo.IntField()
    feed_id      = mongo.DynamicField()
    story_feed_id= mongo.IntField()
    content_id   = mongo.StringField()
    
    meta = {
        'collection': 'activities',
        'indexes': [('user_id', '-date'), 'category'],
        'allow_inheritance': False,
        'index_drop_dups': True,
        'ordering': ['-date'],
    }
    
    def __unicode__(self):
        user = User.objects.get(pk=self.user_id)
        return "<%s> %s - %s" % (user.username, self.category, self.content and self.content[:20])
    
    def to_json(self):
        return {
            'date': self.date,
            'category': self.category,
            'title': self.title,
            'content': self.content,
            'with_user_id': self.with_user_id,
            'feed_id': self.feed_id,
            'story_feed_id': self.story_feed_id,
            'content_id': self.content_id,
        }
        
    @classmethod
    def user(cls, user_id, page=1, limit=4, public=False):
        user_profile = Profile.objects.get(user=user_id)
        dashboard_date = user_profile.dashboard_date or user_profile.last_seen_on
        page = max(1, page)
        limit = int(limit)
        offset = (page-1) * limit
        
        activities_db = cls.objects.filter(user_id=user_id)
        if public:
            activities_db = activities_db.filter(category__nin=['star', 'feedsub'])
            
        activities_db = activities_db[offset:offset+limit+1]
        has_next_page = len(activities_db) > limit
        activities_db = activities_db[offset:offset+limit]
        with_user_ids = [a.with_user_id for a in activities_db if a.with_user_id]
        social_profiles = dict((p.user_id, p) for p in MSocialProfile.objects.filter(user_id__in=with_user_ids))
        activities = []
        for activity_db in activities_db:
            activity = activity_db.to_json()
            activity['date'] = activity_db.date
            activity['time_since'] = relative_timesince(activity_db.date)
            social_profile = social_profiles.get(activity_db.with_user_id)
            if social_profile:
                activity['photo_url'] = social_profile.profile_photo_url
            activity['is_new'] = activity_db.date > dashboard_date
            activity['with_user'] = social_profiles.get(activity_db.with_user_id)
            activities.append(activity)
        
        return activities, has_next_page
            
    @classmethod
    def new_starred_story(cls, user_id, story_title, story_feed_id, story_id):
        cls.objects.get_or_create(user_id=user_id,
                                  category='star',
                                  content=story_title,
                                  story_feed_id=story_feed_id,
                                  content_id=story_id)
                           
    @classmethod
    def new_feed_subscription(cls, user_id, feed_id, feed_title):
        cls.objects.create(user_id=user_id,
                           category='feedsub',
                           content=feed_title,
                           feed_id=feed_id)
                           
    @classmethod
    def new_follow(cls, follower_user_id, followee_user_id):
        params = {
            'user_id': follower_user_id, 
            'with_user_id': followee_user_id,
            'category': 'follow',
        }
        try:
            cls.objects.get_or_create(**params)
        except cls.MultipleObjectsReturned:
            dupes = cls.objects.filter(**params).order_by('-date')
            logging.debug(" ---> ~FRDeleting dupe follow activities. %s found." % dupes.count())
            for dupe in dupes[1:]:
                dupe.delete()
    
    @classmethod
    def new_comment_reply(cls, user_id, comment_user_id, reply_content, story_id, story_feed_id, story_title=None, original_message=None):
        params = {
            'user_id': user_id,
            'with_user_id': comment_user_id,
            'category': 'comment_reply',
            'content': reply_content,
            'feed_id': "social:%s" % comment_user_id,
            'story_feed_id': story_feed_id,
            'title': story_title,
            'content_id': story_id,
        }
        if original_message:
            params['content'] = original_message
            original = cls.objects.filter(**params).limit(1)
            if original:
                original = original[0]
                original.content = reply_content
                original.save()
            else:
                original_message = None

        if not original_message:
            cls.objects.create(**params)
            
    @classmethod
    def remove_comment_reply(cls, user_id, comment_user_id, reply_content, story_id, story_feed_id):
        params = {
            'user_id': user_id,
            'with_user_id': comment_user_id,
            'category': 'comment_reply',
            'content': reply_content,
            'feed_id': "social:%s" % comment_user_id,
            'story_feed_id': story_feed_id,
            'content_id': story_id,
        }
        original = cls.objects.filter(**params)
        original.delete()
            
    @classmethod
    def new_comment_like(cls, liking_user_id, comment_user_id, story_id, story_title, comments):
        cls.objects.get_or_create(user_id=liking_user_id,
                                  with_user_id=comment_user_id,
                                  category="comment_like",
                                  feed_id="social:%s" % comment_user_id,
                                  content_id=story_id,
                                  defaults={
                                    "title": story_title,
                                    "content": comments,
                                  })
    
    @classmethod
    def new_shared_story(cls, user_id, source_user_id, story_title, comments, story_feed_id, story_id, share_date=None):
        a, _ = cls.objects.get_or_create(user_id=user_id,
                                         category='sharedstory',
                                         feed_id="social:%s" % user_id,
                                         story_feed_id=story_feed_id,
                                         content_id=story_id,
                                         defaults={
                                             'with_user_id': source_user_id,
                                             'title': story_title,
                                             'content': comments,
                                         })
        if a.content != comments:
            a.content = comments
            a.save()
        if share_date:
            a.date = share_date
            a.save()

    @classmethod
    def remove_shared_story(cls, user_id, story_feed_id, story_id):
        try:
            a = cls.objects.get(user_id=user_id,
                                with_user_id=user_id,
                                category='sharedstory',
                                feed_id=story_feed_id,
                                content_id=story_id)
        except cls.DoesNotExist:
            return
        
        a.delete()
        
