# encoding: utf-8
import sys
import datetime
from south.db import db
from south.v2 import DataMigration
from django.db import models
from apps.rss_feeds.models import Feed, FeedIcon

class Migration(DataMigration):

    def forwards(self, orm):
        feeds = Feed.objects.all().order_by('-average_stories_per_month')
        feed_count = feeds.count()
        i = 0
        for feed in feeds:
            i += 1
            print "%s/%s: %s" % (i, feed_count, feed,)
            sys.stdout.flush()
        
            feed_icon = FeedIcon.objects.filter(feed=feed)
            if feed_icon:
                try:
                    feed.favicon_color = feed_icon[0].color
                    feed.favicon_not_found = feed_icon[0].not_found
                    feed.save()
                except Exception, e:
                    print '\n\n!!! %s\n\n' % e
                    continue


    def backwards(self, orm):
        "Write your backwards methods here."


    models = {
        'rss_feeds.duplicatefeed': {
            'Meta': {'object_name': 'DuplicateFeed'},
            'duplicate_address': ('django.db.models.fields.CharField', [], {'max_length': '255'}),
            'duplicate_feed_id': ('django.db.models.fields.CharField', [], {'max_length': '255', 'null': 'True'}),
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'related_name': "'duplicate_addresses'", 'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'})
        },
        'rss_feeds.feed': {
            'Meta': {'ordering': "['feed_title']", 'object_name': 'Feed', 'db_table': "'feeds'"},
            'active': ('django.db.models.fields.BooleanField', [], {'default': 'True', 'db_index': 'True'}),
            'active_subscribers': ('django.db.models.fields.IntegerField', [], {'default': '-1', 'db_index': 'True'}),
            'average_stories_per_month': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'creation': ('django.db.models.fields.DateField', [], {'auto_now_add': 'True', 'blank': 'True'}),
            'days_to_trim': ('django.db.models.fields.IntegerField', [], {'default': '90'}),
            'etag': ('django.db.models.fields.CharField', [], {'max_length': '255', 'null': 'True', 'blank': 'True'}),
            'exception_code': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'favicon_color': ('django.db.models.fields.CharField', [], {'max_length': '6', 'null': 'True', 'blank': 'True'}),
            'favicon_not_found': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'feed_address': ('django.db.models.fields.URLField', [], {'unique': 'True', 'max_length': '255'}),
            'feed_link': ('django.db.models.fields.URLField', [], {'default': "''", 'max_length': '1000', 'null': 'True', 'blank': 'True'}),
            'feed_title': ('django.db.models.fields.CharField', [], {'default': "'[Untitled]'", 'max_length': '255', 'null': 'True', 'blank': 'True'}),
            'fetched_once': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'has_feed_exception': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'db_index': 'True'}),
            'has_page_exception': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'db_index': 'True'}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'last_load_time': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'last_modified': ('django.db.models.fields.DateTimeField', [], {'null': 'True', 'blank': 'True'}),
            'last_update': ('django.db.models.fields.DateTimeField', [], {'db_index': 'True'}),
            'min_to_decay': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'next_scheduled_update': ('django.db.models.fields.DateTimeField', [], {'db_index': 'True'}),
            'num_subscribers': ('django.db.models.fields.IntegerField', [], {'default': '-1'}),
            'premium_subscribers': ('django.db.models.fields.IntegerField', [], {'default': '-1'}),
            'queued_date': ('django.db.models.fields.DateTimeField', [], {'db_index': 'True'}),
            'stories_last_month': ('django.db.models.fields.IntegerField', [], {'default': '0'})
        },
        'rss_feeds.feeddata': {
            'Meta': {'object_name': 'FeedData'},
            'feed': ('utils.fields.AutoOneToOneField', [], {'related_name': "'data'", 'unique': 'True', 'to': "orm['rss_feeds.Feed']"}),
            'feed_classifier_counts': ('django.db.models.fields.TextField', [], {'null': 'True', 'blank': 'True'}),
            'feed_tagline': ('django.db.models.fields.CharField', [], {'max_length': '1024', 'null': 'True', 'blank': 'True'}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'popular_authors': ('django.db.models.fields.CharField', [], {'max_length': '2048', 'null': 'True', 'blank': 'True'}),
            'popular_tags': ('django.db.models.fields.CharField', [], {'max_length': '1024', 'null': 'True', 'blank': 'True'}),
            'story_count_history': ('django.db.models.fields.TextField', [], {'null': 'True', 'blank': 'True'})
        },
        'rss_feeds.feedicon': {
            'Meta': {'object_name': 'FeedIcon'},
            'color': ('django.db.models.fields.CharField', [], {'max_length': '6', 'null': 'True', 'blank': 'True'}),
            'data': ('django.db.models.fields.TextField', [], {'null': 'True', 'blank': 'True'}),
            'feed': ('utils.fields.AutoOneToOneField', [], {'related_name': "'icon'", 'unique': 'True', 'primary_key': 'True', 'to': "orm['rss_feeds.Feed']"}),
            'icon_url': ('django.db.models.fields.CharField', [], {'max_length': '2000', 'null': 'True', 'blank': 'True'}),
            'not_found': ('django.db.models.fields.BooleanField', [], {'default': 'False'})
        },
        'rss_feeds.feedloadtime': {
            'Meta': {'object_name': 'FeedLoadtime'},
            'date_accessed': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'blank': 'True'}),
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'loadtime': ('django.db.models.fields.FloatField', [], {})
        },
        'rss_feeds.feedupdatehistory': {
            'Meta': {'object_name': 'FeedUpdateHistory'},
            'average_per_feed': ('django.db.models.fields.DecimalField', [], {'max_digits': '4', 'decimal_places': '1'}),
            'fetch_date': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'blank': 'True'}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'number_of_feeds': ('django.db.models.fields.IntegerField', [], {}),
            'seconds_taken': ('django.db.models.fields.IntegerField', [], {})
        }
    }

    complete_apps = ['rss_feeds']
