import mongoengine as mongo
from itertools import groupby
from apps.rss_feeds.models import Feed
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from utils import json_functions as json
from utils.feed_functions import add_object_to_folder


class MCategory(mongo.Document):
    title = mongo.StringField()
    description = mongo.StringField()
    feed_ids = mongo.ListField(mongo.IntField())
    
    meta = {
        'collection': 'category',
        'indexes': ['title'],
        'allow_inheritance': False,
        'index_drop_dups': True,
    }
    
    def __unicode__(self):
        return "%s: %s sites" % (self.title, len(self.feed_ids))
    
    @classmethod
    def add(cls, title, description):
        return cls.objects.create(title=title, description=description)
        
    @classmethod
    def serialize(cls, category=None):
        categories = cls.objects.all()
        if category:
            categories = categories.filter(title=category)
        
        data = dict(categories=[], feeds={})
        feed_ids = set()
        for category in categories:
            category_output = {
                'title': category.title,
                'description': category.description,
                'feed_ids': category.feed_ids,
            }
            data['categories'].append(category_output)
            feed_ids.update(list(category.feed_ids))
        
        feeds = Feed.objects.filter(pk__in=feed_ids)
        for feed in feeds:
            data['feeds'][feed.pk] = feed.canonical()
        
        return data

    @classmethod
    def reload_sites(cls, category_title=None):
        category_sites = MCategorySite.objects.all()
        if category_title:
            category_sites = category_sites.filter(category_title=category_title)
        
        category_groups = groupby(sorted(category_sites, key=lambda c: c.category_title), key=lambda c: c.category_title)
        for category_title, sites in category_groups:
            try:
                category = cls.objects.get(title=category_title)
            except cls.DoesNotExist, e:
                print " ***> Missing category: %s" % category_title
                continue
            category.feed_ids = [site.feed_id for site in sites]
            category.save()
            print " ---> Reloaded category: %s" % category
    
    @classmethod
    def subscribe(cls, user_id, category_title):
        category = cls.objects.get(title=category_title)

        for feed_id in category.feed_ids:
            us, _ = UserSubscription.objects.get_or_create(
                feed_id=feed_id, 
                user_id=user_id,
                defaults={
                    'needs_unread_recalc': True,
                    'active': True,
                }
            )
    
        usf, created = UserSubscriptionFolders.objects.get_or_create(
            user_id=user_id,
            defaults={'folders': '[]'}
        )
        
        usf.add_folder('', category.title)
        folders = json.decode(usf.folders)
        for feed_id in category.feed_ids:
            folders = add_object_to_folder(feed_id, category.title, folders)
        usf.folders = json.encode(folders)
        usf.save()
        
        
class MCategorySite(mongo.Document):
    feed_id = mongo.IntField()
    category_title = mongo.StringField()
    
    meta = {
        'collection': 'category_site',
        'indexes': ['feed_id', 'category_title'],
        'allow_inheritance': False,
        'index_drop_dups': True,
    }
    
    def __unicode__(self):
        feed = Feed.get_by_id(self.feed_id)
        return "%s: %s" % (self.category_title, feed)
    
    @classmethod
    def add(cls, category_title, feed_id):
        category_site, created = cls.objects.get_or_create(category_title=category_title, 
                                                           feed_id=feed_id)
        
        if not created:
            print " ---> Site is already in category: %s" % category_site
        else:
            MCategory.reload_sites(category_title)