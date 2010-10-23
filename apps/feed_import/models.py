from collections import defaultdict
from django.db import models
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed, DuplicateFeed
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.tasks import NewFeeds
from celery.task import Task
import datetime
import lxml.etree
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
        
    def queue_new_feeds(self):
        new_feeds = UserSubscription.objects.filter(user=self.user, feed__fetched_once=False).values('feed_id')
        new_feeds = list(set([f['feed_id'] for f in new_feeds]))
        logging.info(" ---> [%s] Queueing NewFeeds: (%s) %s" % (self.user, len(new_feeds), new_feeds))
        size = 4
        publisher = Task.get_publisher(exchange="new_feeds")
        for t in (new_feeds[pos:pos + size] for pos in xrange(0, len(new_feeds), size)):
            NewFeeds.apply_async(args=(t,), queue="new_feeds", publisher=publisher)
        publisher.connection.close()
    
class OPMLImporter(Importer):
    
    def __init__(self, opml_xml, user):
        self.user = user
        self.opml_xml = opml_xml

    def process(self):
        outline = opml.from_string(self.opml_xml)
        self.clear_feeds()
        folders = self.process_outline(outline)
        UserSubscriptionFolders.objects.create(user=self.user, folders=json.encode(folders))
        self.queue_new_feeds()
        return folders
        
    def process_outline(self, outline):
        folders = []
    
        for item in outline:
            if not hasattr(item, 'xmlUrl'):
                folder = item
                if hasattr(folder, 'text'):
                    logging.info(' ---> [%s] New Folder: %s' % (self.user, folder.text))
                folders.append({folder.text: self.process_outline(folder)})
            elif hasattr(item, 'xmlUrl'):
                feed = item
                if not hasattr(feed, 'htmlUrl'):
                    setattr(feed, 'htmlUrl', None)
                if not hasattr(feed, 'title'):
                    setattr(feed, 'title', feed.htmlUrl)
                feed_address = urlnorm.normalize(feed.xmlUrl)
                feed_link = urlnorm.normalize(feed.htmlUrl)
                if len(feed_address) > Feed._meta.get_field('feed_address').max_length:
                    continue
                if feed_link and len(feed_link) > Feed._meta.get_field('feed_link').max_length:
                    continue
                if feed.title and len(feed.title) > Feed._meta.get_field('feed_title').max_length:
                    feed.title = feed.title[:255]
                logging.info(' ---> \t%s - %s - %s' % (feed.title, feed_link, feed_address,))
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
                        'mark_read_date': datetime.datetime.utcnow() - datetime.timedelta(days=1)
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
        # print dict(folders)
        self.rearrange_folders(folders)
        logging.info(" ---> [%s] Google Reader import: %s" % (self.user, self.subscription_folders))
        UserSubscriptionFolders.objects.create(user=self.user,
                                               folders=json.encode(self.subscription_folders))
        self.queue_new_feeds()

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
                    'mark_read_date': datetime.datetime.utcnow() - datetime.timedelta(days=1)
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
        