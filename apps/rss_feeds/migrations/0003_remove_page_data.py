
from south.db import db
from django.db import models
from apps.rss_feeds.models import *

class Migration:
    
    def forwards(self, orm):
        
        # Deleting field 'Feed.page_data'
        db.delete_column('feeds', 'page_data')
        
    
    
    def backwards(self, orm):
        
        # Adding field 'Feed.page_data'
        db.add_column('feeds', 'page_data', orm['rss_feeds.feed:page_data'])
        
    
    
    models = {
        'rss_feeds.feed': {
            'Meta': {'db_table': "'feeds'"},
            'active': ('django.db.models.fields.BooleanField', [], {'default': 'True', 'blank': 'True'}),
            'creation': ('django.db.models.fields.DateField', [], {'auto_now_add': 'True', 'blank': 'True'}),
            'days_to_trim': ('django.db.models.fields.IntegerField', [], {'default': '90'}),
            'etag': ('django.db.models.fields.CharField', [], {'max_length': '50', 'null': 'True', 'blank': 'True'}),
            'feed_address': ('django.db.models.fields.URLField', [], {'unique': 'True', 'max_length': '255'}),
            'feed_link': ('django.db.models.fields.URLField', [], {'default': "''", 'max_length': '200'}),
            'feed_tagline': ('django.db.models.fields.CharField', [], {'default': "''", 'max_length': '1024'}),
            'feed_title': ('django.db.models.fields.CharField', [], {'default': "''", 'max_length': '255'}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'last_load_time': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'last_modified': ('django.db.models.fields.DateTimeField', [], {'null': 'True', 'blank': 'True'}),
            'last_update': ('django.db.models.fields.DateTimeField', [], {'default': '0', 'auto_now': 'True', 'blank': 'True'}),
            'min_to_decay': ('django.db.models.fields.IntegerField', [], {'default': '15'}),
            'next_scheduled_update': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime.now'}),
            'num_subscribers': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'stories_per_month': ('django.db.models.fields.IntegerField', [], {'default': '0'})
        },
        'rss_feeds.feedpage': {
            'feed': ('django.db.models.fields.related.OneToOneField', [], {'related_name': "'feed_page'", 'unique': 'True', 'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'page_data': ('StoryField', [], {'null': 'True', 'blank': 'True'})
        },
        'rss_feeds.feedupdatehistory': {
            'average_per_feed': ('django.db.models.fields.DecimalField', [], {'max_digits': '4', 'decimal_places': '1'}),
            'fetch_date': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime.now'}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'number_of_feeds': ('django.db.models.fields.IntegerField', [], {}),
            'seconds_taken': ('django.db.models.fields.IntegerField', [], {})
        },
        'rss_feeds.feedxml': {
            'feed': ('django.db.models.fields.related.OneToOneField', [], {'related_name': "'feed_xml'", 'unique': 'True', 'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'rss_xml': ('StoryField', [], {'null': 'True', 'blank': 'True'})
        },
        'rss_feeds.story': {
            'Meta': {'db_table': "'stories'"},
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'story_author': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.StoryAuthor']"}),
            'story_content': ('StoryField', [], {'null': 'True', 'blank': 'True'}),
            'story_content_type': ('django.db.models.fields.CharField', [], {'max_length': '255', 'null': 'True', 'blank': 'True'}),
            'story_date': ('django.db.models.fields.DateTimeField', [], {}),
            'story_feed': ('django.db.models.fields.related.ForeignKey', [], {'related_name': "'stories'", 'to': "orm['rss_feeds.Feed']"}),
            'story_guid': ('django.db.models.fields.CharField', [], {'max_length': '1000'}),
            'story_guid_hash': ('django.db.models.fields.CharField', [], {'max_length': '40'}),
            'story_original_content': ('StoryField', [], {'null': 'True', 'blank': 'True'}),
            'story_past_trim_date': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'blank': 'True'}),
            'story_permalink': ('django.db.models.fields.CharField', [], {'max_length': '1000'}),
            'story_tags': ('django.db.models.fields.CharField', [], {'max_length': '1000'}),
            'story_title': ('django.db.models.fields.CharField', [], {'max_length': '255'}),
            'tags': ('django.db.models.fields.related.ManyToManyField', [], {'to': "orm['rss_feeds.Tag']", 'symmetrical': 'False'})
        },
        'rss_feeds.storyauthor': {
            'author_name': ('django.db.models.fields.CharField', [], {'max_length': '255', 'null': 'True', 'blank': 'True'}),
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'})
        },
        'rss_feeds.tag': {
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'name': ('django.db.models.fields.CharField', [], {'max_length': '255'})
        }
    }
    
    complete_apps = ['rss_feeds']
