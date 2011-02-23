from collections import defaultdict
from django.db import models
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed, DuplicateFeed
from apps.reader.models import UserSubscription, UserSubscriptionFolders
import datetime
from StringIO import StringIO
from lxml import etree
from utils import json_functions as json, urlnorm
import utils.opml as opml
from utils import log as logging

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
                # if hasattr(folder, 'text'):
                #     logging.info(' ---> [%s] ~FRNew Folder: %s' % (self.user, folder.text))
                folders.append({folder.text: self.process_outline(folder)})
            elif hasattr(item, 'xmlUrl'):
                feed = item
                if not hasattr(feed, 'htmlUrl'):
                    setattr(feed, 'htmlUrl', None)
                if not hasattr(feed, 'title') or not feed.title:
                    setattr(feed, 'title', feed.htmlUrl or feed.xmlUrl)
                feed_address = urlnorm.normalize(feed.xmlUrl)
                feed_link = urlnorm.normalize(feed.htmlUrl)
                if len(feed_address) > Feed._meta.get_field('feed_address').max_length:
                    continue
                if feed_link and len(feed_link) > Feed._meta.get_field('feed_link').max_length:
                    continue
                # logging.info(' ---> \t~FR%s - %s - %s' % (feed.title, feed_link, feed_address,))
                feed_data = dict(feed_address=feed_address, feed_link=feed_link, feed_title=feed.title)
                # feeds.append(feed_data)

                # See if it exists as a duplicate first
                duplicate_feed = DuplicateFeed.objects.filter(duplicate_address=feed_address)
                if duplicate_feed:
                    feed_db = duplicate_feed[0].feed
                else:
                    feed_data['active_subscribers'] = 1
                    feed_data['num_subscribers'] = 1
                    feed_db, _ = Feed.objects.get_or_create(feed_address=feed_address,
                                                            defaults=dict(**feed_data))
                    
                us, _ = UserSubscription.objects.get_or_create(
                    feed=feed_db, 
                    user=self.user,
                    defaults={
                        'needs_unread_recalc': True,
                        'mark_read_date': datetime.datetime.utcnow() - datetime.timedelta(days=1),
                        'active': self.user.profile.is_premium,
                    }
                )
                if self.user.profile.is_premium and not us.active:
                    us.active = True
                    us.save()
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
        # print dict(folders)
        self.rearrange_folders(folders)
        logging.user(self.user, "~BB~FW~SBGoogle Reader import: ~BT~FW%s" % (self.subscription_folders))
        UserSubscriptionFolders.objects.get_or_create(user=self.user, defaults=dict(
                                                      folders=json.encode(self.subscription_folders)))


    def parse(self):
        parser = etree.XMLParser(recover=True)
        tree = etree.parse(StringIO(self.feeds_xml), parser)
        self.feeds = tree.xpath('/object/list/object')
    
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
        
        try:
            feed_link = urlnorm.normalize(feed_link)
            feed_address = urlnorm.normalize(feed_address)

            if len(feed_address) > Feed._meta.get_field('feed_address').max_length:
                return folders

            # See if it exists as a duplicate first
            duplicate_feed = DuplicateFeed.objects.filter(duplicate_address=feed_address)
            if duplicate_feed:
                feed_db = duplicate_feed[0].feed
            else:
                feed_data = dict(feed_address=feed_address, feed_link=feed_link, feed_title=feed_title)
                feed_data['active_subscribers'] = 1
                feed_data['num_subscribers'] = 1
                feed_db, _ = Feed.objects.get_or_create(feed_address=feed_address,
                                                        defaults=dict(**feed_data))

            us, _ = UserSubscription.objects.get_or_create(
                feed=feed_db, 
                user=self.user,
                defaults={
                    'needs_unread_recalc': True,
                    'mark_read_date': datetime.datetime.utcnow() - datetime.timedelta(days=1),
                    'active': self.user.profile.is_premium,
                }
            )
            if not category: category = "Root"
            folders[category].append(feed_db.pk)
        except Exception, e:
            logging.info(' *** -> Exception: %s' % e)
            
        return folders
        
    def rearrange_folders(self, folders, depth=0):
        for folder, items in folders.items():
            if folder == 'Root':
                self.subscription_folders += items
            else:
                # folder_parents = folder.split(u' \u2014 ')
                self.subscription_folders.append({folder: items})
     