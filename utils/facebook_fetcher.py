import re
import datetime
import dateutil.parser
from django.conf import settings
from django.utils import feedgenerator
from django.utils.html import linebreaks
from apps.social.models import MSocialServices
from apps.reader.models import UserSubscription
from utils import log as logging
from vendor.facebook import GraphAPIError

class FacebookFetcher:
    
    def __init__(self, feed, options=None):
        self.feed = feed
        self.options = options or {}
    
    def fetch(self):
        page_name = self.extract_page_name()
        if not page_name: 
            return

        facebook_user = self.facebook_user()
        if not facebook_user:
            return
        
        # If 'video', use video API to get embed:
        # f.get_object('tastyvegetarian', fields='posts')
        # f.get_object('1992797300790726', fields='embed_html')
        feed = self.fetch_page_feed(facebook_user, page_name, 'name,about,posts,videos,photos')
        
        data = {}
        data['title'] = feed.get('name', "%s on Facebook" % page_name)
        data['link'] = feed.get('link', "https://facebook.com/%s" % page_name)
        data['description'] = feed.get('about', "%s on Facebook" % page_name)
        data['lastBuildDate'] = datetime.datetime.utcnow()
        data['generator'] = 'NewsBlur Facebook API Decrapifier - %s' % settings.NEWSBLUR_URL
        data['docs'] = None
        data['feed_url'] = self.feed.feed_address
        rss = feedgenerator.Atom1Feed(**data)
        merged_data = []
        
        posts = feed.get('posts', {}).get('data', None)
        if posts:
            for post in posts:
                story_data = self.page_posts_story(facebook_user, post)
                if not story_data:
                    continue
                merged_data.append(story_data)
            
        videos = feed.get('videos', {}).get('data', None)
        if videos:
            for video in videos:
                story_data = self.page_video_story(facebook_user, video)
                if not story_data:
                    continue
                for seen_data in merged_data:
                    if story_data['link'] == seen_data['link']:
                        # Video wins over posts (and attachments)
                        seen_data['description'] = story_data['description']
                        seen_data['title'] = story_data['title']
                        break
        
        for story_data in merged_data:
            rss.add_item(**story_data)
        
        return rss.writeString('utf-8')
    
    def extract_page_name(self):
        page = None
        try:
            page_groups = re.search('facebook.com/(\w+)/?', self.feed.feed_address)
            if not page_groups:
                return
            page = page_groups.group(1)
        except IndexError:
            return
        
        return page
        
    def facebook_user(self):
        facebook_api = None
        social_services = None
        
        if self.options.get('requesting_user_id', None):
            social_services = MSocialServices.get_user(self.options.get('requesting_user_id'))
            facebook_api = social_services.facebook_api()
            if not facebook_api:
                logging.debug('   ***> [%-30s] ~FRFacebook fetch failed: %s: No facebook API for %s' % 
                              (self.feed.log_title[:30], self.feed.feed_address, self.options))
                return
        else:
            usersubs = UserSubscription.objects.filter(feed=self.feed)
            if not usersubs:
                logging.debug('   ***> [%-30s] ~FRFacebook fetch failed: %s: No subscriptions' % 
                              (self.feed.log_title[:30], self.feed.feed_address))
                return

            for sub in usersubs:
                social_services = MSocialServices.get_user(sub.user_id)
                if not social_services.facebook_uid: 
                    continue

                facebook_api = social_services.facebook_api()
                if not facebook_api: 
                    continue
                else:
                    break
        
            if not facebook_api:
                logging.debug('   ***> [%-30s] ~FRFacebook fetch failed: %s: No facebook API for %s' % 
                              (self.feed.log_title[:30], self.feed.feed_address, usersubs[0].user.username))
                return
        
        return facebook_api
    
    def fetch_page_feed(self, facebook_user, page, fields):
        try:
            stories = facebook_user.get_object(page, fields=fields)
        except GraphAPIError as e:
            message = str(e).lower()
            if 'session has expired' in message:
                logging.debug('   ***> [%-30s] ~FRFacebook page failed/expired, disconnecting facebook: %s: %s' % 
                              (self.feed.log_title[:30], self.feed.feed_address, e))
                self.feed.save_feed_history(560, "Facebook Error: Expired token")
            return {}
        
        if not stories:
            return {}

        return stories
    
    def page_posts_story(self, facebook_user, page_story):
        categories = set()
        if 'message' not in page_story:
            # Probably a story shared on the page's timeline, not a published story
            return
        message = linebreaks(page_story['message'])
        created_date = page_story['created_time']
        if isinstance(created_date, str):
            created_date = dateutil.parser.parse(created_date)
        fields = facebook_user.get_object(page_story['id'], fields='permalink_url,link,attachments')
        permalink = fields.get('link', fields['permalink_url'])
        attachments_html = ""
        if fields.get('attachments', None) and fields['attachments']['data']:
            for attachment in fields['attachments']['data']:
                if 'media' in attachment:
                    attachments_html += "<img src=\"%s\" />" % attachment['media']['image']['src']
                if attachment.get('subattachments', None):
                    for subattachment in attachment['subattachments']['data']:
                        attachments_html += "<img src=\"%s\" />" % subattachment['media']['image']['src']
            
        content = """<div class="NB-facebook-rss">
                         <div class="NB-facebook-rss-message">%s</div>
                         <div class="NB-facebook-rss-picture">%s</div>
                    </div>""" % (
            message,
            attachments_html
        )
        
        story = {
            'title': message,
            'link': permalink,
            'description': content,
            'categories': list(categories),
            'unique_id': "fb_post:%s" % page_story['id'],
            'pubdate': created_date,
        }
        
        return story
    
    def page_video_story(self, facebook_user, page_story):
        categories = set()
        if 'description' not in page_story:
            return
        message = linebreaks(page_story['description'])
        created_date = page_story['updated_time']
        if isinstance(created_date, str):
            created_date = dateutil.parser.parse(created_date)
        permalink = facebook_user.get_object(page_story['id'], fields='permalink_url')['permalink_url']
        embed_html = facebook_user.get_object(page_story['id'], fields='embed_html')
        
        if permalink.startswith('/'):
            permalink = "https://www.facebook.com%s" % permalink
        
        content = """<div class="NB-facebook-rss">
                         <div class="NB-facebook-rss-message">%s</div>
                         <div class="NB-facebook-rss-embed">%s</div>
                    </div>""" % (
            message,
            embed_html.get('embed_html', '')
        )
        
        story = {
            'title': page_story.get('story', message),
            'link': permalink,
            'description': content,
            'categories': list(categories),
            'unique_id': "fb_post:%s" % page_story['id'],
            'pubdate': created_date,
        }
        
        return story
    
    def favicon_url(self):
        page_name = self.extract_page_name()
        facebook_user = self.facebook_user()
        if not facebook_user:
            logging.debug('   ***> [%-30s] ~FRFacebook icon failed, disconnecting facebook: %s' % 
                          (self.feed.log_title[:30], self.feed.feed_address))
            return
        
        try:
            picture_data = facebook_user.get_object(page_name, fields='picture')
        except GraphAPIError as e:
            message = str(e).lower()
            if 'session has expired' in message:
                logging.debug('   ***> [%-30s] ~FRFacebook icon failed/expired, disconnecting facebook: %s: %s' % 
                              (self.feed.log_title[:30], self.feed.feed_address, e))
            return

        if 'picture' in picture_data:
            return picture_data['picture']['data']['url']
        