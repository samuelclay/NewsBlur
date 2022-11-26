import time
import datetime
from wsgiref.util import application_uri
import dateutil
import stripe
import hashlib
import re
import redis
import uuid
import paypalrestsdk
import mongoengine as mongo
from django.db import models
from django.db import IntegrityError
from django.db.utils import DatabaseError
from django.db.models.signals import post_save
from django.db.models import Sum, Avg, Count
from django.db.models import Q
from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
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
from zebra.signals import zebra_webhook_customer_subscription_created
from zebra.signals import zebra_webhook_customer_subscription_updated
from zebra.signals import zebra_webhook_charge_succeeded
from zebra.signals import zebra_webhook_charge_refunded
from zebra.signals import zebra_webhook_checkout_session_completed

class Profile(models.Model):
    user              = models.OneToOneField(User, unique=True, related_name="profile", on_delete=models.CASCADE)
    is_premium        = models.BooleanField(default=False)
    is_archive        = models.BooleanField(default=False, blank=True, null=True)
    is_pro            = models.BooleanField(default=False, blank=True, null=True)
    premium_expire    = models.DateTimeField(blank=True, null=True)
    send_emails       = models.BooleanField(default=True)
    preferences       = models.TextField(default="{}")
    view_settings     = models.TextField(default="{}")
    collapsed_folders = models.TextField(default="[]")
    feed_pane_size    = models.IntegerField(default=282)
    days_of_unread    = models.IntegerField(default=settings.DAYS_OF_UNREAD, blank=True, null=True)
    tutorial_finished = models.BooleanField(default=False)
    hide_getting_started = models.BooleanField(default=False, null=True, blank=True)
    has_setup_feeds   = models.BooleanField(default=False, null=True, blank=True)
    has_found_friends = models.BooleanField(default=False, null=True, blank=True)
    has_trained_intelligence = models.BooleanField(default=False, null=True, blank=True)
    last_seen_on      = models.DateTimeField(default=datetime.datetime.now)
    last_seen_ip      = models.CharField(max_length=50, blank=True, null=True)
    dashboard_date    = models.DateTimeField(default=datetime.datetime.now)
    timezone          = TimeZoneField(default="America/New_York")
    secret_token      = models.CharField(max_length=12, blank=True, null=True)
    stripe_4_digits   = models.CharField(max_length=4, blank=True, null=True)
    stripe_id         = models.CharField(max_length=24, blank=True, null=True)
    paypal_sub_id     = models.CharField(max_length=24, blank=True, null=True)
    # paypal_payer_id   = models.CharField(max_length=24, blank=True, null=True)
    premium_renewal   = models.BooleanField(default=False, blank=True, null=True)
    active_provider   = models.CharField(max_length=24, blank=True, null=True)
    
    def __str__(self):
        return "%s <%s>%s%s%s" % (
            self.user, 
            self.user.email, 
            " (Premium)" if self.is_premium and not self.is_archive and not self.is_pro else "", 
            " (Premium ARCHIVE)" if self.is_archive and not self.is_pro else "",
            " (Premium PRO)" if self.is_pro else "",
        )
    
    @classmethod
    def plan_to_stripe_price(cls, plan):
        price = None
        if plan == "premium":
            price = "newsblur-premium-36"
        elif plan == "archive":
            price = "price_0KK5a7wdsmP8XBlaHfbQNnaL"
            if settings.DEBUG:
                price = "price_0KK5tVwdsmP8XBlaXW1vYUn9"
        elif plan == "pro":
            price = "price_0KK5cvwdsmP8XBlaZDq068bA"
            if settings.DEBUG:
                price = "price_0KK5twwdsmP8XBlasifbX56Z"
        return price
    
    @classmethod
    def plan_to_paypal_plan_id(cls, plan):
        price = None
        if plan == "premium":
            price = "P-48R22630SD810553FMHZONIY"
            if settings.DEBUG:
                price = "P-4RV31836YD8080909MHZROJY"
        elif plan == "archive":
            price = "P-5JM46230U31841226MHZOMZY"
            if settings.DEBUG:
                price = "P-2EG40290653242115MHZROQQ"
        elif plan == "pro":
            price = "price_0KK5cvwdsmP8XBlaZDq068bA"
            if settings.DEBUG:
                price = "price_0KK5twwdsmP8XBlasifbX56Z"
        return price

    @property
    def unread_cutoff(self, force_premium=False, force_archive=False):
        if self.is_archive or force_archive:
            days_of_unread = self.days_of_unread or settings.DAYS_OF_UNREAD
            return datetime.datetime.utcnow() - datetime.timedelta(days=days_of_unread)
        if self.is_premium or force_premium:
            return datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
        
        return datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD_FREE)

    @property
    def unread_cutoff_premium(self):
        return datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
    
    @property
    def days_of_story_hashes(self):
        if self.is_archive:
            return settings.DAYS_OF_STORY_HASHES_ARCHIVE
        return settings.DAYS_OF_STORY_HASHES

    def canonical(self):
        return {
            'is_premium': self.is_premium,
            'is_archive': self.is_archive,
            'is_pro': self.is_pro,
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
        except DatabaseError as e:
            print(f" ---> Profile not saved: {e}")
    
    def delete_user(self, confirm=False, fast=False):
        if not confirm:
            print(" ---> You must pass confirm=True to delete this user.")
            return
        
        logging.user(self.user, "Deleting user: %s / %s" % (self.user.email, self.user.profile.last_seen_ip))
        try:
            if not fast:
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
        
        paypal_ids = PaypalIds.objects.filter(user=self.user)
        logging.user(self.user, "Deleting %s PayPal IDs." % paypal_ids.count())
        paypal_ids.delete()
        
        stripe_ids = StripeIds.objects.filter(user=self.user)
        logging.user(self.user, "Deleting %s Stripe IDs." % stripe_ids.count())
        stripe_ids.delete()
        
        logging.user(self.user, "Deleting user: %s" % self.user)
        self.user.delete()
    
    def activate_premium(self, never_expire=False):
        from apps.profile.tasks import EmailNewPremium
        
        EmailNewPremium.delay(user_id=self.user.pk)
        
        was_premium = self.is_premium
        self.is_premium = True
        self.is_archive = False
        self.is_pro = False
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
        
        # self.setup_premium_history() # Let's not call this unnecessarily
        
        if never_expire:
            self.premium_expire = None
            self.save()

        if not was_premium:
            logging.user(self.user, "~BY~SK~FW~SBNEW PREMIUM ACCOUNT! WOOHOO!!! ~FR%s subscriptions~SN!" % (subs.count()))
        
        return True
    
    def activate_archive(self, never_expire=False):
        UserSubscription.schedule_fetch_archive_feeds_for_user(self.user.pk)
        
        was_premium = self.is_premium
        was_archive = self.is_archive
        was_pro = self.is_pro
        self.is_premium = True
        self.is_archive = True
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
    
        # Count subscribers to turn on archive_subscribers counts, then show that count to users
        # on the paypal_archive_return page.
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

        if not was_archive:
            logging.user(self.user, "~BY~SK~FW~SBNEW PREMIUM ~BBARCHIVE~BY ACCOUNT! WOOHOO!!! ~FR%s subscriptions~SN!" % (subs.count()))
        
        return True
    
    def activate_pro(self, never_expire=False):
        from apps.profile.tasks import EmailNewPremiumPro
        
        EmailNewPremiumPro.delay(user_id=self.user.pk)
        
        was_premium = self.is_premium
        was_archive = self.is_archive
        was_pro = self.is_pro
        self.is_premium = True
        self.is_archive = True
        self.is_pro = True
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

        if not was_pro:
            logging.user(self.user, "~BY~SK~FW~SBNEW PREMIUM ~BGPRO~BY ACCOUNT! WOOHOO!!! ~FR%s subscriptions~SN!" % (subs.count()))
        
        return True
    
    def deactivate_premium(self):
        self.is_premium = False
        self.is_pro = False
        self.is_archive = False
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
    
    def paypal_change_billing_details_url(self):
        return "https://paypal.com"
        
    def switch_stripe_subscription(self, plan):
        stripe_customer = self.stripe_customer()
        if not stripe_customer:
            return
        
        stripe_subscriptions = stripe.Subscription.list(customer=stripe_customer.id).data
        existing_subscription = None
        for subscription in stripe_subscriptions:
            if subscription.plan.active:
                existing_subscription = subscription
                break
        if not existing_subscription: 
            return

        try:
            stripe.Subscription.modify(
                existing_subscription.id,
                cancel_at_period_end=False,
                proration_behavior='always_invoice',
                items=[{
                    'id': existing_subscription['items']['data'][0].id,
                    'price': Profile.plan_to_stripe_price(plan)
                }]
            )
        except stripe.error.CardError as e:
            logging.user(self.user, f"~FRStripe switch subscription failed: ~SB{e}")
            return
        
        self.setup_premium_history()
        
        return True

    def cancel_and_prorate_existing_paypal_subscriptions(self, data):
        paypal_api = self.paypal_api()
        if not paypal_api:
            return
        
        canceled_paypal_sub_id = self.cancel_premium_paypal(cancel_older_subscriptions_only=True)
        if not canceled_paypal_sub_id:
            logging.user(self.user, f"~FRCould not cancel and prorate older paypal premium: {data}")
            return

        if isinstance(canceled_paypal_sub_id, str):
            self.refund_paypal_payment_from_subscription(canceled_paypal_sub_id, prorate=True)

    def switch_paypal_subscription_approval_url(self, plan):
        paypal_api = self.paypal_api()
        if not paypal_api:
            return
        paypal_return = reverse('paypal-return')
        if plan == "archive":
            paypal_return = reverse('paypal-archive-return')

        try:
            application_context = {
                'shipping_preference': 'NO_SHIPPING',
                'user_action': 'SUBSCRIBE_NOW',
            }
            if settings.DEBUG:
                application_context['return_url'] = f"https://a6d3-161-77-224-226.ngrok.io{paypal_return}"
            else:
                application_context['return_url'] = f"https://{Site.objects.get_current().domain}{paypal_return}"
            paypal_subscription = paypal_api.post(f'/v1/billing/subscriptions', {
                'plan_id': Profile.plan_to_paypal_plan_id(plan),
                'custom_id': self.user.pk,
                'application_context': application_context,
            })
        except paypalrestsdk.ResourceNotFound as e:
            logging.user(self.user, f"~FRCouldn't create paypal subscription: {self.paypal_sub_id} {plan}: {e}")
            paypal_subscription = None

        if not paypal_subscription:
            return
        logging.user(self.user, paypal_subscription)
        
        for link in paypal_subscription.get('links', []):
            if link['rel'] == 'approve':
                return link['href']
        
        logging.user(self.user, f"~FRFailed to switch paypal subscription: ~FC{paypal_subscription}")

    def store_paypal_sub_id(self, paypal_sub_id, skip_save_primary=False):
        if not paypal_sub_id:
            logging.user(self.user, "~FBPaypal sub id not found, ignoring")
            return

        if not skip_save_primary or not self.paypal_sub_id:
            self.paypal_sub_id = paypal_sub_id
            self.save()
        
        seen_paypal_ids = set(p.paypal_sub_id for p in self.user.paypal_ids.all())
        if paypal_sub_id in seen_paypal_ids:
            logging.user(self.user, f"~FBPaypal sub seen before, ignoring: {paypal_sub_id}")
            return
        
        self.user.paypal_ids.create(paypal_sub_id=paypal_sub_id)
        logging.user(self.user, f"~FBPaypal sub ~SBadded~SN: ~SB{paypal_sub_id}")

    def setup_premium_history(self, alt_email=None, set_premium_expire=True, force_expiration=False):
        stripe_payments = []
        total_stripe_payments = 0
        total_paypal_payments = 0
        active_plan = None
        premium_renewal = False
        active_provider = None
        
        # Find modern Paypal payments
        self.retrieve_paypal_ids()
        if self.paypal_sub_id:
            seen_payments = set()
            seen_payment_history = PaymentHistory.objects.filter(user=self.user, payment_provider="paypal")
            deleted_paypal_payments = 0
            for payment in list(seen_payment_history):
                if payment.payment_date.date() in seen_payments:
                    payment.delete()
                    deleted_paypal_payments += 1
                else:
                    seen_payments.add(payment.payment_date.date())
                    total_paypal_payments += 1
            if deleted_paypal_payments > 0:
                logging.user(self.user, f"~BY~SN~FRDeleting~FW duplicate paypal history: ~SB{deleted_paypal_payments} payments")
            paypal_api = self.paypal_api()
            for paypal_id_model in self.user.paypal_ids.all():
                paypal_id = paypal_id_model.paypal_sub_id
                try:
                    paypal_subscription = paypal_api.get(f'/v1/billing/subscriptions/{paypal_id}?fields=plan')
                except paypalrestsdk.ResourceNotFound:
                    logging.user(self.user, f"~FRCouldn't find paypal payments: {paypal_id}")
                    paypal_subscription = None

                if paypal_subscription:
                    if paypal_subscription['status'] in ["APPROVAL_PENDING", "APPROVED", "ACTIVE"]:
                        active_plan = paypal_subscription.get('plan_id', None)
                        if not active_plan:
                            active_plan = paypal_subscription['plan']['name']
                        active_provider = "paypal"
                        premium_renewal = True

                    start_date = datetime.datetime(2009, 1, 1).strftime("%Y-%m-%dT%H:%M:%S.000Z")
                    end_date = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S.000Z")
                    try:
                        transactions = paypal_api.get(f"/v1/billing/subscriptions/{paypal_id}/transactions?start_time={start_date}&end_time={end_date}")
                    except paypalrestsdk.exceptions.ResourceNotFound:
                        transactions = None
                    if not transactions or 'transactions' not in transactions:
                        logging.user(self.user, f"~FRCouldn't find paypal transactions: ~SB{paypal_id}")
                        continue
                    for transaction in transactions['transactions']:
                        created = dateutil.parser.parse(transaction['time']).date()
                        if transaction['status'] not in ['COMPLETED', 'PARTIALLY_REFUNDED', 'REFUNDED']: continue
                        if created in seen_payments: continue
                        seen_payments.add(created)
                        total_paypal_payments += 1
                        refunded = None
                        if transaction['status'] in ['PARTIALLY_REFUNDED', 'REFUNDED']:
                            refunded = True
                        PaymentHistory.objects.get_or_create(user=self.user,
                                                                payment_date=created,
                                                                payment_amount=int(float(transaction['amount_with_breakdown']['gross_amount']['value'])),
                                                                payment_provider='paypal',
                                                                refunded=refunded)

                    ipns = PayPalIPN.objects.filter(Q(custom=self.user.username) |
                                        Q(payer_email=self.user.email) |
                                        Q(custom=self.user.pk)).order_by('-payment_date')
                    for transaction in ipns:
                        if transaction.txn_type != "subscr_payment":
                            continue
                        created = transaction.payment_date.date()
                        if created in seen_payments: 
                            continue
                        seen_payments.add(created)
                        total_paypal_payments += 1
                        PaymentHistory.objects.get_or_create(user=self.user,
                                                                payment_date=created,
                                                                payment_amount=int(transaction.payment_gross),
                                                                payment_provider='paypal')
        else:
            logging.user(self.user, "~FBNo Paypal payments")
        
        # Record Stripe payments
        existing_stripe_history = PaymentHistory.objects.filter(user=self.user, 
                                                         payment_provider="stripe")
        if existing_stripe_history.count():
            logging.user(self.user, "~BY~SN~FRDeleting~FW existing stripe history: ~SB%s payments" % existing_stripe_history.count())
            existing_stripe_history.delete()
            
        if self.stripe_id:
            self.retrieve_stripe_ids()
            
            stripe.api_key = settings.STRIPE_SECRET
            seen_payments = set()
            for stripe_id_model in self.user.stripe_ids.all():
                stripe_id = stripe_id_model.stripe_id
                stripe_customer = stripe.Customer.retrieve(stripe_id)
                stripe_payments = stripe.Charge.list(customer=stripe_customer.id).data
                stripe_subscriptions = stripe.Subscription.list(customer=stripe_customer.id).data
                
                for subscription in stripe_subscriptions:
                    if subscription.plan.active:
                        active_plan = subscription.plan.id
                        active_provider = "stripe"
                        if not subscription.cancel_at:
                            premium_renewal = True
                        break
                            
                for payment in stripe_payments:
                    created = datetime.datetime.fromtimestamp(payment.created)
                    if payment.status == 'failed': continue
                    if created in seen_payments: continue
                    seen_payments.add(created)
                    total_stripe_payments += 1
                    refunded = None
                    if payment.refunded:
                        refunded = True
                    PaymentHistory.objects.get_or_create(user=self.user,
                                                         payment_date=created,
                                                         payment_amount=payment.amount / 100.0,
                                                         payment_provider='stripe',
                                                         refunded=refunded)
        else:
            logging.user(self.user, "~FBNo Stripe payments")

        # Calculate payments in last year, then add together
        payment_history = PaymentHistory.objects.filter(user=self.user)
        last_year = datetime.datetime.now() - datetime.timedelta(days=364)
        recent_payments_count = 0
        oldest_recent_payment_date = None
        free_lifetime_premium = False
        for payment in payment_history:
            # Don't use free gift premiums in calculation for expiration
            if payment.payment_amount == 0:
                logging.user(self.user, "~BY~SN~FWFree lifetime premium")
                free_lifetime_premium = True
                continue

            # Only update exiration if payment in the last year
            if payment.payment_date > last_year:
                recent_payments_count += 1
                if not oldest_recent_payment_date or payment.payment_date < oldest_recent_payment_date:
                    oldest_recent_payment_date = payment.payment_date
        
        if oldest_recent_payment_date:
            new_premium_expire = (oldest_recent_payment_date +
                                  datetime.timedelta(days=365*recent_payments_count))
            # Only move premium expire forward, never earlier. Also set expiration if not premium.
            if (force_expiration or 
                (set_premium_expire and not self.premium_expire and not free_lifetime_premium) or 
                (self.premium_expire and new_premium_expire > self.premium_expire)):
                self.premium_expire = new_premium_expire
                self.save()

        if self.premium_renewal != premium_renewal or self.active_provider != active_provider:
            active_sub_id = self.stripe_id
            if active_provider == "paypal":
                active_sub_id = self.paypal_sub_id
            logging.user(self.user, "~FCTurning ~SB~%s~SN~FC premium renewal (%s: %s)" % ("FRoff" if not premium_renewal else "FBon", active_provider, active_sub_id))
            self.premium_renewal = premium_renewal
            self.active_provider = active_provider
            self.save()
        
        logging.user(self.user, "~BY~SN~FWFound ~SB~FB%s paypal~FW~SN and ~SB~FC%s stripe~FW~SN payments (~SB%s payments expire: ~SN~FB%s~FW)" % (
                     total_paypal_payments, total_stripe_payments, len(payment_history), self.premium_expire))

        if (set_premium_expire and not self.is_premium and
            self.premium_expire > datetime.datetime.now()):
            self.activate_premium()
        
        logging.user(self.user, "~FCActive plan: %s, stripe/paypal: %s/%s, is_archive? %s" % (active_plan, Profile.plan_to_stripe_price('archive'), Profile.plan_to_paypal_plan_id('archive'), self.is_archive))
        if (active_plan == Profile.plan_to_stripe_price('pro') and not self.is_pro):
            self.activate_pro()
        elif (active_plan == Profile.plan_to_stripe_price('archive') and not self.is_archive):
            self.activate_archive()
        elif (active_plan == Profile.plan_to_paypal_plan_id('pro') and not self.is_pro):
            self.activate_pro()
        elif (active_plan == Profile.plan_to_paypal_plan_id('archive') and not self.is_archive):
            self.activate_archive()
        
    def preference_value(self, key, default=None):
        preferences = json.decode(self.preferences)
        return preferences.get(key, default)

    @classmethod
    def resync_stripe_and_paypal_history(cls, start_days=365, end_days=0, skip=0):
        start_date = datetime.datetime.now() - datetime.timedelta(days=start_days)
        end_date = datetime.datetime.now() - datetime.timedelta(days=end_days)
        payments = PaymentHistory.objects.filter(payment_date__gte=start_date,
                                                 payment_date__lte=end_date)
        last_seen_date = None
        for p, payment in enumerate(payments):
            if p < skip:
                continue
            if p == skip and skip > 0:
                print(f" ---> Skipping {skip} payments...")
            if payment.payment_date.date() != last_seen_date:
                last_seen_date = payment.payment_date.date()
                print(f" ---> Payment date: {last_seen_date} (#{p})")
                
            payment.user.profile.setup_premium_history()

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
                data = stripe.Charge.list(created={'gt': week}, count=limit, starting_after=starting_after)
            except stripe.error.APIConnectionError:
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
                except stripe.error.APIConnectionError:
                    logging.debug(" ***> Failed: %s" % user.username)
                    failed.append(user.username)
                    time.sleep(2)
                    continue

        return ','.join(failed)
        
    def refund_premium(self, partial=False, provider=None):
        refunded = False
        if provider == "paypal":
            refunded = self.refund_paypal_payment_from_subscription(self.paypal_sub_id, prorate=partial)
            self.cancel_premium_paypal()
        elif provider == "stripe":
            refunded = self.refund_latest_stripe_payment(partial=partial)
            # self.cancel_premium_stripe()
        else:
            # Find last payment, refund that
            payment_history = PaymentHistory.objects.filter(user=self.user, 
                                                            payment_provider__in=['paypal', 'stripe'])
            if payment_history.count():
                provider = payment_history[0].payment_provider
                if provider == "stripe":
                    refunded = self.refund_latest_stripe_payment(partial=partial)
                    # self.cancel_premium_stripe()
                elif provider == "paypal":
                    refunded = self.refund_paypal_payment_from_subscription(self.paypal_sub_id, prorate=partial)
                    self.cancel_premium_paypal()

        return refunded
    
    def refund_latest_stripe_payment(self, partial=False):
        refunded = False
        if not self.stripe_id:
            return
        
        stripe.api_key = settings.STRIPE_SECRET
        stripe_customer = stripe.Customer.retrieve(self.stripe_id)
        stripe_payments = stripe.Charge.list(customer=stripe_customer.id).data
        if partial:
            stripe_payments[0].refund(amount=1200)
            refunded = 12
        else:
            stripe_payments[0].refund()
            self.cancel_premium_stripe()
            refunded = stripe_payments[0].amount/100
        
        logging.user(self.user, "~FRRefunding stripe payment: $%s" % refunded)
        return refunded
    
    def refund_paypal_payment_from_subscription(self, paypal_sub_id, prorate=False):
        if not paypal_sub_id: 
            return
        
        paypal_api = self.paypal_api()
        refunded = False

        # Find transaction from subscription
        now = datetime.datetime.now() + datetime.timedelta(days=1)
        # 200 days captures Paypal's 180 day limit on refunds
        start_date = (now-datetime.timedelta(days=200)).strftime("%Y-%m-%dT%H:%M:%SZ")
        end_date = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        try:
            transactions = paypal_api.get(f"/v1/billing/subscriptions/{paypal_sub_id}/transactions?start_time={start_date}&end_time={end_date}")
        except paypalrestsdk.ResourceNotFound:
            transactions = {}
        if 'transactions' not in transactions or not len(transactions['transactions']):
            logging.user(self.user, f"~FRCouldn't find paypal transactions for refund: {paypal_sub_id} {transactions}")
            return
        
        # Refund the latest transaction
        transaction = transactions['transactions'][0]
        today = datetime.datetime.now().strftime('%B %d, %Y')
        url = f"/v2/payments/captures/{transaction['id']}/refund"
        refund_amount = float(transaction['amount_with_breakdown']['gross_amount']['value'])
        if prorate:
            transaction_date = dateutil.parser.parse(transaction['time'])
            days_since = (datetime.datetime.now() - transaction_date.replace(tzinfo=None)).days
            if days_since < 365:
                days_left = (365 - days_since)
                pct_left = days_left/365
                refund_amount = pct_left * refund_amount
            else:
                logging.user(self.user, f"~FRCouldn't prorate paypal payment, too old: ~SB{transaction}")
        try:
            response = paypal_api.post(url, {
                'reason': f"Refunded on {today}",
                'amount': {
                    'currency_code': 'USD',
                    'value': f"{refund_amount:.2f}",
                }
            })
        except paypalrestsdk.exceptions.ResourceInvalid as e:
            response = e.response.json()
            if len(response.get('details', [])):
                response = response['details'][0]['description']
        if settings.DEBUG:
            logging.user(self.user, f"Paypal refund response: {response}")
        if 'status' in response and response['status'] == "COMPLETED":
            refunded = int(float(transaction['amount_with_breakdown']['gross_amount']['value']))
            logging.user(self.user, "~FRRefunding paypal payment: $%s/%s" % (refund_amount, refunded))
        else:
            logging.user(self.user, "~FRCouldn't refund paypal payment: %s" % response)
            refunded = response
                    
        return refunded
            
    def cancel_premium(self):
        paypal_cancel = self.cancel_premium_paypal()
        stripe_cancel = self.cancel_premium_stripe()
        self.setup_premium_history() # Sure, webhooks will force new history, but they take forever
        return stripe_cancel or paypal_cancel
    
    def cancel_premium_paypal(self, cancel_older_subscriptions_only=False):
        self.retrieve_paypal_ids()
        if not self.paypal_sub_id:
            logging.user(self.user, "~FRUser doesn't have a Paypal subscription, how did we get here?")
            return
        if not self.premium_renewal and not cancel_older_subscriptions_only:
            logging.user(self.user, "~FRUser ~SBalready~SN canceled Paypal subscription: %s" % self.paypal_sub_id)
            return

        paypal_api = self.paypal_api()
        today = datetime.datetime.now().strftime('%B %d, %Y')
        for paypal_id_model in self.user.paypal_ids.all():
            paypal_id = paypal_id_model.paypal_sub_id
            if cancel_older_subscriptions_only and paypal_id == self.paypal_sub_id:
                logging.user(self.user, "~FBNot canceling active Paypal subscription: %s" % self.paypal_sub_id)
                continue
            try:
                paypal_subscription = paypal_api.get(f'/v1/billing/subscriptions/{paypal_id}')
            except paypalrestsdk.ResourceNotFound:
                logging.user(self.user, f"~FRCouldn't find paypal payments: {paypal_id}")
                continue
            if paypal_subscription['status'] not in ['ACTIVE', 'APPROVED', 'APPROVAL_PENDING']:
                logging.user(self.user, "~FRUser ~SBalready~SN canceled Paypal subscription: %s" % paypal_id)
                continue

            url = f"/v1/billing/subscriptions/{paypal_id}/suspend"
            try:
                response = paypal_api.post(url, {
                    'reason': f"Cancelled on {today}"
                })
            except paypalrestsdk.ResourceNotFound as e:
                logging.user(self.user, f"~FRCouldn't find paypal response during ~FB~SB{paypal_id}~SN~FR profile suspend: ~SB~FB{e}")
            
            logging.user(self.user, "~FRCanceling Paypal subscription: %s" % paypal_id)
            return paypal_id

        return True
        
    def cancel_premium_stripe(self):
        if not self.stripe_id:
            return
            
        stripe.api_key = settings.STRIPE_SECRET
        for stripe_id_model in self.user.stripe_ids.all():
            stripe_id = stripe_id_model.stripe_id
            stripe_customer = stripe.Customer.retrieve(stripe_id)
            try:
                subscriptions = stripe.Subscription.list(customer=stripe_customer)
                for subscription in subscriptions.data:
                    stripe.Subscription.modify(subscription['id'], cancel_at_period_end=True)
                    logging.user(self.user, "~FRCanceling Stripe subscription: %s" % subscription['id'])
            except stripe.error.InvalidRequestError:
                logging.user(self.user, "~FRFailed to cancel Stripe subscription: %s" % stripe_id)
                continue
        
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
    
    def retrieve_paypal_ids(self, force=False):
        if self.paypal_sub_id and not force:
            return
        
        ipns = PayPalIPN.objects.filter(Q(custom=self.user.username) |
                                        Q(payer_email=self.user.email) |
                                        Q(custom=self.user.pk)).order_by('-payment_date')
        if not len(ipns):
            return
        
        self.paypal_sub_id = ipns[0].subscr_id
        self.save()

        paypal_ids = set()
        for ipn in ipns:
            if not ipn.subscr_id: continue
            paypal_ids.add(ipn.subscr_id)
        
        seen_paypal_ids = set(p.paypal_sub_id for p in self.user.paypal_ids.all())
        for paypal_id in paypal_ids:
            if paypal_id in seen_paypal_ids:
                continue
            self.user.paypal_ids.create(paypal_sub_id=paypal_id)
        
    @property
    def latest_paypal_email(self):
        ipn = PayPalIPN.objects.filter(custom=self.user.username)
        if not len(ipn):
            ipn = PayPalIPN.objects.filter(payer_email=self.user.email)
        if not len(ipn):
            return
        
        return ipn[0].payer_email
    
    def update_email(self, new_email):
        from apps.social.models import MSocialProfile

        if self.user.email == new_email:
            return

        self.user.email = new_email
        self.user.save()
        
        sp = MSocialProfile.get_user(self.user.pk)
        sp.email = new_email
        sp.save()

        if self.stripe_id:
            stripe_customer = self.stripe_customer()
            stripe_customer.update({'email': new_email})
            stripe_customer.save()

    def stripe_customer(self):
        if self.stripe_id:
            stripe.api_key = settings.STRIPE_SECRET
            stripe_customer = stripe.Customer.retrieve(self.stripe_id)
            return stripe_customer
    
    def paypal_api(self):
        if self.paypal_sub_id:
            api = paypalrestsdk.Api({
                "mode": "sandbox" if settings.DEBUG else "live",
                "client_id": settings.PAYPAL_API_CLIENTID,
                "client_secret": settings.PAYPAL_API_SECRET
            })
            return api
    
    def activate_ios_premium(self, transaction_identifier=None, amount=36):
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
        
        logging.user(self.user, "~FG~BBNew iOS premium subscription: $%s~FW" % amount)
        return True
            
    def activate_android_premium(self, order_id=None, amount=36):
        payments = PaymentHistory.objects.filter(user=self.user,
                                                 payment_identifier=order_id,
                                                 payment_date__gte=datetime.datetime.now()-datetime.timedelta(days=3))
        if len(payments):
            # Already paid
            logging.user(self.user, "~FG~BBAlready paid Android premium subscription: $%s~FW" % amount)
            return False

        PaymentHistory.objects.create(user=self.user,
                                      payment_date=datetime.datetime.now(),
                                      payment_amount=amount,
                                      payment_provider='android-subscription',
                                      payment_identifier=order_id)
        
        self.setup_premium_history()
                                      
        if order_id == "nb.premium.archive.99":
            self.activate_archive()
        elif not self.is_premium:
            self.activate_premium()
        
        logging.user(self.user, "~FG~BBNew Android premium subscription: $%s~FW" % amount)
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
            archive = 0
            pro = 0
            key = 's:%s' % feed_id
            premium_key = 'sp:%s' % feed_id
            archive_key = 'sarchive:%s' % feed_id
            pro_key = 'spro:%s' % feed_id
            
            if user_id:
                active = UserSubscription.objects.get(feed_id=feed_id, user_id=user_id).only('active').active
                user_active_feeds = dict([(user_id, active)])
            else:
                user_active_feeds = dict([(us.user_id, us.active) 
                                 for us in UserSubscription.objects.filter(feed_id=feed_id).only('user', 'active')])
            profiles = Profile.objects.filter(user_id__in=list(user_active_feeds.keys())).values('user_id', 'last_seen_on', 'is_premium', 'is_archive', 'is_pro')
            feed = Feed.get_by_id(feed_id)
            
            if entire_feed_counted:
                pipeline = r.pipeline()
                pipeline.delete(key)
                pipeline.delete(premium_key)
                pipeline.delete(archive_key)
                pipeline.delete(pro_key)
                pipeline.execute()
            
            for profiles_group in chunks(profiles, 20):
                pipeline = r.pipeline()
                for profile in profiles_group:
                    last_seen_on = int(profile['last_seen_on'].strftime('%s'))
                    muted_feed = not bool(user_active_feeds[profile['user_id']])
                    if muted_feed:
                        last_seen_on = 0
                    pipeline.zadd(key, { profile['user_id']: last_seen_on })
                    total += 1
                    if profile['is_premium']:
                        pipeline.zadd(premium_key, { profile['user_id']: last_seen_on })
                        premium += 1
                    else:
                        pipeline.zrem(premium_key, profile['user_id'])
                    if profile['is_archive']:
                        pipeline.zadd(archive_key, { profile['user_id']: last_seen_on })
                        archive += 1
                    else:
                        pipeline.zrem(archive_key, profile['user_id'])
                    if profile['is_pro']:
                        pipeline.zadd(pro_key, { profile['user_id']: last_seen_on })
                        pro += 1
                    else:
                        pipeline.zrem(pro_key, profile['user_id'])
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
                r.zadd(archive_key, {-1: now})
                r.expire(archive_key, settings.SUBSCRIBER_EXPIRE*24*60*60)
                r.zadd(pro_key, {-1: now})
                r.expire(pro_key, settings.SUBSCRIBER_EXPIRE*24*60*60)
            
            logging.info("   ---> [%-30s] ~SN~FBCounting subscribers, storing in ~SBredis~SN: ~FMt:~SB~FM%s~SN a:~SB%s~SN p:~SB%s~SN ap:~SB%s~SN archive:~SB%s~SN pro:~SB%s" % 
                          (feed.log_title[:30], total, active, premium, active_premium, archive, pro))

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
                    archive_key = 'sarchive:%s' % feed_id
                    pro_key = 'spro:%s' % feed_id

                    last_seen_on = int(user.profile.last_seen_on.strftime('%s'))
                    if feed_ids is muted_feed_ids:
                        last_seen_on = 0
                    pipeline.zadd(key, { user.pk: last_seen_on })
                    if user.profile.is_premium:
                        pipeline.zadd(premium_key, { user.pk: last_seen_on })
                    else:
                        pipeline.zrem(premium_key, user.pk)
                    if user.profile.is_archive:
                        pipeline.zadd(archive_key, { user.pk: last_seen_on })
                    else:
                        pipeline.zrem(archive_key, user.pk)
                    if user.profile.is_pro:
                        pipeline.zadd(pro_key, { user.pk: last_seen_on })
                    else:
                        pipeline.zrem(pro_key, user.pk)
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
        msg.send()
        
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
        msg.send()
        
        from apps.social.models import MActivity
        MActivity.new_opml_export(user_id=self.user.pk, count=exporter.feed_count, automated=True)
        
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
        msg.send()
        
        logging.user(self.user, "~BB~FM~SBSending first share to blurblog email to: %s" % self.user.email)
    
    def send_new_premium_email(self, force=False):        
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
        subject = "Thank you for subscribing to NewsBlur Premium!"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send()
        
        logging.user(self.user, "~BB~FM~SBSending email for new premium: %s" % self.user.email)
    
    def send_new_premium_archive_email(self, total_story_count, pre_archive_count, force=False):
        if not self.user.email:
            return
        
        params = dict(receiver_user_id=self.user.pk, email_type='new_premium_archive')
        try:
            MSentEmail.objects.get(**params)
            if not force:
                # Return if email already sent
                logging.user(self.user, "~BB~FMNot ~SBSending email for new premium archive: %s (%s to %s stories)" % (self.user.email, pre_archive_count, total_story_count))
                return
        except MSentEmail.DoesNotExist:
            MSentEmail.objects.create(**params)
        feed_count = UserSubscription.objects.filter(user=self.user).count()
        user    = self.user
        text    = render_to_string('mail/email_new_premium_archive.txt', locals())
        html    = render_to_string('mail/email_new_premium_archive.xhtml', locals())
        if total_story_count > pre_archive_count:
            subject = f"NewsBlur archive backfill is complete: from {pre_archive_count:,} to {total_story_count:,} stories"
        else:
            subject = f"NewsBlur archive backfill is complete: {total_story_count:,} stories"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send()
        
        logging.user(self.user, "~BB~FM~SBSending email for new premium archive: %s (%s to %s stories)" % (self.user.email, pre_archive_count, total_story_count))
    
    def send_new_premium_pro_email(self, force=False):
        if not self.user.email or not self.send_emails:
            return
        
        params = dict(receiver_user_id=self.user.pk, email_type='new_premium_pro')
        try:
            MSentEmail.objects.get(**params)
            if not force:
                # Return if email already sent
                return
        except MSentEmail.DoesNotExist:
            MSentEmail.objects.create(**params)

        user    = self.user
        text    = render_to_string('mail/email_new_premium_pro.txt', locals())
        html    = render_to_string('mail/email_new_premium_pro.xhtml', locals())
        subject = "Thanks for subscribing to NewsBlur Premium Pro!"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send()
        
        logging.user(self.user, "~BB~FM~SBSending email for new premium pro: %s" % self.user.email)
    
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
        msg.send()
        
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
        msg.send()
        
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
        msg.send()
        
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
        msg.send()
        
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
        msg.send()
        
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
        msg.send()
        
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
        msg.send()
        
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


class PaypalIds(models.Model):
    user = models.ForeignKey(User, related_name='paypal_ids', on_delete=models.CASCADE, null=True)
    paypal_sub_id = models.CharField(max_length=24, blank=True, null=True)

    def __str__(self):
        return "%s: %s" % (self.user.username, self.paypal_sub_id)

        
def create_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)
    else:
        Profile.objects.get_or_create(user=instance)
post_save.connect(create_profile, sender=User)


def paypal_signup(sender, **kwargs):
    ipn_obj = sender
    user = None
    if ipn_obj.custom:
        try:
            user = User.objects.get(username__iexact=ipn_obj.custom)
        except User.DoesNotExist:
            pass

    if not user and ipn_obj.payer_email:
        try:
            user = User.objects.get(email__iexact=ipn_obj.payer_email)
        except User.DoesNotExist:
            pass
        
    if not user and ipn_obj.custom:
        try:
            user = User.objects.get(pk=ipn_obj.custom)
        except User.DoesNotExist:
            pass

    if not user and ipn_obj.subscr_id:
        try:
            user = PaypalIds.objects.get(paypal_sub_id=ipn_obj.subscr_id).user
        except PaypalIds.DoesNotExist:
            pass

    if not user:
        logging.debug(" ---> Paypal subscription not found during paypal_signup: %s/%s" % (
            ipn_obj.payer_email,
            ipn_obj.custom))    
        return {"code": -1, "message": "User doesn't exist."}

    logging.user(user, "~BC~SB~FBPaypal subscription signup")
    try:
        if not user.email:
            user.email = ipn_obj.payer_email
            user.save()
    except:
        pass
    user.profile.activate_premium()
    user.profile.cancel_premium_stripe()
    # user.profile.cancel_premium_paypal(second_most_recent_only=True)

    # assert False, "Shouldn't be here anymore as the new Paypal REST API uses webhooks"
valid_ipn_received.connect(paypal_signup)

def paypal_payment_history_sync(sender, **kwargs):
    ipn_obj = sender
    try:
        user = User.objects.get(username__iexact=ipn_obj.custom)
    except User.DoesNotExist:
        try:
            user = User.objects.get(email__iexact=ipn_obj.payer_email)
        except User.DoesNotExist:
            logging.debug(" ---> Paypal subscription not found during flagging: %s/%s" % (
                ipn_obj.payer_email,
                ipn_obj.custom))
            return {"code": -1, "message": "User doesn't exist."}

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
        try:
            user = User.objects.get(email__iexact=ipn_obj.payer_email)
        except User.DoesNotExist:
            logging.debug(" ---> Paypal subscription not found during flagging: %s/%s" % (
                ipn_obj.payer_email,
                ipn_obj.custom))
            return {"code": -1, "message": "User doesn't exist."}
        
    try:
        user.profile.setup_premium_history()
        logging.user(user, "~BC~SB~FBPaypal subscription payment flagged")
    except:
        return {"code": -1, "message": "User doesn't exist."}
invalid_ipn_received.connect(paypal_payment_was_flagged)

def stripe_checkout_session_completed(sender, full_json, **kwargs):
    newsblur_user_id = full_json['data']['object']['metadata']['newsblur_user_id']
    stripe_id = full_json['data']['object']['customer']
    profile = None
    try:
        profile = Profile.objects.get(stripe_id=stripe_id)
    except Profile.DoesNotExist:
        pass
    
    if not profile:
        try:
            profile = User.objects.get(pk=int(newsblur_user_id)).profile
            profile.stripe_id = stripe_id
            profile.save()
        except User.DoesNotExist:
            pass
    
    if profile:
        logging.user(profile.user, "~BC~SB~FBStripe checkout subscription signup")
        profile.retrieve_stripe_ids()
    else:
        logging.user(profile.user, "~BR~SB~FRCouldn't find Stripe user: ~FW%s" % full_json)
        return {"code": -1, "message": "User doesn't exist."}
zebra_webhook_checkout_session_completed.connect(stripe_checkout_session_completed)

def stripe_signup(sender, full_json, **kwargs):
    stripe_id = full_json['data']['object']['customer']
    plan_id = full_json['data']['object']['plan']['id']
    try:
        profile = Profile.objects.get(stripe_id=stripe_id)
        logging.user(profile.user, "~BC~SB~FBStripe subscription signup")
        if plan_id == Profile.plan_to_stripe_price('premium'):
            profile.activate_premium()
        elif plan_id == Profile.plan_to_stripe_price('archive'):
            profile.activate_archive()
        elif plan_id == Profile.plan_to_stripe_price('pro'):
            profile.activate_pro()
        profile.cancel_premium_paypal()
        profile.retrieve_stripe_ids()
    except Profile.DoesNotExist:
        return {"code": -1, "message": "User doesn't exist."}
zebra_webhook_customer_subscription_created.connect(stripe_signup)

def stripe_subscription_updated(sender, full_json, **kwargs):
    stripe_id = full_json['data']['object']['customer']
    plan_id = full_json['data']['object']['plan']['id']
    try:
        profile = Profile.objects.get(stripe_id=stripe_id)
        active = not full_json['data']['object']['cancel_at'] and full_json['data']['object']['plan']['active']
        logging.user(profile.user, "~BC~SB~FBStripe subscription updated: %s" % "active" if active else "cancelled")
        if active:
            if plan_id == Profile.plan_to_stripe_price('premium'):
                profile.activate_premium()
            elif plan_id == Profile.plan_to_stripe_price('archive'):
                profile.activate_archive()
            elif plan_id == Profile.plan_to_stripe_price('pro'):
                profile.activate_pro()
            profile.cancel_premium_paypal()
            profile.retrieve_stripe_ids()
        else:
            profile.setup_premium_history()
    except Profile.DoesNotExist:
        return {"code": -1, "message": "User doesn't exist."}
zebra_webhook_customer_subscription_updated.connect(stripe_subscription_updated)

def stripe_payment_history_sync(sender, full_json, **kwargs):
    stripe_id = full_json['data']['object']['customer']
    try:
        profile = Profile.objects.get(stripe_id=stripe_id)
        logging.user(profile.user, "~BC~SB~FBStripe subscription payment")
        profile.setup_premium_history()
    except Profile.DoesNotExist:
        return {"code": -1, "message": "User doesn't exist."}    
zebra_webhook_charge_succeeded.connect(stripe_payment_history_sync)
zebra_webhook_charge_refunded.connect(stripe_payment_history_sync)

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
        sender_user = self.sending_user_id
        if sender_user:
            sender_user = User.objects.get(pk=self.sending_user_id)
        receiver_user = self.receiver_user_id
        if receiver_user:
            receiver_user = User.objects.get(pk=self.receiver_user_id)
        return "%s sent %s email to %s %s" % (sender_user, self.email_type, receiver_user, receiver_user.profile if receiver_user else receiver_user)
    
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
    refunded = models.BooleanField(blank=True, null=True)
    
    def __str__(self):
        return "[%s] $%s/%s %s" % (self.payment_date.strftime("%Y-%m-%d"), self.payment_amount,
                                self.payment_provider, "<REFUNDED>" if self.refunded else "")
    class Meta:
        ordering = ['-payment_date']
        
    def canonical(self):
        return {
            'payment_date': self.payment_date.strftime('%Y-%m-%d'),
            'payment_amount': self.payment_amount,
            'payment_provider': self.payment_provider,
            'refunded': self.refunded,
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


class MDashboardRiver(mongo.Document):
    user_id = mongo.IntField(unique_with=())
    river_id = mongo.StringField()
    river_side = mongo.StringField()
    river_order = mongo.IntField()

    meta = {
        'collection': 'dashboard_river',
        'allow_inheritance': False,
        'indexes': ['user_id', 
                    {'fields': ['user_id', 'river_id', 'river_side', 'river_order'], 
                     'unique': True,
                    }],
        'ordering': ['river_order']
    }

    def __str__(self):
        try:
            u = User.objects.get(pk=self.user_id)
        except User.DoesNotExist:
            u = "<missing user>"
        return f"{u} ({self.river_side}/{self.river_order}): {self.river_id}"
        
    def canonical(self):
        return {
            'river_id': self.river_id,
            'river_side': self.river_side,
            'river_order': self.river_order,
        }
    
    @classmethod
    def get_user_rivers(cls, user_id):
        return cls.objects(user_id=user_id)

    @classmethod
    def remove_river(cls, user_id, river_side, river_order):
        try:
            river = cls.objects.get(user_id=user_id, river_side=river_side, river_order=river_order)
        except cls.DoesNotExist:
            return

        river.delete()

        for r, river in enumerate(cls.objects.filter(user_id=user_id, river_side=river_side)):
            if river.river_order != r:
                logging.debug(f" ---> Rebalancing {river} from {river.river_order} to {r}")
                river.river_order = r
                river.save()

    @classmethod
    def save_user(cls, user_id, river_id, river_side, river_order):
        try:
            river = cls.objects.get(user_id=user_id, river_side=river_side, river_order=river_order)
        except cls.DoesNotExist:
            river = None

        if not river:
            river = cls.objects.create(user_id=user_id, river_id=river_id, 
                                    river_side=river_side, river_order=river_order)

        river.river_id = river_id
        river.river_side = river_side
        river.river_order = river_order
        river.save()

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
        if position is None:
            return -1
        if position >= 0:
            return position + 1
    
    @classmethod
    def pop_user(cls):
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        user = r.zrange(cls.KEY, 0, 0)[0]
        r.zrem(cls.KEY, user)

        return user
    
