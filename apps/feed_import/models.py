from collections import defaultdict
from django.db import models
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed
from apps.reader.models import UserSubscription, UserSubscriptionFolders
import datetime
import lxml.etree
from utils import json, urlnorm
import utils.opml as opml

class OAuthToken(models.Model):
    user = models.OneToOneField(User, null=True, blank=True)
    session_id = models.CharField(max_length=50, null=True, blank=True)
    remote_ip = models.CharField(max_length=50, null=True, blank=True)
    request_token = models.CharField(max_length=50)
    request_token_secret = models.CharField(max_length=50)
    access_token = models.CharField(max_length=50)
    access_token_secret = models.CharField(max_length=50)
    created_date = models.DateTimeField(default=datetime.datetime.now)
    

class Importer:

    def clear_feeds(self):
        UserSubscriptionFolders.objects.filter(user=self.user).delete()
        UserSubscription.objects.filter(user=self.user).delete()
        
    
class OPMLImporter(Importer):
    
    def __init__(self, opml_xml, user):
        self.user = user
        self.opml_xml = opml_xml

    def process(self):
        outline = opml.from_string(self.opml_xml)
        self.clear_feeds()
        folders = self.process_outline(outline)
        UserSubscriptionFolders.objects.create(user=self.user, folders=json.encode(folders))

        return folders
        
    def process_outline(self, outline):
        folders = []
    
        for item in outline:
            if not hasattr(item, 'xmlUrl'):
                folder = item
                print 'New Folder: %s' % folder.text
                folders.append({folder.text: self.process_outline(folder)})
            elif hasattr(item, 'xmlUrl'):
                feed = item
                if not hasattr(feed, 'htmlUrl'):
                    setattr(feed, 'htmlUrl', None)
                if not hasattr(feed, 'title'):
                    setattr(feed, 'title', feed.htmlUrl)
                feed_address = urlnorm.normalize(feed.xmlUrl)
                feed_link = urlnorm.normalize(feed.htmlUrl)
                print '\t%s - %s - %s' % (feed.title, feed_link, feed_address,)
                feed_data = dict(feed_address=feed_address, feed_link=feed_link, feed_title=feed.title)
                # feeds.append(feed_data)
                feed_db, _ = Feed.objects.get_or_create(feed_address=feed_address, defaults=dict(**feed_data))
                us, _ = UserSubscription.objects.get_or_create(
                    feed=feed_db, 
                    user=self.user,
                    defaults={
                        'needs_unread_recalc': True,
                        'mark_read_date': datetime.datetime.now() - datetime.timedelta(days=1)
                    }
                )
                folders.append(feed_db.pk)
        return folders
        

class GoogleReaderImporter(Importer):
    
    def __init__(self, feeds_xml, user):
        self.user = user
        self.feeds_xml = feeds_xml
        self.subscription_folders = []
        
    def process(self):
        self.clear_feeds()
        self.parse()

        folders = defaultdict(list)
        for item in self.feeds:
            folders = self.process_item(item, folders)
        print "Google Reader import"
        # print dict(folders)
        self.rearrange_folders(folders)
        print self.subscription_folders
        UserSubscriptionFolders.objects.create(user=self.user,
                                               folders=json.encode(self.subscription_folders))

    def parse(self):
        self.feeds = lxml.etree.fromstring(self.feeds_xml).xpath('/object/list/object')
    
    def process_item(self, item, folders):
        feed_title = item.xpath('./string[@name="title"]') and \
                        item.xpath('./string[@name="title"]')[0].text
        feed_address = item.xpath('./string[@name="id"]') and \
                        item.xpath('./string[@name="id"]')[0].text.replace('feed/', '')
        feed_link = item.xpath('./string[@name="htmlUrl"]') and \
                        item.xpath('./string[@name="htmlUrl"]')[0].text
        category = item.xpath('./list[@name="categories"]/object/string[@name="label"]') and \
                        item.xpath('./list[@name="categories"]/object/string[@name="label"]')[0].text
        
        if not feed_address:
            feed_address = feed_link
        
        feed_link = urlnorm.normalize(feed_link)
        feed_address = urlnorm.normalize(feed_address)
        
        feed_data = dict(feed_address=feed_address, feed_link=feed_link, feed_title=feed_title)
        feed_db, _ = Feed.objects.get_or_create(feed_address=feed_address, defaults=dict(**feed_data))
        us, _ = UserSubscription.objects.get_or_create(
            feed=feed_db, 
            user=self.user,
            defaults={
                'needs_unread_recalc': True,
                'mark_read_date': datetime.datetime.now() - datetime.timedelta(days=1)
            }
        )
        if not category: category = "Root"
        folders[category].append(feed_db.pk)
        return folders
        
    def rearrange_folders(self, folders, depth=0):
        for folder, items in folders.items():
            if folder == 'Root':
                self.subscription_folders += items
            else:
                folder_parents = folder.split(u' \u2014 ')
                self.subscription_folders.append({folder: items})
        