import time
import datetime
import dateutil
import stripe
import hashlib
import re
import redis
import uuid
import mongoengine as mongo
from django.db import models
from django.db import IntegrityError
from django.db.utils import DatabaseError
from django.db.models.signals import post_save
from django.db.models import Sum, Avg, Count
from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.core.mail import EmailMultiAlternatives
from django.urls import reverse
from django.template.loader import render_to_string
from apps.rss_feeds.models import Feed, MStory, MStarredStory
from apps.rss_feeds.tasks import SchedulePremiumSetup
from apps.feed_import.models import OPMLExporter
from apps.reader.models import UserSubscription
from apps.reader.models import RUserStory
from utils import log as logging
from utils import json_functions as json
from utils.user_functions import generate_secret_token
from utils.feed_functions import chunks
from vendor.timezones.fields import TimeZoneField
from paypal.standard.ipn.signals import valid_ipn_received, invalid_ipn_received
from paypal.standard.ipn.models import PayPalIPN
from vendor.paypalapi.interface import PayPalInterface
from vendor.paypalapi.exceptions import PayPalAPIResponseError
from zebra.signals import zebra_webhook_customer_subscription_created
from zebra.signals import zebra_webhook_charge_succeeded

class Profile(models.Model):
    user              = models.OneToOneField(User, unique=True, related_name="profile", on_delete=models.CASCADE)
    is_premium        = models.BooleanField(default=False)
    premium_expire    = models.DateTimeField(blank=True, null=True)
    send_emails       = models.BooleanField(default=True)
    preferences       = models.TextField(default="{}")
    view_settings     = models.TextField(default="{}")
    collapsed_folders = models.TextField(default="[]")
    feed_pane_size    = models.IntegerField(default=242)
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
    
    def __str__(self):
        return "%s <%s> (Premium: %s)" % (self.user, self.user.email, self.is_premium)
    
    @property
    def unread_cutoff(self, force_premium=False):
        if self.is_premium or force_premium:
            return datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
        
        return datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD_FREE)

    @property
    def unread_cutoff_premium(self):
        return datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
        
    def canonical(self):
        return {
            'is_premium': self.is_premium,
            'premium_expire': int(self.premium_expire.strftime('%s')) if self.premium_expire else 0,
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
            print(" ---> Profile not saved. Table isn't there yet.")
    
    def delete_user(self, confirm=False, fast=False):
        if not confirm:
            print(" ---> You must pass confirm=True to delete this user.")
            return
        
        logging.user(self.user, "Deleting user: %s / %s" % (self.user.email, self.user.profile.last_seen_ip))
        try:
            self.cancel_premium()
        except:
            logging.user(self.user, "~BR~SK~FWError cancelling premium renewal for: %s" % self.user.username)
        
        from apps.social.models import MSocialProfile, MSharedStory, MSocialSubscription
        from apps.social.models import MActivity, MInteraction
        try:
            social_profile = MSocialProfile.objects.get(user_id=self.user.pk)
            logging.user(self.user, "Unfollowing %s followings and %s followers" %
                         (social_profile.following_count,
                         social_profile.follower_count))
            for follow in social_profile.following_user_ids:
                social_profile.unfollow_user(follow)
            for follower in social_profile.follower_user_ids:
                follower_profile = MSocialProfile.objects.get(user_id=follower)
                follower_profile.unfollow_user(self.user.pk)
            social_profile.delete()
        except (MSocialProfile.DoesNotExist, IndexError):
            logging.user(self.user, " ***> No social profile found. S'ok, moving on.")
            pass
        
        shared_stories = MSharedStory.objects.filter(user_id=self.user.pk)
        logging.user(self.user, "Deleting %s shared stories" % shared_stories.count())
        for story in shared_stories:
            try:
                if not fast:
                    original_story = MStory.objects.get(story_hash=story.story_hash)
                    original_story.sync_redis()
            except MStory.DoesNotExist:
                pass
            story.delete()
            
        subscriptions = MSocialSubscription.objects.filter(subscription_user_id=self.user.pk)
        logging.user(self.user, "Deleting %s social subscriptions" % subscriptions.count())
        subscriptions.delete()
        
        interactions = MInteraction.objects.filter(user_id=self.user.pk)
        logging.user(self.user, "Deleting %s interactions for user." % interactions.count())
        interactions.delete()
        
        interactions = MInteraction.objects.filter(with_user_id=self.user.pk)
        logging.user(self.user, "Deleting %s interactions with user." % interactions.count())
        interactions.delete()
        
        activities = MActivity.objects.filter(user_id=self.user.pk)
        logging.user(self.user, "Deleting %s activities for user." % activities.count())
        activities.delete()
        
        activities = MActivity.objects.filter(with_user_id=self.user.pk)
        logging.user(self.user, "Deleting %s activities with user." % activities.count())
        activities.delete()
        
        starred_stories = MStarredStory.objects.filter(user_id=self.user.pk)
        logging.user(self.user, "Deleting %s starred stories." % starred_stories.count())
        starred_stories.delete()
        
        logging.user(self.user, "Deleting user: %s" % self.user)
        self.user.delete()
    
    def activate_premium(self, never_expire=False):
        from apps.profile.tasks import EmailNewPremium
        
        EmailNewPremium.delay(user_id=self.user.pk)
        
        was_premium = self.is_premium
        self.is_premium = True
        self.save()
        self.user.is_active = True
        self.user.save()
        
        # Only auto-enable every feed if a free user is moving to premium
        subs = UserSubscription.objects.filter(user=self.user)
        if not was_premium:
            for sub in subs:
                if sub.active: continue
                sub.active = True
                try:
                    sub.save()
                except (IntegrityError, Feed.DoesNotExist):
                    pass
    
        try:
            scheduled_feeds = [sub.feed.pk for sub in subs]
        except Feed.DoesNotExist:
            scheduled_feeds = []
        logging.user(self.user, "~SN~FMTasking the scheduling immediate premium setup of ~SB%s~SN feeds..." % 
                     len(scheduled_feeds))
        SchedulePremiumSetup.apply_async(kwargs=dict(feed_ids=scheduled_feeds))
    
        UserSubscription.queue_new_feeds(self.user)
        
        self.setup_premium_history()
        
        if never_expire:
            self.premium_expire = None
            self.save()
        
        logging.user(self.user, "~BY~SK~FW~SBNEW PREMIUM ACCOUNT! WOOHOO!!! ~FR%s subscriptions~SN!" % (subs.count()))
        
        return True
    
    def deactivate_premium(self):
        self.is_premium = False
        self.save()
        
        subs = UserSubscription.objects.filter(user=self.user)
        for sub in subs:
            sub.active = False
            try:
                sub.save()
                # Don't bother recalculating feed's subs, as it will do that on next fetch
                # sub.feed.setup_feed_for_premium_subscribers()
            except (IntegrityError, Feed.DoesNotExist):
                pass
        
        logging.user(self.user, "~BY~FW~SBBOO! Deactivating premium account: ~FR%s subscriptions~SN!" % (subs.count()))
    
    def activate_free(self):
        if self.user.is_active:
            return
        
        self.user.is_active = True
        self.user.save()
        self.send_new_user_queue_email()
        
    def setup_premium_history(self, alt_email=None, set_premium_expire=True, force_expiration=False):
        paypal_payments = []
        stripe_payments = []
        total_stripe_payments = 0
        existing_history = PaymentHistory.objects.filter(user=self.user, 
                                                         payment_provider__in=['paypal', 'stripe'])
        if existing_history.count():
            logging.user(self.user, "~BY~SN~FRDeleting~FW existing history: ~SB%s payments" % existing_history.count())
            existing_history.delete()
        
        # Record Paypal payments
        paypal_payments = PayPalIPN.objects.filter(custom=self.user.username,
                                                   payment_status='Completed',
                                                   txn_type='subscr_payment')
        if not paypal_payments.count():
            paypal_payments = PayPalIPN.objects.filter(payer_email=self.user.email,
                                                       payment_status='Completed',
                                                       txn_type='subscr_payment')
        if alt_email and not paypal_payments.count():
            paypal_payments = PayPalIPN.objects.filter(payer_email=alt_email,
                                                       payment_status='Completed',
                                                       txn_type='subscr_payment')
            if paypal_payments.count():
                # Make sure this doesn't happen again, so let's use Paypal's email.
                self.user.email = alt_email
                self.user.save()
        seen_txn_ids = set()
        for payment in paypal_payments:
            if payment.txn_id in seen_txn_ids: continue
            seen_txn_ids.add(payment.txn_id)
            PaymentHistory.objects.create(user=self.user,
                                          payment_date=payment.payment_date,
                                          payment_amount=payment.payment_gross,
                                          payment_provider='paypal')
                
        # Record Stripe payments
        if self.stripe_id:
            self.retrieve_stripe_ids()
            
            stripe.api_key = settings.STRIPE_SECRET
            seen_payments = set()
            for stripe_id_model in self.user.stripe_ids.all():
                stripe_id = stripe_id_model.stripe_id
                stripe_customer = stripe.Customer.retrieve(stripe_id)
                stripe_payments = stripe.Charge.all(customer=stripe_customer.id).data
                
                for payment in stripe_payments:
                    created = datetime.datetime.fromtimestamp(payment.created)
                    if payment.status == 'failed': continue
                    if created in seen_payments: continue
                    seen_payments.add(created)
                    total_stripe_payments += 1
                    PaymentHistory.objects.get_or_create(user=self.user,
                                                         payment_date=created,
                                                         payment_amount=payment.amount / 100.0,
                                                         payment_provider='stripe')
        
        # Calculate payments in last year, then add together
        payment_history = PaymentHistory.objects.filter(user=self.user)
        last_year = datetime.datetime.now() - datetime.timedelta(days=364)
        recent_payments_count = 0
        oldest_recent_payment_date = None
        free_lifetime_premium = False
        for payment in payment_history:
            if payment.payment_amount == 0:
                free_lifetime_premium = True
            if payment.payment_date > last_year:
                recent_payments_count += 1
                if not oldest_recent_payment_date or payment.payment_date < oldest_recent_payment_date:
                    oldest_recent_payment_date = payment.payment_date
        
        if free_lifetime_premium:
            logging.user(self.user, "~BY~SN~FWFree lifetime premium")
            self.premium_expire = None
            self.save()
        elif oldest_recent_payment_date:
            new_premium_expire = (oldest_recent_payment_date +
                                  datetime.timedelta(days=365*recent_payments_count))
            # Only move premium expire forward, never earlier. Also set expiration if not premium.
            if (force_expiration or 
                (set_premium_expire and not self.premium_expire) or 
                (self.premium_expire and new_premium_expire > self.premium_expire)):
                self.premium_expire = new_premium_expire
                self.save()

        logging.user(self.user, "~BY~SN~FWFound ~SB~FB%s paypal~FW~SN and ~SB~FC%s stripe~FW~SN payments (~SB%s payments expire: ~SN~FB%s~FW)" % (
                     len(paypal_payments), total_stripe_payments, len(payment_history), self.premium_expire))

        if (set_premium_expire and not self.is_premium and
            (not self.premium_expire or self.premium_expire > datetime.datetime.now())):
            self.activate_premium()

    @classmethod
    def reimport_stripe_history(cls, limit=10, days=7, starting_after=None):
        stripe.api_key = settings.STRIPE_SECRET
        week = (datetime.datetime.now() - datetime.timedelta(days=days)).strftime('%s')
        failed = []
        i = 0
        
        while True:
            logging.debug(" ---> At %s / %s" % (i, starting_after))
            i += 1
            try:
                data = stripe.Charge.all(created={'gt': week}, count=limit, starting_after=starting_after)
            except stripe.APIConnectionError:
                time.sleep(10)
                continue
            charges = data['data']
            if not len(charges):
                logging.debug("At %s (%s), finished" % (i, starting_after))
                break
            starting_after = charges[-1]["id"]
            customers = [c['customer'] for c in charges if 'customer' in c]
            for customer in customers:
                if not customer:
                    print(" ***> No customer!")
                    continue
                try:
                    profile = Profile.objects.get(stripe_id=customer)
                    user = profile.user
                except Profile.DoesNotExist:
                    logging.debug(" ***> Couldn't find stripe_id=%s" % customer)
                    failed.append(customer)
                    continue
                except Profile.MultipleObjectsReturned:
                    logging.debug(" ***> Multiple stripe_id=%s" % customer)
                    failed.append(customer)
                    continue
                try:
                    user.profile.setup_premium_history()
                except stripe.APIConnectionError:
                    logging.debug(" ***> Failed: %s" % user.username)
                    failed.append(user.username)
                    time.sleep(2)
                    continue

        return ','.join(failed)
        
    def refund_premium(self, partial=False):
        refunded = False
        
        if self.stripe_id:
            stripe.api_key = settings.STRIPE_SECRET
            stripe_customer = stripe.Customer.retrieve(self.stripe_id)
            stripe_payments = stripe.Charge.all(customer=stripe_customer.id).data
            if partial:
                stripe_payments[0].refund(amount=1200)
                refunded = 12
            else:
                stripe_payments[0].refund()
                self.cancel_premium()
                refunded = stripe_payments[0].amount/100
            logging.user(self.user, "~FRRefunding stripe payment: $%s" % refunded)
        else:
            self.cancel_premium()

            paypal_opts = {
                'API_ENVIRONMENT': 'PRODUCTION',
                'API_USERNAME': settings.PAYPAL_API_USERNAME,
                'API_PASSWORD': settings.PAYPAL_API_PASSWORD,
                'API_SIGNATURE': settings.PAYPAL_API_SIGNATURE,
                'API_CA_CERTS': False,
            }
            paypal = PayPalInterface(**paypal_opts)
            transactions = PayPalIPN.objects.filter(custom=self.user.username,
                                                    txn_type='subscr_payment'
                                                    ).order_by('-payment_date')
            if not transactions:
                transactions = PayPalIPN.objects.filter(payer_email=self.user.email,
                                                        txn_type='subscr_payment'
                                                        ).order_by('-payment_date')
            if transactions:
                transaction = transactions[0]
                refund = paypal.refund_transaction(transaction.txn_id)
                try:
                    refunded = int(float(refund.raw['TOTALREFUNDEDAMOUNT'][0]))
                except KeyError:
                    refunded = int(transaction.payment_gross)
                logging.user(self.user, "~FRRefunding paypal payment: $%s" % refunded)
            else:
                logging.user(self.user, "~FRCouldn't refund paypal payment: not found by username or email")
                refunded = 0
                    
        
        return refunded
            
    def cancel_premium(self):
        paypal_cancel = self.cancel_premium_paypal()
        stripe_cancel = self.cancel_premium_stripe()
        return stripe_cancel or paypal_cancel
    
    def cancel_premium_paypal(self, second_most_recent_only=False):
        transactions = PayPalIPN.objects.filter(custom=self.user.username,
                                                txn_type='subscr_signup').order_by('-subscr_date')
        
        if not transactions:
            return
        
        paypal_opts = {
            'API_ENVIRONMENT': 'PRODUCTION',
            'API_USERNAME': settings.PAYPAL_API_USERNAME,
            'API_PASSWORD': settings.PAYPAL_API_PASSWORD,
            'API_SIGNATURE': settings.PAYPAL_API_SIGNATURE,
            'API_CA_CERTS': False,
        }
        paypal = PayPalInterface(**paypal_opts)
        if second_most_recent_only:
            # Check if user has an active subscription. If so, cancel it because a new one came in.
            if len(transactions) > 1:
                transaction = transactions[1]
            else:
                return False
        else:
            transaction = transactions[0]
        profileid = transaction.subscr_id
        try:
            paypal.manage_recurring_payments_profile_status(profileid=profileid, action='Cancel')
        except PayPalAPIResponseError:
            logging.user(self.user, "~FRUser ~SBalready~SN canceled Paypal subscription: %s" % profileid)
        else:
            if second_most_recent_only:
                logging.user(self.user, "~FRCanceling ~BR~FWsecond-oldest~SB~FR Paypal subscription: %s" % profileid)
            else:
                logging.user(self.user, "~FRCanceling Paypal subscription: %s" % profileid)
        
        return True
        
    def cancel_premium_stripe(self):
        if not self.stripe_id:
            return
            
        stripe.api_key = settings.STRIPE_SECRET
        stripe_customer = stripe.Customer.retrieve(self.stripe_id)
        try:
            stripe_customer.cancel_subscription()
        except stripe.InvalidRequestError:
            logging.user(self.user, "~FRFailed to cancel Stripe subscription")

        logging.user(self.user, "~FRCanceling Stripe subscription")
        
        return True
    
    def retrieve_stripe_ids(self):
        if not self.stripe_id:
            return
        
        stripe.api_key = settings.STRIPE_SECRET
        stripe_customer = stripe.Customer.retrieve(self.stripe_id)
        stripe_email = stripe_customer.email
        
        stripe_ids = set()
        for email in set([stripe_email, self.user.email]):
            customers = stripe.Customer.list(email=email)
            for customer in customers:
                stripe_ids.add(customer.stripe_id)
        
        self.user.stripe_ids.all().delete()
        for stripe_id in stripe_ids:
            self.user.stripe_ids.create(stripe_id=stripe_id)
        
    @property
    def latest_paypal_email(self):
        ipn = PayPalIPN.objects.filter(custom=self.user.username)
        if not len(ipn):
            return
        
        return ipn[0].payer_email
    
    def activate_ios_premium(self, product_identifier, transaction_identifier, amount=36):
        payments = PaymentHistory.objects.filter(user=self.user,
                                                 payment_identifier=transaction_identifier,
                                                 payment_date__gte=datetime.datetime.now()-datetime.timedelta(days=3))
        if len(payments):
            # Already paid
            logging.user(self.user, "~FG~BBAlready paid iOS premium subscription: $%s~FW" % transaction_identifier)
            return False

        PaymentHistory.objects.create(user=self.user,
                                      payment_date=datetime.datetime.now(),
                                      payment_amount=amount,
                                      payment_provider='ios-subscription',
                                      payment_identifier=transaction_identifier)
        
        self.setup_premium_history()
                                      
        if not self.is_premium:
            self.activate_premium()
        
        logging.user(self.user, "~FG~BBNew iOS premium subscription: $%s~FW" % product_identifier)
        return True
        
    @classmethod
    def clear_dead_spammers(self, days=30, confirm=False):
        users = User.objects.filter(date_joined__gte=datetime.datetime.now()-datetime.timedelta(days=days)).order_by('-date_joined')
        usernames = set()
        numerics = re.compile(r'[0-9]+')
        for user in users:
            opens = UserSubscription.objects.filter(user=user).aggregate(sum=Sum('feed_opens'))['sum']
            reads = RUserStory.read_story_count(user.pk)
            has_numbers = numerics.search(user.username)

            try:
                has_profile = user.profile.last_seen_ip
            except Profile.DoesNotExist:
                usernames.add(user.username)
                print(" ---> Missing profile: %-20s %-30s %-6s %-6s" % (user.username, user.email, opens, reads))
                continue

            if opens is None and not reads and has_numbers:
                usernames.add(user.username)
                print(" ---> Numerics: %-20s %-30s %-6s %-6s" % (user.username, user.email, opens, reads))
            elif not has_profile:
                usernames.add(user.username)
                print(" ---> No IP: %-20s %-30s %-6s %-6s" % (user.username, user.email, opens, reads))
        
        if not confirm: return usernames
        
        for username in usernames:
            try:
                u = User.objects.get(username=username)
            except User.DoesNotExist:
                continue
            u.profile.delete_user(confirm=True)

        RNewUserQueue.user_count()
        RNewUserQueue.activate_all()
        
    @classmethod
    def count_feed_subscribers(self, feed_id=None, user_id=None, verbose=True):
        SUBSCRIBER_EXPIRE = datetime.datetime.now() - datetime.timedelta(days=settings.SUBSCRIBER_EXPIRE)
        r = redis.Redis(connection_pool=settings.REDIS_FEED_SUB_POOL)
        entire_feed_counted = False
        
        if verbose:
            feed = Feed.get_by_id(feed_id)
            logging.debug("   ---> [%-30s] ~SN~FBCounting subscribers for feed:~SB~FM%s~SN~FB user:~SB~FM%s" % (feed.log_title[:30], feed_id, user_id))
        
        if feed_id:
            feed_ids = [feed_id]
        elif user_id:
            feed_ids = [us['feed_id'] for us in UserSubscription.objects.filter(user=user_id, active=True).values('feed_id')]
        else:
            assert False, "feed_id or user_id required"

        if feed_id and not user_id:
            entire_feed_counted = True
            
        for feed_id in feed_ids:
            total = 0
            premium = 0
            active = 0
            active_premium = 0
            key = 's:%s' % feed_id
            premium_key = 'sp:%s' % feed_id
            
            if user_id:
                active = UserSubscription.objects.get(feed_id=feed_id, user_id=user_id).only('active').active
                user_ids = dict([(user_id, active)])
            else:
                user_ids = dict([(us.user_id, us.active) 
                                 for us in UserSubscription.objects.filter(feed_id=feed_id).only('user', 'active')])
            profiles = Profile.objects.filter(user_id__in=list(user_ids.keys())).values('user_id', 'last_seen_on', 'is_premium')
            feed = Feed.get_by_id(feed_id)
            
            if entire_feed_counted:
                r.delete(key)
                r.delete(premium_key)
            
            for profiles_group in chunks(profiles, 20):
                pipeline = r.pipeline()
                for profile in profiles_group:
                    last_seen_on = int(profile['last_seen_on'].strftime('%s'))
                    muted_feed = not bool(user_ids[profile['user_id']])
                    if muted_feed:
                        last_seen_on = 0
                    pipeline.zadd(key, { profile['user_id']: last_seen_on })
                    total += 1
                    if profile['is_premium']:
                        pipeline.zadd(premium_key, { profile['user_id']: last_seen_on })
                        premium += 1
                    else:
                        pipeline.zrem(premium_key, profile['user_id'])
                    if profile['last_seen_on'] > SUBSCRIBER_EXPIRE and not muted_feed:
                        active += 1
                        if profile['is_premium']:
                            active_premium += 1
                
                pipeline.execute()
            
            if entire_feed_counted:
                now = int(datetime.datetime.now().strftime('%s'))
                r.zadd(key, { -1: now })
                r.expire(key, settings.SUBSCRIBER_EXPIRE*24*60*60)
                r.zadd(premium_key, {-1: now})
                r.expire(premium_key, settings.SUBSCRIBER_EXPIRE*24*60*60)
            
            logging.info("   ---> [%-30s] ~SN~FBCounting subscribers, storing in ~SBredis~SN: ~FMt:~SB~FM%s~SN a:~SB%s~SN p:~SB%s~SN ap:~SB%s" % 
                          (feed.log_title[:30], total, active, premium, active_premium))

    @classmethod
    def count_all_feed_subscribers_for_user(self, user):
        r = redis.Redis(connection_pool=settings.REDIS_FEED_SUB_POOL)
        if not isinstance(user, User):
            user = User.objects.get(pk=user)
        
        active_feed_ids = [us['feed_id'] for us in UserSubscription.objects.filter(user=user.pk, active=True).values('feed_id')]
        muted_feed_ids = [us['feed_id'] for us in UserSubscription.objects.filter(user=user.pk, active=False).values('feed_id')]
        logging.user(user, "~SN~FBRefreshing user last_login_on for ~SB%s~SN/~SB%s subscriptions~SN" % 
                     (len(active_feed_ids), len(muted_feed_ids)))
        for feed_ids in [active_feed_ids, muted_feed_ids]:
            for feeds_group in chunks(feed_ids, 20):
                pipeline = r.pipeline()
                for feed_id in feeds_group:
                    key = 's:%s' % feed_id
                    premium_key = 'sp:%s' % feed_id

                    last_seen_on = int(user.profile.last_seen_on.strftime('%s'))
                    if feed_ids is muted_feed_ids:
                        last_seen_on = 0
                    pipeline.zadd(key, { user.pk: last_seen_on })
                    if user.profile.is_premium:
                        pipeline.zadd(premium_key, { user.pk: last_seen_on })
                    else:
                        pipeline.zrem(premium_key, user.pk)
                pipeline.execute()
    
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
    
    def send_opml_export_email(self, reason=None, force=False):
        if not self.user.email:
            return
        
        emails_sent = MSentEmail.objects.filter(receiver_user_id=self.user.pk,
                                                email_type='opml_export')
        day_ago = datetime.datetime.now() - datetime.timedelta(days=1)
        for email in emails_sent:
            if email.date_sent > day_ago and not force:
                logging.user(self.user, "~SN~FMNot sending opml export email, already sent today.")
                return

        MSentEmail.record(receiver_user_id=self.user.pk, email_type='opml_export')
        
        exporter = OPMLExporter(self.user)
        opml     = exporter.process()

        params = {
            'feed_count': UserSubscription.objects.filter(user=self.user).count(),
            'reason': reason,
        }
        user    = self.user
        text    = render_to_string('mail/email_opml_export.txt', params)
        html    = render_to_string('mail/email_opml_export.xhtml', params)
        subject = "Backup OPML file of your NewsBlur sites"
        filename= 'NewsBlur Subscriptions - %s.xml' % datetime.datetime.now().strftime('%Y-%m-%d')
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.attach(filename, opml, 'text/xml')
        msg.send(fail_silently=True)
        
        logging.user(self.user, "~BB~FM~SBSending OPML backup email to: %s" % self.user.email)
    
    def send_first_share_to_blurblog_email(self, force=False):
        from apps.social.models import MSocialProfile, MSharedStory
        
        if not self.user.email:
            return
        
        params = dict(receiver_user_id=self.user.pk, email_type='first_share')
        try:
            MSentEmail.objects.get(**params)
            if not force:
                # Return if email already sent
                return
        except MSentEmail.DoesNotExist:
            MSentEmail.objects.create(**params)
                
        social_profile = MSocialProfile.objects.get(user_id=self.user.pk)
        params = {
            'shared_stories': MSharedStory.objects.filter(user_id=self.user.pk).count(),
            'blurblog_url': social_profile.blurblog_url,
            'blurblog_rss': social_profile.blurblog_rss
        }
        user    = self.user
        text    = render_to_string('mail/email_first_share_to_blurblog.txt', params)
        html    = render_to_string('mail/email_first_share_to_blurblog.xhtml', params)
        subject = "Your shared stories on NewsBlur are available on your Blurblog"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send(fail_silently=True)
        
        logging.user(self.user, "~BB~FM~SBSending first share to blurblog email to: %s" % self.user.email)
    
    def send_new_premium_email(self, force=False):
        # subs = UserSubscription.objects.filter(user=self.user)
#         message = """Woohoo!
#
# User: %(user)s
# Feeds: %(feeds)s
#
# Sincerely,
# NewsBlur""" % {'user': self.user.username, 'feeds': subs.count()}
        # mail_admins('New premium account', message, fail_silently=True)
        
        if not self.user.email or not self.send_emails:
            return
        
        params = dict(receiver_user_id=self.user.pk, email_type='new_premium')
        try:
            MSentEmail.objects.get(**params)
            if not force:
                # Return if email already sent
                return
        except MSentEmail.DoesNotExist:
            MSentEmail.objects.create(**params)

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
            print("Please provide an email address.")
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
        
        logging.user(self.user, "~BB~FM~SBSending email for forgotten password: %s" % self.user.email)
    
    def send_new_user_queue_email(self, force=False):
        if not self.user.email:
            print("Please provide an email address.")
            return
        
        params = dict(receiver_user_id=self.user.pk, email_type='new_user_queue')
        try:
            MSentEmail.objects.get(**params)
            if not force:
                # Return if email already sent
                return
        except MSentEmail.DoesNotExist:
            MSentEmail.objects.create(**params)

        user    = self.user
        text    = render_to_string('mail/email_new_user_queue.txt', locals())
        html    = render_to_string('mail/email_new_user_queue.xhtml', locals())
        subject = "Your free account is now ready to go on NewsBlur"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send(fail_silently=True)
        
        logging.user(self.user, "~BB~FM~SBSending email for new user queue: %s" % self.user.email)
    
    def send_upload_opml_finished_email(self, feed_count):
        if not self.user.email:
            print("Please provide an email address.")
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
    
    def send_import_reader_finished_email(self, feed_count):
        if not self.user.email:
            print("Please provide an email address.")
            return
        
        user    = self.user
        text    = render_to_string('mail/email_import_reader_finished.txt', locals())
        html    = render_to_string('mail/email_import_reader_finished.xhtml', locals())
        subject = "Your Google Reader import is complete. Get going with NewsBlur!"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send()
                
        logging.user(self.user, "~BB~FM~SBSending email for Google Reader import: %s" % self.user.email)
    
    def send_import_reader_starred_finished_email(self, feed_count, starred_count):
        if not self.user.email:
            print("Please provide an email address.")
            return
        
        user    = self.user
        text    = render_to_string('mail/email_import_reader_starred_finished.txt', locals())
        html    = render_to_string('mail/email_import_reader_starred_finished.xhtml', locals())
        subject = "Your Google Reader starred stories import is complete. Get going with NewsBlur!"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send()
                
        logging.user(self.user, "~BB~FM~SBSending email for Google Reader starred stories import: %s" % self.user.email)
    
    def send_launch_social_email(self, force=False):
        if not self.user.email or not self.send_emails:
            logging.user(self.user, "~FM~SB~FRNot~FM sending launch social email for user, %s: %s" % (self.user.email and 'opt-out: ' or 'blank', self.user.email))
            return
        
        params = dict(receiver_user_id=self.user.pk, email_type='launch_social')
        try:
            MSentEmail.objects.get(**params)
            if not force:
                # Return if email already sent
                logging.user(self.user, "~FM~SB~FRNot~FM sending launch social email for user, sent already: %s" % self.user.email)
                return
        except MSentEmail.DoesNotExist:
            MSentEmail.objects.create(**params)
        
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
    
    def send_launch_turntouch_email(self, force=False):
        if not self.user.email or not self.send_emails:
            logging.user(self.user, "~FM~SB~FRNot~FM sending launch TT email for user, %s: %s" % (self.user.email and 'opt-out: ' or 'blank', self.user.email))
            return
        
        params = dict(receiver_user_id=self.user.pk, email_type='launch_turntouch')
        try:
            MSentEmail.objects.get(**params)
            if not force:
                # Return if email already sent
                logging.user(self.user, "~FM~SB~FRNot~FM sending launch social email for user, sent already: %s" % self.user.email)
                return
        except MSentEmail.DoesNotExist:
            MSentEmail.objects.create(**params)
        
        delta      = datetime.datetime.now() - self.last_seen_on
        months_ago = delta.days / 30
        user    = self.user
        data    = dict(user=user, months_ago=months_ago)
        text    = render_to_string('mail/email_launch_turntouch.txt', data)
        html    = render_to_string('mail/email_launch_turntouch.xhtml', data)
        subject = "Introducing Turn Touch for NewsBlur"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send(fail_silently=True)
        
        logging.user(self.user, "~BB~FM~SBSending launch TT email for user: %s months, %s" % (months_ago, self.user.email))

    def send_launch_turntouch_end_email(self, force=False):
        if not self.user.email or not self.send_emails:
            logging.user(self.user, "~FM~SB~FRNot~FM sending launch TT end email for user, %s: %s" % (self.user.email and 'opt-out: ' or 'blank', self.user.email))
            return
        
        params = dict(receiver_user_id=self.user.pk, email_type='launch_turntouch_end')
        try:
            MSentEmail.objects.get(**params)
            if not force:
                # Return if email already sent
                logging.user(self.user, "~FM~SB~FRNot~FM sending launch TT end email for user, sent already: %s" % self.user.email)
                return
        except MSentEmail.DoesNotExist:
            MSentEmail.objects.create(**params)
        
        delta      = datetime.datetime.now() - self.last_seen_on
        months_ago = delta.days / 30
        user    = self.user
        data    = dict(user=user, months_ago=months_ago)
        text    = render_to_string('mail/email_launch_turntouch_end.txt', data)
        html    = render_to_string('mail/email_launch_turntouch_end.xhtml', data)
        subject = "Last day to back Turn Touch: NewsBlur's beautiful remote"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send(fail_silently=True)
        
        logging.user(self.user, "~BB~FM~SBSending launch TT end email for user: %s months, %s" % (months_ago, self.user.email))
    
    def grace_period_email_sent(self, force=False):
        emails_sent = MSentEmail.objects.filter(receiver_user_id=self.user.pk,
                                                email_type='premium_expire_grace')
        day_ago = datetime.datetime.now() - datetime.timedelta(days=360)
        for email in emails_sent:
            if email.date_sent > day_ago and not force:
                logging.user(self.user, "~SN~FMNot sending premium expire grace email, already sent before.")
                return True
        
    def send_premium_expire_grace_period_email(self, force=False):
        if not self.user.email:
            logging.user(self.user, "~FM~SB~FRNot~FM~SN sending premium expire grace for user: %s" % (self.user))
            return

        if self.grace_period_email_sent(force=force):
            return
            
        if self.premium_expire and self.premium_expire < datetime.datetime.now():
            self.premium_expire = datetime.datetime.now()
        self.save()
        
        delta      = datetime.datetime.now() - self.last_seen_on
        months_ago = delta.days / 30
        user    = self.user
        data    = dict(user=user, months_ago=months_ago)
        text    = render_to_string('mail/email_premium_expire_grace.txt', data)
        html    = render_to_string('mail/email_premium_expire_grace.xhtml', data)
        subject = "Your premium account on NewsBlur has one more month!"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send(fail_silently=True)
        
        MSentEmail.record(receiver_user_id=self.user.pk, email_type='premium_expire_grace')
        logging.user(self.user, "~BB~FM~SBSending premium expire grace email for user: %s months, %s" % (months_ago, self.user.email))
        
    def send_premium_expire_email(self, force=False):
        if not self.user.email:
            logging.user(self.user, "~FM~SB~FRNot~FM sending premium expire for user: %s" % (self.user))
            return

        emails_sent = MSentEmail.objects.filter(receiver_user_id=self.user.pk,
                                                email_type='premium_expire')
        day_ago = datetime.datetime.now() - datetime.timedelta(days=360)
        for email in emails_sent:
            if email.date_sent > day_ago and not force:
                logging.user(self.user, "~FM~SBNot sending premium expire email, already sent before.")
                return
        
        delta      = datetime.datetime.now() - self.last_seen_on
        months_ago = delta.days / 30
        user    = self.user
        data    = dict(user=user, months_ago=months_ago)
        text    = render_to_string('mail/email_premium_expire.txt', data)
        html    = render_to_string('mail/email_premium_expire.xhtml', data)
        subject = "Your premium account on NewsBlur has expired"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send(fail_silently=True)
        
        MSentEmail.record(receiver_user_id=self.user.pk, email_type='premium_expire')
        logging.user(self.user, "~BB~FM~SBSending premium expire email for user: %s months, %s" % (months_ago, self.user.email))
    
    def autologin_url(self, next=None):
        return reverse('autologin', kwargs={
            'username': self.user.username, 
            'secret': self.secret_token
        }) + ('?' + next + '=1' if next else '')
        
    
    @classmethod
    def doublecheck_paypal_payments(cls, days=14):
        payments = PayPalIPN.objects.filter(txn_type='subscr_payment', 
                                            updated_at__gte=datetime.datetime.now()
                                                            - datetime.timedelta(days)
                                            ).order_by('-created_at')
        for payment in payments:
            try:
                profile = Profile.objects.get(user__username=payment.custom)
            except Profile.DoesNotExist:
                logging.debug(" ---> ~FRCouldn't find user: ~SB~FC%s" % payment.custom)
                continue
            profile.setup_premium_history()
        

class StripeIds(models.Model):
    user = models.ForeignKey(User, related_name='stripe_ids', on_delete=models.CASCADE, null=True)
    stripe_id = models.CharField(max_length=24, blank=True, null=True)

    def __str__(self):
        return "%s: %s" % (self.user.username, self.stripe_id)

        
def create_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)
    else:
        Profile.objects.get_or_create(user=instance)
post_save.connect(create_profile, sender=User)


def paypal_signup(sender, **kwargs):
    ipn_obj = sender
    try:
        user = User.objects.get(username__iexact=ipn_obj.custom)
    except User.DoesNotExist:
        user = User.objects.get(email__iexact=ipn_obj.payer_email)
    logging.user(user, "~BC~SB~FBPaypal subscription signup")
    try:
        if not user.email:
            user.email = ipn_obj.payer_email
            user.save()
    except:
        pass
    user.profile.activate_premium()
    user.profile.cancel_premium_stripe()
    user.profile.cancel_premium_paypal(second_most_recent_only=True)
valid_ipn_received.connect(paypal_signup)

def paypal_payment_history_sync(sender, **kwargs):
    ipn_obj = sender
    try:
        user = User.objects.get(username__iexact=ipn_obj.custom)
    except User.DoesNotExist:
        user = User.objects.get(email__iexact=ipn_obj.payer_email)
    logging.user(user, "~BC~SB~FBPaypal subscription payment")
    try:
        user.profile.setup_premium_history()
    except:
        return {"code": -1, "message": "User doesn't exist."}
valid_ipn_received.connect(paypal_payment_history_sync)

def paypal_payment_was_flagged(sender, **kwargs):
    ipn_obj = sender
    try:
        user = User.objects.get(username__iexact=ipn_obj.custom)
    except User.DoesNotExist:
        if ipn_obj.payer_email:
            user = User.objects.get(email__iexact=ipn_obj.payer_email)
    try:
        user.profile.setup_premium_history()
        logging.user(user, "~BC~SB~FBPaypal subscription payment flagged")
    except:
        return {"code": -1, "message": "User doesn't exist."}
invalid_ipn_received.connect(paypal_payment_was_flagged)

def paypal_recurring_payment_history_sync(sender, **kwargs):
    ipn_obj = sender
    try:
        user = User.objects.get(username__iexact=ipn_obj.custom)
    except User.DoesNotExist:
        user = User.objects.get(email__iexact=ipn_obj.payer_email)
    logging.user(user, "~BC~SB~FBPaypal subscription recurring payment")
    try:
        user.profile.setup_premium_history()
    except:
        return {"code": -1, "message": "User doesn't exist."}
valid_ipn_received.connect(paypal_recurring_payment_history_sync)

def stripe_signup(sender, full_json, **kwargs):
    stripe_id = full_json['data']['object']['customer']
    try:
        profile = Profile.objects.get(stripe_id=stripe_id)
        logging.user(profile.user, "~BC~SB~FBStripe subscription signup")
        profile.activate_premium()
        profile.cancel_premium_paypal()
        profile.retrieve_stripe_ids()
    except Profile.DoesNotExist:
        return {"code": -1, "message": "User doesn't exist."}
zebra_webhook_customer_subscription_created.connect(stripe_signup)

def stripe_payment_history_sync(sender, full_json, **kwargs):
    stripe_id = full_json['data']['object']['customer']
    try:
        profile = Profile.objects.get(stripe_id=stripe_id)
        logging.user(profile.user, "~BC~SB~FBStripe subscription payment")
        profile.setup_premium_history()
    except Profile.DoesNotExist:
        return {"code": -1, "message": "User doesn't exist."}    
zebra_webhook_charge_succeeded.connect(stripe_payment_history_sync)

def change_password(user, old_password, new_password, only_check=False):
    user_db = authenticate(username=user.username, password=old_password)
    if user_db is None:
        blank = blank_authenticate(user.username)
        if blank and not only_check:
            user.set_password(new_password or user.username)
            user.save()
    if user_db is None:
        user_db = authenticate(username=user.username, password=user.username)
        
    if not user_db:
        return -1
    else:
        if not only_check:
            user_db.set_password(new_password)
            user_db.save()
        return 1

def blank_authenticate(username, password=""):
    try:
        user = User.objects.get(username__iexact=username)
    except User.DoesNotExist:
        return
    
    if user.password == "!":
        return user
        
    algorithm, salt, hash = user.password.split('$', 2)
    encoded_blank = hashlib.sha1((salt + password).encode(encoding='utf-8')).hexdigest()
    encoded_username = authenticate(username=username, password=username)
    if encoded_blank == hash or encoded_username == user:
        return user

# Unfinished
class MEmailUnsubscribe(mongo.Document):
    user_id = mongo.IntField()
    email_type = mongo.StringField()
    date = mongo.DateTimeField(default=datetime.datetime.now)
    
    EMAIL_TYPE_FOLLOWS = 'follows'
    EMAIL_TYPE_REPLIES = 'replies'
    EMAIL_TYOE_PRODUCT = 'product'
    
    meta = {
        'collection': 'email_unsubscribes',
        'allow_inheritance': False,
        'indexes': ['user_id', 
                    {'fields': ['user_id', 'email_type'], 
                     'unique': True,
                     'types': False,
                    }],
    }
    
    def __str__(self):
        return "%s unsubscribed from %s on %s" % (self.user_id, self.email_type, self.date)
    
    @classmethod
    def user(cls, user_id):
        unsubs = cls.objects(user_id=user_id)
        return unsubs
    
    @classmethod
    def unsubscribe(cls, user_id, email_type):
        cls.objects.create()


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
    
    def __str__(self):
        return "%s sent %s email to %s" % (self.sending_user_id, self.email_type, self.receiver_user_id)
    
    @classmethod
    def record(cls, email_type, receiver_user_id, sending_user_id=None):
        cls.objects.create(email_type=email_type, 
                           receiver_user_id=receiver_user_id, 
                           sending_user_id=sending_user_id)

class PaymentHistory(models.Model):
    user = models.ForeignKey(User, related_name='payments', on_delete=models.CASCADE)
    payment_date = models.DateTimeField()
    payment_amount = models.IntegerField()
    payment_provider = models.CharField(max_length=20)
    payment_identifier = models.CharField(max_length=100, null=True)
    
    def __str__(self):
        return "[%s] $%s/%s" % (self.payment_date.strftime("%Y-%m-%d"), self.payment_amount,
                                self.payment_provider)
    class Meta:
        ordering = ['-payment_date']
        
    def canonical(self):
        return {
            'payment_date': self.payment_date.strftime('%Y-%m-%d'),
            'payment_amount': self.payment_amount,
            'payment_provider': self.payment_provider,
        }
    
    @classmethod
    def report(cls, months=26):
        output = ""
        
        def _counter(start_date, end_date, output, payments=None):
            if not payments:
                payments = PaymentHistory.objects.filter(payment_date__gte=start_date, payment_date__lte=end_date)
                payments = payments.aggregate(avg=Avg('payment_amount'), 
                                              sum=Sum('payment_amount'), 
                                              count=Count('user'))
            output += "%s-%02d-%02d - %s-%02d-%02d:\t$%.2f\t$%-6s\t%-4s\n" % (
                start_date.year, start_date.month, start_date.day,
                end_date.year, end_date.month, end_date.day,
                round(payments['avg'] if payments['avg'] else 0, 2), payments['sum'] if payments['sum'] else 0, payments['count'])
            
            return payments, output

        output += "\nMonthly Totals:\n"
        for m in reversed(list(range(months))):
            now = datetime.datetime.now()
            start_date = datetime.datetime(now.year, now.month, 1) - dateutil.relativedelta.relativedelta(months=m)
            end_time = start_date + datetime.timedelta(days=31)
            end_date = datetime.datetime(end_time.year, end_time.month, 1) - datetime.timedelta(seconds=1)
            total, output = _counter(start_date, end_date, output)
            total = total['sum']

        output += "\nMTD Totals:\n"
        years = datetime.datetime.now().year - 2009
        this_mtd_avg = 0
        last_mtd_avg = 0
        last_mtd_sum = 0
        this_mtd_sum = 0
        last_mtd_count = 0
        this_mtd_count = 0
        for y in reversed(list(range(years))):
            now = datetime.datetime.now()
            start_date = datetime.datetime(now.year, now.month, 1) - dateutil.relativedelta.relativedelta(years=y)
            end_date = now - dateutil.relativedelta.relativedelta(years=y)
            if end_date > now: end_date = now
            count, output = _counter(start_date, end_date, output)
            if end_date.year != now.year:
                last_mtd_avg = count['avg'] or 0
                last_mtd_sum = count['sum'] or 0
                last_mtd_count = count['count']
            else:
                this_mtd_avg = count['avg'] or 0
                this_mtd_sum = count['sum'] or 0
                this_mtd_count = count['count']

        output += "\nCurrent Month Totals:\n"
        years = datetime.datetime.now().year - 2009
        last_month_avg = 0
        last_month_sum = 0
        last_month_count = 0
        for y in reversed(list(range(years))):
            now = datetime.datetime.now()
            start_date = datetime.datetime(now.year, now.month, 1) - dateutil.relativedelta.relativedelta(years=y)
            end_time = start_date + datetime.timedelta(days=31)
            end_date = datetime.datetime(end_time.year, end_time.month, 1) - datetime.timedelta(seconds=1)
            if end_date > now:
                payments = {'avg': this_mtd_avg / (max(1, last_mtd_avg) / float(max(1, last_month_avg))), 
                            'sum': int(round(this_mtd_sum / (max(1, last_mtd_sum) / float(max(1, last_month_sum))))), 
                            'count': int(round(this_mtd_count / (max(1, last_mtd_count) / float(max(1, last_month_count)))))}
                _, output = _counter(start_date, end_date, output, payments=payments)
            else:
                count, output = _counter(start_date, end_date, output)
                last_month_avg = count['avg']
                last_month_sum = count['sum']
                last_month_count = count['count']

        output += "\nYTD Totals:\n"
        years = datetime.datetime.now().year - 2009
        this_ytd_avg = 0
        last_ytd_avg = 0
        this_ytd_sum = 0
        last_ytd_sum = 0
        this_ytd_count = 0
        last_ytd_count = 0
        for y in reversed(list(range(years))):
            now = datetime.datetime.now()
            start_date = datetime.datetime(now.year, 1, 1) - dateutil.relativedelta.relativedelta(years=y)
            end_date = now - dateutil.relativedelta.relativedelta(years=y)
            count, output = _counter(start_date, end_date, output)
            if end_date.year != now.year:
                last_ytd_avg = count['avg'] or 0
                last_ytd_sum = count['sum'] or 0
                last_ytd_count = count['count']
            else:
                this_ytd_avg = count['avg'] or 0
                this_ytd_sum = count['sum'] or 0
                this_ytd_count = count['count']

        output += "\nYearly Totals:\n"
        years = datetime.datetime.now().year - 2009
        last_year_avg = 0
        last_year_sum = 0
        last_year_count = 0
        annual = 0
        for y in reversed(list(range(years))):
            now = datetime.datetime.now()
            start_date = datetime.datetime(now.year, 1, 1) - dateutil.relativedelta.relativedelta(years=y)
            end_date = datetime.datetime(now.year, 1, 1) - dateutil.relativedelta.relativedelta(years=y-1) - datetime.timedelta(seconds=1)
            if end_date > now:
                payments = {'avg': this_ytd_avg / (max(1, last_ytd_avg) / float(max(1, last_year_avg))), 
                            'sum': int(round(this_ytd_sum / (max(1, last_ytd_sum) / float(max(1, last_year_sum))))), 
                            'count': int(round(this_ytd_count / (max(1, last_ytd_count) / float(max(1, last_year_count)))))}
                count, output = _counter(start_date, end_date, output, payments=payments)
                annual = count['sum']
            else:
                count, output = _counter(start_date, end_date, output)
                last_year_avg = count['avg'] or 0
                last_year_sum = count['sum'] or 0
                last_year_count = count['count']
                

        total = cls.objects.all().aggregate(sum=Sum('payment_amount'))
        output += "\nTotal: $%s\n" % total['sum']
        
        print(output)
        
        return {'annual': annual, 'output': output}


class MGiftCode(mongo.Document):
    gifting_user_id = mongo.IntField()
    receiving_user_id = mongo.IntField()
    gift_code = mongo.StringField(max_length=12)
    duration_days = mongo.IntField()
    payment_amount = mongo.IntField()
    created_date = mongo.DateTimeField(default=datetime.datetime.now)
    
    meta = {
        'collection': 'gift_codes',
        'allow_inheritance': False,
        'indexes': ['gifting_user_id', 'receiving_user_id', 'created_date'],
    }
    
    def __str__(self):
        return "%s gifted %s on %s: %s (redeemed %s times)" % (self.gifting_user_id, self.receiving_user_id, self.created_date, self.gift_code, self.redeemed)
    
    @property
    def redeemed(self):
        redeemed_code = MRedeemedCode.objects.filter(gift_code=self.gift_code)
        return len(redeemed_code)
    
    @staticmethod
    def create_code(gift_code=None):
        u = str(uuid.uuid4())
        code = u[:8] + u[9:13]
        if gift_code:
            code = gift_code + code[len(gift_code):]
        return code
        
    @classmethod
    def add(cls, gift_code=None, duration=0, gifting_user_id=None, receiving_user_id=None, payment=0):
        return cls.objects.create(gift_code=cls.create_code(gift_code), 
                                   gifting_user_id=gifting_user_id,
                                   receiving_user_id=receiving_user_id,
                                   duration_days=duration,
                                   payment_amount=payment)


class MRedeemedCode(mongo.Document):
    user_id = mongo.IntField()
    gift_code = mongo.StringField()
    redeemed_date = mongo.DateTimeField(default=datetime.datetime.now)
    
    meta = {
        'collection': 'redeemed_codes',
        'allow_inheritance': False,
        'indexes': ['user_id', 'gift_code', 'redeemed_date'],
    }
    
    def __str__(self):
        return "%s redeemed %s on %s" % (self.user_id, self.gift_code, self.redeemed_date)
    
    @classmethod
    def record(cls, user_id, gift_code):
        cls.objects.create(user_id=user_id, 
                           gift_code=gift_code)
    @classmethod
    def redeem(cls, user, gift_code):
        newsblur_gift_code = MGiftCode.objects.filter(gift_code__iexact=gift_code)
        if newsblur_gift_code:
            newsblur_gift_code = newsblur_gift_code[0]
            PaymentHistory.objects.create(user=user,
                                          payment_date=datetime.datetime.now(),
                                          payment_amount=newsblur_gift_code.payment_amount,
                                          payment_provider='newsblur-gift')
            
        else:
            # Thinkup / Good Web Bundle
            PaymentHistory.objects.create(user=user,
                                          payment_date=datetime.datetime.now(),
                                          payment_amount=12,
                                          payment_provider='good-web-bundle')
        cls.record(user.pk, gift_code)
        user.profile.activate_premium()
        logging.user(user, "~FG~BBRedeeming gift code: %s~FW" % gift_code)
        

class MCustomStyling(mongo.Document):
    user_id = mongo.IntField(unique=True)
    custom_css = mongo.StringField()
    custom_js = mongo.StringField()
    updated_date = mongo.DateTimeField(default=datetime.datetime.now)
    
    meta = {
        'collection': 'custom_styling',
        'allow_inheritance': False,
        'indexes': ['user_id'],
    }
    
    def __str__(self):
        return "%s custom style %s/%s %s" % (self.user_id, len(self.custom_css) if self.custom_css else "-", 
                                             len(self.custom_js) if self.custom_js else "-", self.updated_date)
    
    def canonical(self):
        return {
            'css': self.custom_css,
            'js': self.custom_js,
        }
    
    @classmethod
    def get_user(cls, user_id):
        try:
            styling = cls.objects.get(user_id=user_id)
        except cls.DoesNotExist:
            return None
        
        return styling
    
    @classmethod
    def save_user(cls, user_id, css, js):
        styling = cls.get_user(user_id)
        if not css and not js:
            if styling:
                styling.delete()
            return

        if not styling:
            styling = cls.objects.create(user_id=user_id)

        styling.custom_css = css
        styling.custom_js = js
        styling.save()
        
class RNewUserQueue:
    
    KEY = "new_user_queue"
    
    @classmethod
    def activate_next(cls):
        count = cls.user_count()
        if not count:
            return
        
        user_id = cls.pop_user()
        try:
            user = User.objects.get(pk=user_id)
        except User.DoesNotExist:
            logging.debug("~FRCan't activate free account, can't find user ~SB%s~SN. ~FB%s still in queue." % (user_id, count-1))
            return
            
        logging.user(user, "~FBActivating free account (%s / %s). %s still in queue." % (user.email, user.profile.last_seen_ip, (count-1)))

        user.profile.activate_free()
    
    @classmethod
    def activate_all(cls):
        count = cls.user_count()
        if not count:
            logging.debug("~FBNo users to activate, sleeping...")
            return
        
        for i in range(count):
            cls.activate_next()
        
    @classmethod
    def add_user(cls, user_id):
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        now = time.time()
        
        r.zadd(cls.KEY, { user_id: now })
    
    @classmethod
    def user_count(cls):
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        count = r.zcard(cls.KEY)

        return count
    
    @classmethod
    def user_position(cls, user_id):
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        position = r.zrank(cls.KEY, user_id)
        if position >= 0:
            return position + 1
    
    @classmethod
    def pop_user(cls):
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        user = r.zrange(cls.KEY, 0, 0)[0]
        r.zrem(cls.KEY, user)

        return user
    
