import re
import datetime
import tweepy
import dateutil.parser
from django.conf import settings
from django.utils import feedgenerator
from django.utils.html import linebreaks
from django.utils.dateformat import DateFormat
from apps.social.models import MSocialServices
from apps.reader.models import UserSubscription
from utils import log as logging

class TwitterFetcher:
    
    def __init__(self, feed, options=None):
        self.feed = feed
        self.address = self.feed.feed_address
        self.options = options or {}
    
    def fetch(self, address=None):
        data = {}
        if not address:
            address = self.feed.feed_address
        self.address = address
        twitter_user = None

        if '/lists/' in address:
            list_id = self.extract_list_id()
            if not list_id:
                return
            
            tweets, list_info = self.fetch_list_timeline(list_id)
            if not tweets:
                return
                            
            data['title'] = "%s on Twitter" % list_info.full_name
            data['link'] = "https://twitter.com%s" % list_info.uri
            data['description'] = "%s on Twitter" % list_info.full_name
        else:
            username = self.extract_username()
            if not username:
                return
        
            twitter_user = self.fetch_user(username)
            if not twitter_user:
                return
            tweets = self.user_timeline(twitter_user)
        
            data['title'] = "%s on Twitter" % username
            data['link'] = "https://twitter.com/%s" % username
            data['description'] = "%s on Twitter" % username

        data['lastBuildDate'] = datetime.datetime.utcnow()
        data['generator'] = 'NewsBlur Twitter API Decrapifier - %s' % settings.NEWSBLUR_URL
        data['docs'] = None
        data['feed_url'] = address
        rss = feedgenerator.Atom1Feed(**data)
        
        for tweet in tweets:
            story_data = self.tweet_story(tweet.__dict__)
            rss.add_item(**story_data)
        
        return rss.writeString('utf-8')
    
    def extract_username(self):
        username = None
        try:
            username_groups = re.search('twitter.com/(\w+)/?$', self.address)
            if not username_groups:
                return
            username = username_groups.group(1)
        except IndexError:
            return
        
        return username

    def extract_list_id(self):
        list_id = None
        try:
            list_groups = re.search('twitter.com/i/lists/(\w+)/?', self.address)
            if not list_groups:
                return
            list_id = list_groups.group(1)
        except IndexError:
            return
        
        return list_id
    
    def twitter_api(self):
        twitter_api = None
        social_services = None
        if self.options.get('requesting_user_id', None):
            social_services = MSocialServices.get_user(self.options.get('requesting_user_id'))
            try:
                twitter_api = social_services.twitter_api()
            except tweepy.error.TweepError as e:
                logging.debug('   ***> [%-30s] ~FRTwitter fetch failed: %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                return
        else:
            usersubs = UserSubscription.objects.filter(feed=self.feed)
            if not usersubs:
                logging.debug('   ***> [%-30s] ~FRTwitter fetch failed: %s: No subscriptions' % 
                              (self.feed.log_title[:30], self.address))
                return
            for sub in usersubs:
                social_services = MSocialServices.get_user(sub.user_id)
                if not social_services.twitter_uid: continue
                try:
                    twitter_api = social_services.twitter_api()
                    if not twitter_api: 
                        continue
                    else:
                        break
                except tweepy.error.TweepError as e:
                    logging.debug('   ***> [%-30s] ~FRTwitter fetch failed: %s: %s' % 
                                  (self.feed.log_title[:30], self.address, e))
                    continue
        
        if not twitter_api:
            logging.debug('   ***> [%-30s] ~FRTwitter fetch failed: %s: No twitter API for %s' % 
                          (self.feed.log_title[:30], self.address, usersubs[0].user.username))
            return
        
        return twitter_api
    
    def fetch_user(self, username):
        twitter_api = self.twitter_api()
        if not twitter_api:
            return
        
        try:
            twitter_user = twitter_api.get_user(username)
        except TypeError as e:
            logging.debug('   ***> [%-30s] ~FRTwitter fetch failed, disconnecting twitter: %s: %s' % 
                          (self.feed.log_title[:30], self.address, e))
            self.feed.save_feed_history(560, "Twitter Error: %s" % (e))
            return
        except tweepy.error.TweepError as e:
            message = str(e).lower()
            if ((len(e.args) >= 2 and e.args[2] == 63) or
                ('temporarily locked' in message)):
                # Suspended
                logging.debug('   ***> [%-30s] ~FRTwitter failed, user suspended, disconnecting twitter: %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                self.feed.save_feed_history(560, "Twitter Error: User suspended")
                return
            elif 'suspended' in message:
                logging.debug('   ***> [%-30s] ~FRTwitter user suspended, disconnecting twitter: %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                self.feed.save_feed_history(560, "Twitter Error: User suspended")
                return
            elif 'expired token' in message:
                logging.debug('   ***> [%-30s] ~FRTwitter user expired, disconnecting twitter: %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                self.feed.save_feed_history(560, "Twitter Error: Expired token")
                return
            elif 'not found' in message:
                logging.debug('   ***> [%-30s] ~FRTwitter user not found, disconnecting twitter: %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                self.feed.save_feed_history(560, "Twitter Error: User not found")
                return
            elif 'over capacity' in message or 'Max retries' in message:
                logging.debug('   ***> [%-30s] ~FRTwitter over capacity, ignoring... %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                self.feed.save_feed_history(460, "Twitter Error: Over capacity")
                return
            else:
                raise e
        
        return twitter_user
    
    def user_timeline(self, twitter_user):
        try:
            tweets = twitter_user.timeline(tweet_mode='extended')
        except tweepy.error.TweepError as e:
            message = str(e).lower()
            if 'not authorized' in message:
                logging.debug('   ***> [%-30s] ~FRTwitter timeline failed, disconnecting twitter: %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                self.feed.save_feed_history(560, "Twitter Error: Not authorized")
                return []
            elif 'user not found' in message:
                logging.debug('   ***> [%-30s] ~FRTwitter user not found, disconnecting twitter: %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                self.feed.save_feed_history(560, "Twitter Error: User not found")
                return []
            elif '429' in message:
                logging.debug('   ***> [%-30s] ~FRTwitter rate limited: %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                self.feed.save_feed_history(560, "Twitter Error: Rate limited")
                return []
            elif 'blocked from viewing' in message:
                logging.debug('   ***> [%-30s] ~FRTwitter user blocked, ignoring: %s' % 
                              (self.feed.log_title[:30], e))
                self.feed.save_feed_history(560, "Twitter Error: Blocked from viewing")
                return []
            else:
                raise e
        
        if not tweets:
            return []
        return tweets
    
    def fetch_list_timeline(self, list_id):
        twitter_api = self.twitter_api()
        if not twitter_api:
            return None, None
        
        try:
            list_timeline = twitter_api.list_timeline(list_id=list_id, tweet_mode='extended')
        except TypeError as e:
            logging.debug('   ***> [%-30s] ~FRTwitter list fetch failed, disconnecting twitter: %s: %s' % 
                          (self.feed.log_title[:30], self.address, e))
            self.feed.save_feed_history(560, "Twitter Error: %s" % (e))
            return None, None
        except tweepy.error.TweepError as e:
            message = str(e).lower()
            if ((len(e.args) >= 2 and e.args[2] == 63) or
                ('temporarily locked' in message)):
                # Suspended
                logging.debug('   ***> [%-30s] ~FRTwitter failed, user suspended, disconnecting twitter: %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                self.feed.save_feed_history(560, "Twitter Error: User suspended")
                return None, None
            elif 'suspended' in message:
                logging.debug('   ***> [%-30s] ~FRTwitter user suspended, disconnecting twitter: %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                self.feed.save_feed_history(560, "Twitter Error: User suspended")
                return None, None
            elif 'expired token' in message:
                logging.debug('   ***> [%-30s] ~FRTwitter user expired, disconnecting twitter: %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                self.feed.save_feed_history(560, "Twitter Error: Expired token")
                return None, None
            elif 'not found' in message:
                logging.debug('   ***> [%-30s] ~FRTwitter user not found, disconnecting twitter: %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                self.feed.save_feed_history(560, "Twitter Error: User not found")
                return None, None
            elif 'over capacity' in message or 'Max retries' in message:
                logging.debug('   ***> [%-30s] ~FRTwitter over capacity, ignoring... %s: %s' % 
                              (self.feed.log_title[:30], self.address, e))
                self.feed.save_feed_history(460, "Twitter Error: Over capacity")
                return None, None
            else:
                raise e
        
        list_info = twitter_api.get_list(list_id=list_id)
        
        if not list_timeline:
            return [], list_info
        return list_timeline, list_info
        
    def tweet_story(self, user_tweet):
        categories = set()
        
        if user_tweet['full_text'].startswith('RT @'):
            categories.add('retweet')
        elif user_tweet['in_reply_to_status_id'] or user_tweet['full_text'].startswith('@'):
            categories.add('reply')
        else:
            categories.add('tweet')
        if user_tweet['full_text'].startswith('RT @'):
            categories.add('retweet')
        if user_tweet['favorite_count']:
            categories.add('liked')
        if user_tweet['retweet_count']:
            categories.add('retweeted')            
        if 'http' in user_tweet['full_text']:
            categories.add('link')
        
        story = {}
        content_tweet = user_tweet
        entities = ""
        author = user_tweet.get('author') or user_tweet.get('user')
        if not isinstance(author, dict): author = author.__dict__
        author_name = author['screen_name']
        original_author_name = author_name
        if user_tweet['in_reply_to_user_id'] == author['id']:
            categories.add('reply-to-self')        
        retweet_author = ""
        tweet_link = "https://twitter.com/%s/status/%s" % (original_author_name, user_tweet['id'])
        if 'retweeted_status' in user_tweet:
            retweet_author = """Retweeted by 
                                 <a href="https://twitter.com/%s"><img src="%s" style="height: 20px" /></a>
                                 <a href="https://twitter.com/%s">%s</a>
                            on %s""" % (
                author_name,
                author['profile_image_url_https'],
                author_name,
                author_name,
                DateFormat(user_tweet['created_at']).format('l, F jS, Y g:ia').replace('.',''),
                )
            content_tweet = user_tweet['retweeted_status'].__dict__
            author = content_tweet['author']
            if not isinstance(author, dict): author = author.__dict__
            author_name = author['screen_name']
            tweet_link = "https://twitter.com/%s/status/%s" % (author_name, user_tweet['retweeted_status'].id)
        
        tweet_title = user_tweet['full_text']
        tweet_text = linebreaks(content_tweet['full_text'])
        replaced = {}
        entities_media = content_tweet['entities'].get('media', [])
        if 'extended_entities' in content_tweet:
            entities_media = content_tweet['extended_entities'].get('media', [])
        for media in entities_media:
            if 'media_url_https' not in media: continue
            if media['type'] == 'photo':
                if media.get('url') and media['url'] in tweet_text:
                    tweet_title = tweet_title.replace(media['url'], media['display_url'])
                replacement = "<a href=\"%s\">%s</a>" % (media['expanded_url'], media['display_url'])
                if not replaced.get(media['url']):
                    tweet_text = tweet_text.replace(media['url'], replacement)
                    replaced[media['url']] = True
                entities += "<img src=\"%s\"> <hr>" % media['media_url_https']
                categories.add('photo')
            if media['type'] == 'video' or media['type'] == 'animated_gif':
                if media.get('url') and media['url'] in tweet_text:
                    tweet_title = tweet_title.replace(media['url'], media['display_url'])
                replacement = "<a href=\"%s\">%s</a>" % (media['expanded_url'], media['display_url'])
                if not replaced.get(media['url']):
                    tweet_text = tweet_text.replace(media['url'], replacement)
                    replaced[media['url']] = True
                bitrate = 0
                chosen_variant = None
                for variant in media['video_info']['variants']:
                    if not chosen_variant:
                        chosen_variant = variant
                    if variant.get('bitrate', 0) > bitrate:
                        bitrate = variant['bitrate']
                        chosen_variant = variant
                if chosen_variant:
                    entities += "<video src=\"%s\" autoplay loop muted playsinline> <hr>" % chosen_variant['url']
                categories.add(media['type'])                
                
        for url in content_tweet['entities'].get('urls', []):
            if url['url'] in tweet_text:
                replacement = "<a href=\"%s\">%s</a>" % (url['expanded_url'], url['display_url'])
                if not replaced.get(url['url']):
                    tweet_text = tweet_text.replace(url['url'], replacement)
                    replaced[url['url']] = True
                tweet_title = tweet_title.replace(url['url'], url['display_url'])
        
        quote_tweet_content = ""
        if 'quoted_status' in content_tweet:
            quote_tweet_content = "<blockquote>"+self.tweet_story(content_tweet['quoted_status'].__dict__)['description']+"</blockquote>"
        
        
        created_date = content_tweet['created_at']
        if isinstance(created_date, str):
            created_date = dateutil.parser.parse(created_date)
        
        content = """<div class="NB-twitter-rss">
                         <div class="NB-twitter-rss-tweet">%s</div>
                         <div class="NB-twitter-rss-quote-tweet">%s</div>
                         <hr />
                         <div class="NB-twitter-rss-entities">%s</div>
                         <div class="NB-twitter-rss-author">
                             Posted by
                                 <a href="https://twitter.com/%s"><img src="%s" style="height: 32px" /></a>
                                 <a href="https://twitter.com/%s">%s</a>
                            on <a href="%s">%s</a></div>
                         <div class="NB-twitter-rss-retweet">%s</div>
                         <div class="NB-twitter-rss-stats">%s %s%s %s</div>
                    </div>""" % (
            tweet_text,
            quote_tweet_content,
            entities,
            author_name,
            author['profile_image_url_https'],
            author_name,
            author_name,
            tweet_link,
            DateFormat(created_date).format('l, F jS, Y g:ia').replace('.',''),
            retweet_author,
            ("<br /><br />" if content_tweet['favorite_count'] or content_tweet['retweet_count'] else ""),
            ("<b>%s</b> %s" % (content_tweet['favorite_count'], "like" if content_tweet['favorite_count'] == 1 else "likes")) if content_tweet['favorite_count'] else "",
            (", " if content_tweet['favorite_count'] and content_tweet['retweet_count'] else ""),
            ("<b>%s</b> %s" % (content_tweet['retweet_count'], "retweet" if content_tweet['retweet_count'] == 1 else "retweets")) if content_tweet['retweet_count'] else "",
        )
        
        story = {
            'title': tweet_title,
            'link': "https://twitter.com/%s/status/%s" % (original_author_name, user_tweet['id']),
            'description': content,
            'author_name': author_name,
            'categories': list(categories),
            'unique_id': "tweet:%s" % user_tweet['id'],
            'pubdate': user_tweet['created_at'],
        }
        
        return story
