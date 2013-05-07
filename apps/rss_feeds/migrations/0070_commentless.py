# -*- coding: utf-8 -*-
import hashlib
from south.v2 import DataMigration
from apps.rss_feeds.models import Feed
from django.db import transaction

class Migration(DataMigration):

    @transaction.autocommit
    def forwards(self, orm):
        feeds = Feed.objects.filter(
            feed_address__contains='?feed=comments-rss2'
        )
        feeds_count = feeds.count()
        print " ---> Found %s feeds" % feeds_count

        for f, feed in enumerate(feeds):
            print " ---> %4s/%s: %s - %s" % (f, feeds_count, feed, feed.feed_address)
            feed.feed_address = feed.feed_address.replace('?feed=comments-rss2', '?feed=rss2')
            feed_address = feed.feed_address or ""
            feed_link = feed.feed_link or ""
            hash_address_and_link = hashlib.sha1(feed_address+feed_link).hexdigest()
            duplicate_feeds = Feed.objects.filter(hash_address_and_link=hash_address_and_link)
            if not duplicate_feeds:
                feed.save()
            elif feed.pk != duplicate_feeds[0].pk:
                print(" ---> Found different feed (%s), merging..." % duplicate_feeds[0])
                try:
                    Feed.merge_feeds(duplicate_feeds[0].pk, feed.pk, force=True)
                except Exception, e:
                    print " ***> Exception in merge: %s" % e
            else:
                feed.save()

    def backwards(self, orm):
        "Write your backwards methods here."

    models = {
        u'rss_feeds.duplicatefeed': {
            'Meta': {'object_name': 'DuplicateFeed'},
            'duplicate_address': ('django.db.models.fields.CharField', [], {'max_length': '764', 'db_index': 'True'}),
            'duplicate_feed_id': ('django.db.models.fields.CharField', [], {'max_length': '255', 'null': 'True', 'db_index': 'True'}),
            'duplicate_link': ('django.db.models.fields.CharField', [], {'max_length': '764', 'null': 'True', 'db_index': 'True'}),
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'related_name': "'duplicate_addresses'", 'to': u"orm['rss_feeds.Feed']"}),
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'})
        },
        u'rss_feeds.feed': {
            'Meta': {'ordering': "['feed_title']", 'object_name': 'Feed', 'db_table': "'feeds'"},
            'active': ('django.db.models.fields.BooleanField', [], {'default': 'True', 'db_index': 'True'}),
            'active_premium_subscribers': ('django.db.models.fields.IntegerField', [], {'default': '-1'}),
            'active_subscribers': ('django.db.models.fields.IntegerField', [], {'default': '-1', 'db_index': 'True'}),
            'average_stories_per_month': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'branch_from_feed': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm['rss_feeds.Feed']", 'null': 'True', 'blank': 'True'}),
            'creation': ('django.db.models.fields.DateField', [], {'auto_now_add': 'True', 'blank': 'True'}),
            'days_to_trim': ('django.db.models.fields.IntegerField', [], {'default': '90'}),
            'errors_since_good': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'etag': ('django.db.models.fields.CharField', [], {'max_length': '255', 'null': 'True', 'blank': 'True'}),
            'exception_code': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'favicon_color': ('django.db.models.fields.CharField', [], {'max_length': '6', 'null': 'True', 'blank': 'True'}),
            'favicon_not_found': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'feed_address': ('django.db.models.fields.URLField', [], {'max_length': '764', 'db_index': 'True'}),
            'feed_address_locked': ('django.db.models.fields.NullBooleanField', [], {'default': 'False', 'null': 'True', 'blank': 'True'}),
            'feed_link': ('django.db.models.fields.URLField', [], {'default': "''", 'max_length': '1000', 'null': 'True', 'blank': 'True'}),
            'feed_link_locked': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'feed_title': ('django.db.models.fields.CharField', [], {'default': "'[Untitled]'", 'max_length': '255', 'null': 'True', 'blank': 'True'}),
            'fetched_once': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'has_feed_exception': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'db_index': 'True'}),
            'has_page': ('django.db.models.fields.BooleanField', [], {'default': 'True'}),
            'has_page_exception': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'db_index': 'True'}),
            'hash_address_and_link': ('django.db.models.fields.CharField', [], {'unique': 'True', 'max_length': '64'}),
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'is_push': ('django.db.models.fields.NullBooleanField', [], {'default': 'False', 'null': 'True', 'blank': 'True'}),
            'known_good': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'last_load_time': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'last_modified': ('django.db.models.fields.DateTimeField', [], {'null': 'True', 'blank': 'True'}),
            'last_story_date': ('django.db.models.fields.DateTimeField', [], {'null': 'True', 'blank': 'True'}),
            'last_update': ('django.db.models.fields.DateTimeField', [], {'db_index': 'True'}),
            'min_to_decay': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'next_scheduled_update': ('django.db.models.fields.DateTimeField', [], {}),
            'num_subscribers': ('django.db.models.fields.IntegerField', [], {'default': '-1'}),
            'premium_subscribers': ('django.db.models.fields.IntegerField', [], {'default': '-1'}),
            's3_icon': ('django.db.models.fields.NullBooleanField', [], {'default': 'False', 'null': 'True', 'blank': 'True'}),
            's3_page': ('django.db.models.fields.NullBooleanField', [], {'default': 'False', 'null': 'True', 'blank': 'True'}),
            'stories_last_month': ('django.db.models.fields.IntegerField', [], {'default': '0'})
        },
        u'rss_feeds.feeddata': {
            'Meta': {'object_name': 'FeedData'},
            'feed': ('utils.fields.AutoOneToOneField', [], {'related_name': "'data'", 'unique': 'True', 'to': u"orm['rss_feeds.Feed']"}),
            'feed_classifier_counts': ('django.db.models.fields.TextField', [], {'null': 'True', 'blank': 'True'}),
            'feed_tagline': ('django.db.models.fields.CharField', [], {'max_length': '1024', 'null': 'True', 'blank': 'True'}),
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'popular_authors': ('django.db.models.fields.CharField', [], {'max_length': '2048', 'null': 'True', 'blank': 'True'}),
            'popular_tags': ('django.db.models.fields.CharField', [], {'max_length': '1024', 'null': 'True', 'blank': 'True'}),
            'story_count_history': ('django.db.models.fields.TextField', [], {'null': 'True', 'blank': 'True'})
        }
    }

    complete_apps = ['rss_feeds']
    symmetrical = True
