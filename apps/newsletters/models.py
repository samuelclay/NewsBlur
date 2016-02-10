import datetime
import re
from django.db import models
from django.contrib.auth.models import User
from django.core.urlresolvers import reverse
from apps.rss_feeds.models import Feed, MStory, MFetchHistory
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.profile.models import Profile
from utils import log as logging

class EmailNewsletter:
    
    def receive_newsletter(self, params):
        user = self.user_from_email(params['recipient'])
        if not user:
            return
        
        sender_name, sender_domain = self.split_sender(params['from'])
        feed_address = self.feed_address(user, params['sender'])
        
        usf = UserSubscriptionFolders.objects.get(user=user)
        usf.add_folder('', 'Newsletters')
        
        try:
            feed = Feed.objects.get(feed_address=feed_address)
        except Feed.DoesNotExist:
            feed = Feed.objects.create(feed_address=feed_address, 
                                       feed_link='http://' + sender_domain,
                                       feed_title=sender_name,
                                       fetched_once=True,
                                       known_good=True)
            feed.set_next_scheduled_update()
        
        try:
            usersub = UserSubscription.objects.get(user=user, feed=feed)
        except UserSubscription.DoesNotExist:
            _, _, usersub = UserSubscription.add_subscription(
                user=user, 
                feed_address=feed_address,
                folder='Newsletters'
            )
        
        story_hash = MStory.ensure_story_hash(params['signature'], feed.pk)
        story_params = {
            "story_feed_id": feed.pk,
            "story_date": datetime.datetime.fromtimestamp(int(params['timestamp'])),
            "story_title": params['subject'],
            "story_content": params['body-html'],
            "story_author_name": params['from'],
            "story_permalink": reverse('newsletter-story', 
                                       kwargs={'story_hash': story_hash}),
            "story_guid": params['signature'],
        }
        try:
            story = MStory.objects.get(story_hash=story_hash)
        except MStory.DoesNotExist:
            story = MStory(**story_params)
            story.save()
        
        MFetchHistory.add(feed_id=feed.pk, fetch_type='push')
        
        return story
        
    def user_from_email(self, email):
        tokens = re.search('(\w+)\+(\w+)@newsletters.newsblur.com', email)
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
    
    def feed_address(self, user, sender):
        return 'newsletter:%s:%s' % (user.pk, sender)
    
    def split_sender(self, sender):
        tokens = re.search('(.*?) <(.*?)@(.*?)>', sender)
        if not tokens:
            return params['sender'].split('@')
        
        return tokens.group(0), tokens.group(2)