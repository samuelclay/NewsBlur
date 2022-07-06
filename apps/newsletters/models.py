import datetime
import re
import redis
from django.contrib.sites.models import Site
from django.core.mail import EmailMultiAlternatives
from django.urls import reverse
from django.conf import settings
from django.template.loader import render_to_string
from django.utils.html import linebreaks
from apps.rss_feeds.models import Feed, MStory, MFetchHistory
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.profile.models import Profile, MSentEmail
from apps.notifications.tasks import QueueNotifications
from apps.notifications.models import MUserFeedNotification

from utils import log as logging
from utils.story_functions import linkify
from utils.scrubber import Scrubber

class EmailNewsletter:
    
    def receive_newsletter(self, params):
        user = self._user_from_email(params['recipient'])
        if not user:
            return
        
        sender_name, sender_username, sender_domain = self._split_sender(params['from'])
        feed_address = self._feed_address(user, "%s@%s" % (sender_username, sender_domain))
        
        try:
            usf = UserSubscriptionFolders.objects.get(user=user)
        except UserSubscriptionFolders.DoesNotExist:
            logging.user(user, "~FRUser does not have a USF, ignoring newsletter.")
            return
        usf.add_folder('', 'Newsletters')
        
        # First look for the email address
        try:
            feed = Feed.objects.get(feed_address=feed_address)
        except Feed.MultipleObjectsReturned:
            feeds = Feed.objects.filter(feed_address=feed_address)[:1]
            if feeds.count():
                feed = feeds[0]
        except Feed.DoesNotExist:
            feed = None

        # If not found, check among titles user has subscribed to
        if not feed:
            newsletter_subs = UserSubscription.objects.filter(user=user, feed__feed_address__contains="newsletter:").only('feed')
            newsletter_feed_ids = [us.feed.pk for us in newsletter_subs]
            feeds = Feed.objects.filter(feed_title__iexact=sender_name, pk__in=newsletter_feed_ids)
            if feeds.count():
                feed = feeds[0]
        
        # Create a new feed if it doesn't exist by sender name or email
        if not feed:
            feed = Feed.objects.create(feed_address=feed_address, 
                                       feed_link='http://' + sender_domain,
                                       feed_title=sender_name,
                                       fetched_once=True,
                                       known_good=True)
            feed.update()
            logging.user(user, "~FCCreating newsletter feed: ~SB%s" % (feed))
            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            r.publish(user.username, 'reload:%s' % feed.pk)
            self._check_if_first_newsletter(user)
        
        feed.last_update = datetime.datetime.now()
        feed.last_story_date = datetime.datetime.now()
        feed.save()
        
        if feed.feed_title != sender_name:
            feed.feed_title = sender_name
            feed.save()
        
        try:
            usersub = UserSubscription.objects.get(user=user, feed=feed)
        except UserSubscription.DoesNotExist:
            _, _, usersub = UserSubscription.add_subscription(
                user=user, 
                feed_address=feed_address,
                folder='Newsletters'
            )
            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            r.publish(user.username, 'reload:feeds')            
        
        story_hash = MStory.ensure_story_hash(params['signature'], feed.pk)
        story_content = self._get_content(params)
        plain_story_content = self._get_content(params, force_plain=True)
        if len(plain_story_content) > len(story_content):
            story_content = plain_story_content
        story_content = self._clean_content(story_content)
        story_params = {
            "story_feed_id": feed.pk,
            "story_date": datetime.datetime.fromtimestamp(int(params['timestamp'])),
            "story_title": params['subject'],
            "story_content": story_content,
            "story_author_name": params['from'],
            "story_permalink": "https://%s%s" % (
                                    Site.objects.get_current().domain,
                                    reverse('newsletter-story', 
                                            kwargs={'story_hash': story_hash})),
            "story_guid": params['signature'],
        }

        try:
            story = MStory.objects.get(story_hash=story_hash)
        except MStory.DoesNotExist:
            story = MStory(**story_params)
            story.save()
        
        usersub.needs_unread_recalc = True
        usersub.save()
        
        self._publish_to_subscribers(feed, story.story_hash)
        
        MFetchHistory.add(feed_id=feed.pk, fetch_type='push')
        logging.user(user, "~FCNewsletter feed story: ~SB%s~SN / ~SB%s" % (story.story_title, feed))
        
        return story
    
    def _check_if_first_newsletter(self, user, force=False):
        if not user.email:
            return

        subs = UserSubscription.objects.filter(user=user)
        found_newsletter = False
        for sub in subs:
            if sub.feed.is_newsletter:
                found_newsletter = True
                break
        if not found_newsletter and not force: 
            return        
        
        params = dict(receiver_user_id=user.pk, email_type='first_newsletter')
        try:
            MSentEmail.objects.get(**params)
            if not force:
                # Return if email already sent
                return
        except MSentEmail.DoesNotExist:
            MSentEmail.objects.create(**params)
                
        text    = render_to_string('mail/email_first_newsletter.txt', {})
        html    = render_to_string('mail/email_first_newsletter.xhtml', {})
        subject = "Your email newsletters are now being sent to NewsBlur"
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['%s <%s>' % (user, user.email)])
        msg.attach_alternative(html, "text/html")
        msg.send()
        
        logging.user(user, "~BB~FM~SBSending first newsletter email to: %s" % user.email)
        
    def _user_from_email(self, email):
        tokens = re.search('(\w+)[\+\-\.](\w+)@newsletters.newsblur.com', email)
        if not tokens:
            return
        
        username, secret_token = tokens.groups()
        try:
            profiles = Profile.objects.filter(secret_token=secret_token)
            if not profiles:
                return
            profile = profiles[0]
        except Profile.DoesNotExist:
            return
        
        return profile.user
    
    def _feed_address(self, user, sender_email):
        return 'newsletter:%s:%s' % (user.pk, sender_email)
    
    def _split_sender(self, sender):
        tokens = re.search('(.*?) <(.*?)@(.*?)>', sender)

        if not tokens:
            name, domain = sender.split('@')
            return name, sender, domain
            
        sender_name, sender_username, sender_domain = tokens.group(1), tokens.group(2), tokens.group(3)
        sender_name = sender_name.replace('"', '')
        
        return sender_name, sender_username, sender_domain
    
    def _get_content(self, params, force_plain=False):
        if 'body-enriched' in params and not force_plain:
            return params['body-enriched']
        if 'body-html' in params and not force_plain:
            return params['body-html']
        if 'stripped-html' in params and not force_plain:
            return params['stripped-html']
        if 'body-plain' in params:
            return linkify(linebreaks(params['body-plain']))
        
        if force_plain:
            return self._get_content(params, force_plain=False)
    
    def _clean_content(self, content):
        original = content
        scrubber = Scrubber()
        content = scrubber.scrub(content)
        if len(content) < len(original)*0.01:
            content = original
        content = content.replace('!important', '')
        return content
        
    def _publish_to_subscribers(self, feed, story_hash):
        try:
            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            listeners_count = r.publish("%s:story" % feed.pk, 'story:new:%s' % story_hash)
            if listeners_count:
                logging.debug("   ---> [%-30s] ~FMPublished to %s subscribers" % (feed.log_title[:30], listeners_count))
        except redis.ConnectionError:
            logging.debug("   ***> [%-30s] ~BMRedis is unavailable for real-time." % (feed.log_title[:30],))
        
        if MUserFeedNotification.feed_has_users(feed.pk) > 0:
            QueueNotifications.delay(feed.pk, 1)
    