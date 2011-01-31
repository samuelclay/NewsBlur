import datetime
from django.db import models
from django.db import IntegrityError
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.core.mail import mail_admins
from django.contrib.auth import authenticate
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed
from paypal.standard.ipn.signals import subscription_signup
from apps.rss_feeds.tasks import NewFeeds
from celery.task import Task
from utils import log as logging
from utils.timezones.fields import TimeZoneField
from utils.user_functions import generate_secret_token
     
class Profile(models.Model):
    user = models.OneToOneField(User, unique=True, related_name="profile")
    is_premium = models.BooleanField(default=False)
    preferences = models.TextField(default="{}")
    view_settings = models.TextField(default="{}")
    collapsed_folders = models.TextField(default="[]")
    last_seen_on = models.DateTimeField(default=datetime.datetime.now)
    last_seen_ip = models.CharField(max_length=50, blank=True, null=True)
    timezone = TimeZoneField(default="America/New_York")
    secret_token = models.CharField(max_length=12, blank=True, null=True)
    
    def __unicode__(self):
        return "%s" % self.user
    
    def save(self, *args, **kwargs):
        if not self.secret_token:
            self.secret_token = generate_secret_token(self.user.username, 12)
        super(Profile, self).save(*args, **kwargs)
    
    def activate_premium(self):
        self.is_premium = True
        self.save()
        
        subs = UserSubscription.objects.filter(user=self.user)
        for sub in subs:
            sub.active = True
            try:
                sub.save()
                sub.feed.setup_feed_for_premium_subscribers()
            except IntegrityError, Feed.DoesNotExist:
                pass
        
        self.queue_new_feeds()
        
        logging.info(' ---> [%s] ~BY~SK~FW~SBNEW PREMIUM ACCOUNT! WOOHOO!!! ~FR%s subscriptions~SN!' % (self.user.username, subs.count()))
        message = """Woohoo!
        
User: %(user)s
Feeds: %(feeds)s

Sincerely,
NewsBlur""" % {'user': self.user.username, 'feeds': subs.count()}
        mail_admins('New premium account', message, fail_silently=True)
        
    def queue_new_feeds(self, new_feeds=None):
        if not new_feeds:
            new_feeds = UserSubscription.objects.filter(user=self.user, 
                                                        feed__fetched_once=False, 
                                                        active=True).values('feed_id')
            new_feeds = list(set([f['feed_id'] for f in new_feeds]))
        logging.info(" ---> [%s] ~BB~FW~SBQueueing NewFeeds: ~FC(%s) %s" % (self.user, len(new_feeds), new_feeds))
        size = 4
        publisher = Task.get_publisher(exchange="new_feeds")
        for t in (new_feeds[pos:pos + size] for pos in xrange(0, len(new_feeds), size)):
            NewFeeds.apply_async(args=(t,), queue="new_feeds", publisher=publisher)
        publisher.connection.close()   

    def refresh_stale_feeds(self, exclude_new=False):
        stale_cutoff = datetime.datetime.now() - datetime.timedelta(days=7)
        stale_feeds  = UserSubscription.objects.filter(user=self.user, active=True, feed__last_update__lte=stale_cutoff)
        if exclude_new:
            stale_feeds = stale_feeds.filter(feed__fetched_once=True)
        all_feeds    = UserSubscription.objects.filter(user=self.user, active=True)
        
        logging.info(" ---> [%s] ~FG~BBRefreshing stale feeds: ~SB%s/%s" % (
            self.user, stale_feeds.count(), all_feeds.count()))

        for sub in stale_feeds:
            sub.feed.fetched_once = False
            sub.feed.save()
        
        if stale_feeds:
            stale_feeds = list(set([f['feed_id'] for f in stale_feeds]))
            self.queue_new_feeds(new_feeds=stale_feeds)
        
        
def create_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)
    else:
        Profile.objects.get_or_create(user=instance)
post_save.connect(create_profile, sender=User)


def paypal_signup(sender, **kwargs):
    ipn_obj = sender
    user = User.objects.get(username=ipn_obj.custom)
    user.profile.activate_premium()
subscription_signup.connect(paypal_signup)

def change_password(user, old_password, new_password):
    user_db = authenticate(username=user.username, password=old_password)
    if user_db is None:
        return -1
    else:
        user_db.set_password(new_password)
        user_db.save()
        return 1