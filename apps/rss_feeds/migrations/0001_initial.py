
from south.db import db
from django.db import models
from apps.rss_feeds.models import *

class Migration:
    
    def forwards(self, orm):
        
        # Adding model 'Feed'
        db.create_table('feeds', (
            ('id', orm['rss_feeds.Feed:id']),
            ('feed_address', orm['rss_feeds.Feed:feed_address']),
            ('feed_link', orm['rss_feeds.Feed:feed_link']),
            ('feed_title', orm['rss_feeds.Feed:feed_title']),
            ('feed_tagline', orm['rss_feeds.Feed:feed_tagline']),
            ('active', orm['rss_feeds.Feed:active']),
            ('num_subscribers', orm['rss_feeds.Feed:num_subscribers']),
            ('last_update', orm['rss_feeds.Feed:last_update']),
            ('min_to_decay', orm['rss_feeds.Feed:min_to_decay']),
            ('days_to_trim', orm['rss_feeds.Feed:days_to_trim']),
            ('creation', orm['rss_feeds.Feed:creation']),
            ('etag', orm['rss_feeds.Feed:etag']),
            ('last_modified', orm['rss_feeds.Feed:last_modified']),
            ('page_data', orm['rss_feeds.Feed:page_data']),
            ('stories_per_month', orm['rss_feeds.Feed:stories_per_month']),
            ('next_scheduled_update', orm['rss_feeds.Feed:next_scheduled_update']),
            ('last_load_time', orm['rss_feeds.Feed:last_load_time']),
        ))
        db.send_create_signal('rss_feeds', ['Feed'])
        
        # Adding model 'Tag'
        db.create_table('rss_feeds_tag', (
            ('id', orm['rss_feeds.Tag:id']),
            ('feed', orm['rss_feeds.Tag:feed']),
            ('name', orm['rss_feeds.Tag:name']),
        ))
        db.send_create_signal('rss_feeds', ['Tag'])
        
        # Adding model 'FeedPage'
        db.create_table('rss_feeds_feedpage', (
            ('id', orm['rss_feeds.FeedPage:id']),
            ('feed', orm['rss_feeds.FeedPage:feed']),
            ('page_data', orm['rss_feeds.FeedPage:page_data']),
        ))
        db.send_create_signal('rss_feeds', ['FeedPage'])
        
        # Adding model 'FeedUpdateHistory'
        db.create_table('rss_feeds_feedupdatehistory', (
            ('id', orm['rss_feeds.FeedUpdateHistory:id']),
            ('fetch_date', orm['rss_feeds.FeedUpdateHistory:fetch_date']),
            ('number_of_feeds', orm['rss_feeds.FeedUpdateHistory:number_of_feeds']),
            ('seconds_taken', orm['rss_feeds.FeedUpdateHistory:seconds_taken']),
            ('average_per_feed', orm['rss_feeds.FeedUpdateHistory:average_per_feed']),
        ))
        db.send_create_signal('rss_feeds', ['FeedUpdateHistory'])
        
        # Adding model 'Story'
        db.create_table('stories', (
            ('id', orm['rss_feeds.Story:id']),
            ('story_feed', orm['rss_feeds.Story:story_feed']),
            ('story_date', orm['rss_feeds.Story:story_date']),
            ('story_title', orm['rss_feeds.Story:story_title']),
            ('story_content', orm['rss_feeds.Story:story_content']),
            ('story_original_content', orm['rss_feeds.Story:story_original_content']),
            ('story_content_type', orm['rss_feeds.Story:story_content_type']),
            ('story_author', orm['rss_feeds.Story:story_author']),
            ('story_permalink', orm['rss_feeds.Story:story_permalink']),
            ('story_guid', orm['rss_feeds.Story:story_guid']),
            ('story_guid_hash', orm['rss_feeds.Story:story_guid_hash']),
            ('story_past_trim_date', orm['rss_feeds.Story:story_past_trim_date']),
            ('story_tags', orm['rss_feeds.Story:story_tags']),
        ))
        db.send_create_signal('rss_feeds', ['Story'])
        
        # Adding model 'FeedXML'
        db.create_table('rss_feeds_feedxml', (
            ('id', orm['rss_feeds.FeedXML:id']),
            ('feed', orm['rss_feeds.FeedXML:feed']),
            ('rss_xml', orm['rss_feeds.FeedXML:rss_xml']),
        ))
        db.send_create_signal('rss_feeds', ['FeedXML'])
        
        # Adding model 'StoryAuthor'
        db.create_table('rss_feeds_storyauthor', (
            ('id', orm['rss_feeds.StoryAuthor:id']),
            ('feed', orm['rss_feeds.StoryAuthor:feed']),
            ('author_name', orm['rss_feeds.StoryAuthor:author_name']),
        ))
        db.send_create_signal('rss_feeds', ['StoryAuthor'])
        
        # Adding ManyToManyField 'Story.tags'
        db.create_table('stories_tags', (
            ('id', models.AutoField(verbose_name='ID', primary_key=True, auto_created=True)),
            ('story', models.ForeignKey(orm.Story, null=False)),
            ('tag', models.ForeignKey(orm.Tag, null=False))
        ))
        
    
    
    def backwards(self, orm):
        
        # Deleting model 'Feed'
        db.delete_table('feeds')
        
        # Deleting model 'Tag'
        db.delete_table('rss_feeds_tag')
        
        # Deleting model 'FeedPage'
        db.delete_table('rss_feeds_feedpage')
        
        # Deleting model 'FeedUpdateHistory'
        db.delete_table('rss_feeds_feedupdatehistory')
        
        # Deleting model 'Story'
        db.delete_table('stories')
        
        # Deleting model 'FeedXML'
        db.delete_table('rss_feeds_feedxml')
        
        # Deleting model 'StoryAuthor'
        db.delete_table('rss_feeds_storyauthor')
        
        # Dropping ManyToManyField 'Story.tags'
        db.delete_table('stories_tags')
        
    
    
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
            'page_data': ('StoryField', [], {'null': 'True', 'blank': 'True'}),
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
            'tags': ('django.db.models.fields.related.ManyToManyField', [], {'to': "orm['rss_feeds.Tag']"})
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
