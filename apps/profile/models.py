import datetime
import stripe
import mongoengine as mongo
from django.db import models
from django.db import IntegrityError
from django.db.utils import DatabaseError
from django.db.models.signals import post_save
from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.core.mail import mail_admins
from django.core.mail import EmailMultiAlternatives
from django.core.urlresolvers import reverse
from django.template.loader import render_to_string
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStory
from apps.rss_feeds.tasks import NewFeeds
from apps.feed_import.models import GoogleReaderImporter
from utils import log as logging
from utils import json_functions as json
from utils.user_functions import generate_secret_token
from vendor.timezones.fields import TimeZoneField
from vendor.paypal.standard.ipn.signals import subscription_signup
from vendor.paypal.standard.ipn.models import PayPalIPN
from zebra.signals import zebra_webhook_customer_subscription_created

class Profile(models.Model):
    user              = models.OneToOneField(User, unique=True, related_name="profile")
    is_premium        = models.BooleanField(default=False)
    premium_expire    = models.DateTimeField(blank=True, null=True)
    send_emails       = models.BooleanField(default=True)
    preferences       = models.TextField(default="{}")
    view_settings     = models.TextField(default="{}")
    collapsed_folders = models.TextField(default="[]")
    feed_pane_size    = models.IntegerField(default=240)
    tutorial_finished = models.BooleanField(default=False)
    hide_getting_started = models.NullBooleanField(default=False, null=True, blank=True)
    has_setup_feeds   = models.NullBooleanField(default=False, null=True, blank=True)
    has_found_friends = models.NullBooleanField(default=False, null=True, blank=True)
    has_trained_intelligence = models.NullBooleanField(default=False, null=True, blank=True)
    last_seen_on      = models.DateTimeField(default=datetime.datetime.now)
    last_seen_ip      = models.CharField(max_length=50, blank=True, null=True)
    dashboard_date    = models.DateTimeField(default=datetime.datetime.now)
    timezone          = TimeZoneField(default="America/New_York")
    secret_token      = models.CharField(max_length=12, blank=True, null=True)
    stripe_4_digits   = models.CharField(max_length=4, blank=True, null=True)
    stripe_id         = models.CharField(max_length=24, blank=True, null=True)
    
    def __unicode__(self):
        return "%s <%s> (Premium: %s)" % (self.user, self.user.email, self.is_premium)
    
    def to_json(self):
        return {
            'is_premium': self.is_premium,
            'preferences': json.decode(self.preferences),
            'tutorial_finished': self.tutorial_finished,
            'hide_getting_started': self.hide_getting_started,
            'has_setup_feeds': self.has_setup_feeds,
            'has_found_friends': self.has_found_friends,
            'has_trained_intelligence': self.has_trained_intelligence,
            'dashboard_date': self.dashboard_date
        }
        
    def save(self, *args, **kwargs):
        if not self.secret_token:
            self.secret_token = generate_secret_token(self.user.username, 12)
        try:
            super(Profile, self).save(*args, **kwargs)
        except DatabaseError:
            print " ---> Profile not saved. Table isn't there yet."
    
    def delete_user(self, confirm=False):
        if not confirm:
            print " ---> You must pass confirm=True to delete this user."
            return
        
        from apps.social.models import MSocialProfile, MSharedStory, MSocialSubscription
        from apps.social.models import MActivity, MInteraction
        try:
            social_profile = MSocialProfile.objects.get(user_id=self.user.pk)
            print " ---> Unfollowing %s followings and %s followers" % (social_profile.following_count,
                                                                        social_profile.follower_count)
            for follow in social_profile.following_user_ids:
                social_profile.unfollow_user(follow)
            for follower in social_profile.follower_user_ids:
                follower_profile = MSocialProfile.objects.get(user_id=follower)
                follower_profile.unfollow_user(self.user.pk)
            social_profile.delete()
        except MSocialProfile.DoesNotExist:
            print " ***> No social profile found. S'ok, moving on."
            pass
        
        shared_stories = MSharedStory.objects.filter(user_id=self.user.pk)
        print " ---> Deleting %s shared stories" % shared_stories.count()
        for story in shared_stories:
            try:
                original_story = MStory.objects.get(pk=story.story_db_id)
                original_story.sync_redis()
            except MStory.DoesNotExist:
                pass
            story.delete()
            
        subscriptions = MSocialSubscription.objects.filter(subscription_user_id=self.user.pk)
        print " ---> Deleting %s social subscriptions" % subscriptions.count()
        subscriptions.delete()
        
        interactions = MInteraction.objects.filter(user_id=self.user.pk)
        print " ---> Deleting %s interactions for user." % interactions.count()
        interactions.delete()
        
        interactions = MInteraction.objects.filter(with_user_id=self.user.pk)
        print " ---> Deleting %s interactions with user." % interactions.count()
        interactions.delete()
        
        activities = MActivity.objects.filter(user_id=self.user.pk)
        print " ---> Deleting %s activities for user." % activities.count()
        activities.delete()
        
        activities = MActivity.objects.filter(with_user_id=self.user.pk)
        print " ---> Deleting %s activities with user." % activities.count()
        activities.delete()
        
        print " ---> Deleting user: %s" % self.user
        self.user.delete()
        
    def activate_premium(self):
        from apps.profile.tasks import EmailNewPremium
        EmailNewPremium.delay(user_id=self.user.pk)
        
        self.is_premium = True
        self.save()
        
        self.setup_premium_history()
        
        subs = UserSubscription.objects.filter(user=self.user)
        for sub in subs:
            sub.active = True
            try:
                sub.save()
                sub.feed.setup_feed_for_premium_subscribers()
            except IntegrityError, Feed.DoesNotExist:
                pass
        
        self.queue_new_feeds()
        
        logging.user(self.user, "~BY~SK~FW~SBNEW PREMIUM ACCOUNT! WOOHOO!!! ~FR%s subscriptions~SN!" % (subs.count()))
    
    def setup_premium_history(self):
        existing_history = PaymentHistory.objects.filter(user=self.user)
        print " ---> Deleting existing history: %s payments" % existing_history.count()
        existing_history.delete()
        
        # Record Paypal payments
        paypal_payments = PayPalIPN.objects.filter(custom=self.user.username,
                                                   txn_type='subscr_payment')
        for payment in paypal_payments:
            PaymentHistory.objects.create(user=self.user,
                                          payment_date=payment.payment_date,
                                          payment_amount=payment.payment_gross,
                                          payment_provider='paypal')
        
        # Record Stripe payments
        if self.stripe_id:
            stripe.api_key = settings.STRIPE_SECRET
            stripe_customer = stripe.Customer.retrieve(self.stripe_id)
            stripe_payments = stripe.Charge.all(customer=stripe_customer.id).data
            for payment in stripe_payments:
                created = datetime.datetime.fromtimestamp(payment.created)
                PaymentHistory.objects.create(user=self.user,
                                              payment_date=created,
                                              payment_amount=payment.amount / 100.0,
                                              payment_provider='stripe')
        
        # Calculate last payment date
        payment_history = PaymentHistory.objects.filter(user=self.user)
        most_recent_payment_date = None
        for payment in payment_history:
            if not most_recent_payment_date or payment.payment_date > most_recent_payment_date:
                most_recent_payment_date = payment.payment_date
        
        if most_recent_payment_date:
            self.premium_expire = most_recent_payment_date + datetime.timedelta(year=1)
            self.save()
        
    def queue_new_feeds(self, new_feeds=None):
        if not new_feeds:
            new_feeds = UserSubscription.objects.filter(user=self.user, 
                                                        feed__fetched_once=False, 
                                                        active=True).values('feed_id')
            new_feeds = list(set([f['feed_id'] for f in new_feeds]))
        logging.user(self.user, "~BB~FW~SBQueueing NewFeeds: ~FC(%s) %s" % (len(new_feeds), new_feeds))
        size = 4
        for t in (new_feeds[pos:pos + size] for pos in xrange(0, len(new_feeds), size)):
            NewFeeds.apply_async(args=(t,), queue="new_feeds")

    def refresh_stale_feeds(self, exclude_new=False):
        stale_cutoff = datetime.datetime.now() - datetime.timedelta(days=7)
        stale_feeds  = UserSubscription.objects.filter(user=self.user, active=True, feed__last_update__lte=stale_cutoff)
        if exclude_new:
            stale_feeds = stale_feeds.filter(feed__fetched_once=True)
        all_feeds    = UserSubscription.objects.filter(user=self.user, active=True)
        
        logging.user(self.user, "~FG~BBRefreshing stale feeds: ~SB%s/%s" % (
            stale_feeds.count(), all_feeds.count()))

        for sub in stale_feeds:
            sub.feed.fetched_once = False
            sub.feed.save()
        
        if stale_feeds:
            stale_feeds = list(set([f.feed_id for f in stale_feeds]))
            self.queue_new_feeds(new_feeds=stale_feeds)
    
    def import_reader_starred_items(self, count=20):
        importer = GoogleReaderImporter(self.user)
        importer.import_starred_items(count=count)
        
    def send_new_user_email(self):
        if not self.user.email or not self.send_emails:
            return
        
        user    = self.user
        text    = render_to_string('mail/email_new_account.txt', locals())
        html    = render_to_string('mail/email_new_account.xhtml', locals())
        subject = "Welcome to NewsBlur, %s" % (self.user.username)
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send(fail_silently=True)
        
        logging.user(self.user, "~BB~FM~SBSending email for new user: %s" % self.user.email)
    
    def send_new_premium_email(self, force=False):
        subs = UserSubscription.objects.filter(user=self.user)
        message = """Woohoo!
        
User: %(user)s
Feeds: %(feeds)s

Sincerely,
NewsBlur""" % {'user': self.user.username, 'feeds': subs.count()}
        mail_admins('New premium account', message, fail_silently=True)
        
        if not self.user.email or not self.send_emails:
            return
        
        sent_email, created = MSentEmail.objects.get_or_create(receiver_user_id=self.user.pk,
                                                               email_type='new_premium')
        
        if not created and not force:
            return
        
        user    = self.user
        text    = render_to_string('mail/email_new_premium.txt', locals())
        html    = render_to_string('mail/email_new_premium.xhtml', locals())
        subject = "Thanks for going premium on NewsBlur!"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send(fail_silently=True)
        
        logging.user(self.user, "~BB~FM~SBSending email for new premium: %s" % self.user.email)
    
    def send_forgot_password_email(self, email=None):
        if not self.user.email and not email:
            print "Please provide an email address."
            return
        
        if not self.user.email and email:
            self.user.email = email
            self.user.save()
        
        user    = self.user
        text    = render_to_string('mail/email_forgot_password.txt', locals())
        html    = render_to_string('mail/email_forgot_password.xhtml', locals())
        subject = "Forgot your password on NewsBlur?"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send(fail_silently=True)
        
        user.set_password('')
        user.save()
        
        logging.user(self.user, "~BB~FM~SBSending email for forgotten password: %s" % self.user.email)
        
    def send_upload_opml_finished_email(self, feed_count):
        if not self.user.email:
            print "Please provide an email address."
            return
        
        user    = self.user
        text    = render_to_string('mail/email_upload_opml_finished.txt', locals())
        html    = render_to_string('mail/email_upload_opml_finished.xhtml', locals())
        subject = "Your OPML upload is complete. Get going with NewsBlur!"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send()
                
        logging.user(self.user, "~BB~FM~SBSending email for OPML upload: %s" % self.user.email)
    
    def send_launch_social_email(self, force=False):
        if not self.user.email or not self.send_emails:
            logging.user(self.user, "~FM~SB~FRNot~FM sending launch social email for user, %s: %s" % (self.user.email and 'opt-out: ' or 'blank', self.user.email))
            return
        
        sent_email, created = MSentEmail.objects.get_or_create(receiver_user_id=self.user.pk,
                                                               email_type='launch_social')
        
        if not created and not force:
            logging.user(self.user, "~FM~SB~FRNot~FM sending launch social email for user, sent already: %s" % self.user.email)
            return
        
        delta      = datetime.datetime.now() - self.last_seen_on
        months_ago = delta.days / 30
        user    = self.user
        data    = dict(user=user, months_ago=months_ago)
        text    = render_to_string('mail/email_launch_social.txt', data)
        html    = render_to_string('mail/email_launch_social.xhtml', data)
        subject = "NewsBlur is now a social news reader"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send(fail_silently=True)
        
        logging.user(self.user, "~BB~FM~SBSending launch social email for user: %s months, %s" % (months_ago, self.user.email))
    
    def autologin_url(self, next=None):
        return reverse('autologin', kwargs={
            'username': self.user.username, 
            'secret': self.secret_token
        }) + ('?' + next + '=1' if next else '')
        

            
def create_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)
    else:
        Profile.objects.get_or_create(user=instance)
post_save.connect(create_profile, sender=User)


def paypal_signup(sender, **kwargs):
    ipn_obj = sender
    user = User.objects.get(username=ipn_obj.custom)
    try:
        if not user.email:
            user.email = ipn_obj.payer_email
            user.save()
    except:
        pass
    user.profile.activate_premium()
subscription_signup.connect(paypal_signup)

def stripe_signup(sender, full_json, **kwargs):
    stripe_id = full_json['data']['object']['customer']
    try:
        profile = Profile.objects.get(stripe_id=stripe_id)
        profile.activate_premium()
    except Profile.DoesNotExist:
        return {"code": -1, "message": "User doesn't exist."}
zebra_webhook_customer_subscription_created.connect(stripe_signup)

def change_password(user, old_password, new_password):
    user_db = authenticate(username=user.username, password=old_password)
    if user_db is None:
        return -1
    else:
        user_db.set_password(new_password)
        user_db.save()
        return 1
        
    
class MSentEmail(mongo.Document):
    sending_user_id = mongo.IntField()
    receiver_user_id = mongo.IntField()
    email_type = mongo.StringField()
    date_sent = mongo.DateTimeField(default=datetime.datetime.now)
    
    meta = {
        'collection': 'sent_emails',
        'allow_inheritance': False,
        'indexes': ['sending_user_id', 'receiver_user_id', 'email_type'],
    }
    
    def __unicode__(self):
        return "%s sent %s email to %s" % (self.sending_user_id, self.email_type, self.receiver_user_id)
    
    @classmethod
    def record(cls, email_type, receiver_user_id, sending_user_id):
        cls.objects.create(email_type=email_type, 
                           receiver_user_id=receiver_user_id, 
                           sending_user_id=sending_user_id)

class PaymentHistory(models.Model):
    user = models.ForeignKey(User, related_name='payments')
    payment_date = models.DateTimeField(auto_now=True)
    payment_amount = models.IntegerField()
    payment_provider = models.CharField(max_length=20)
    
    class Meta:
        ordering = ['-payment_date']