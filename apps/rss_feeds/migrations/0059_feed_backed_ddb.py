# -*- coding: utf-8 -*-
import datetime
from south.db import db
from south.v2 import SchemaMigration
from django.db import models


class Migration(SchemaMigration):

    def forwards(self, orm):
        # Adding field 'Feed.backed_by_dynamodb'
        db.add_column('feeds', 'backed_by_dynamodb',
                      self.gf('django.db.models.fields.BooleanField')(default=False),
                      keep_default=False)


    def backwards(self, orm):
        # Deleting field 'Feed.backed_by_dynamodb'
        db.delete_column('feeds', 'backed_by_dynamodb')


    models = {
        'rss_feeds.duplicatefeed': {
            'Meta': {'object_name': 'DuplicateFeed'},
            'duplicate_address': ('django.db.models.fields.CharField', [], {'max_length': '255', 'db_index': 'True'}),
            'duplicate_feed_id': ('django.db.models.fields.CharField', [], {'max_length': '255', 'null': 'True', 'db_index': 'True'}),
            'duplicate_link': ('django.db.models.fields.CharField', [], {'max_length': '255', 'null': 'True', 'db_index': 'True'}),
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'related_name': "'duplicate_addresses'", 'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'})
        },
        'rss_feeds.feed': {
            'Meta': {'ordering': "['feed_title']", 'object_name': 'Feed', 'db_table': "'feeds'"},
            'active': ('django.db.models.fields.BooleanField', [], {'default': 'True', 'db_index': 'True'}),
            'active_premium_subscribers': ('django.db.models.fields.IntegerField', [], {'default': '-1', 'db_index': 'True'}),
            'active_subscribers': ('django.db.models.fields.IntegerField', [], {'default': '-1', 'db_index': 'True'}),
            'average_stories_per_month': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'backed_by_dynamodb': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'branch_from_feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']", 'null': 'True', 'blank': 'True'}),
            'creation': ('django.db.models.fields.DateField', [], {'auto_now_add': 'True', 'blank': 'True'}),
            'days_to_trim': ('django.db.models.fields.IntegerField', [], {'default': '90'}),
            'errors_since_good': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'etag': ('django.db.models.fields.CharField', [], {'max_length': '255', 'null': 'True', 'blank': 'True'}),
            'exception_code': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'favicon_color': ('django.db.models.fields.CharField', [], {'max_length': '6', 'null': 'True', 'blank': 'True'}),
            'favicon_not_found': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'feed_address': ('django.db.models.fields.URLField', [], {'max_length': '255', 'db_index': 'True'}),
            'feed_address_locked': ('django.db.models.fields.NullBooleanField', [], {'default': 'False', 'null': 'True', 'blank': 'True'}),
            'feed_link': ('django.db.models.fields.URLField', [], {'default': "''", 'max_length': '1000', 'null': 'True', 'blank': 'True'}),
            'feed_link_locked': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'feed_title': ('django.db.models.fields.CharField', [], {'default': "'[Untitled]'", 'max_length': '255', 'null': 'True', 'blank': 'True'}),
            'fetched_once': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'has_feed_exception': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'db_index': 'True'}),
            'has_page': ('django.db.models.fields.BooleanField', [], {'default': 'True'}),
            'has_page_exception': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'db_index': 'True'}),
            'hash_address_and_link': ('django.db.models.fields.CharField', [], {'unique': 'True', 'max_length': '64', 'db_index': 'True'}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'is_push': ('django.db.models.fields.NullBooleanField', [], {'default': 'False', 'null': 'True', 'blank': 'True'}),
            'known_good': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'db_index': 'True'}),
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
        'rss_feeds.feedloadtime': {
            'Meta': {'object_name': 'FeedLoadtime'},
            'date_accessed': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'blank': 'True'}),
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'loadtime': ('django.db.models.fields.FloatField', [], {})
        }
    }

    complete_apps = ['rss_feeds']