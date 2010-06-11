
from south.db import db
from django.db import models
from apps.reader.models import *

class Migration:
    
    def forwards(self, orm):
        
        # Adding model 'UserSubscription'
        db.create_table('reader_usersubscription', (
            ('id', orm['reader.UserSubscription:id']),
            ('user', orm['reader.UserSubscription:user']),
            ('feed', orm['reader.UserSubscription:feed']),
            ('last_read_date', orm['reader.UserSubscription:last_read_date']),
            ('mark_read_date', orm['reader.UserSubscription:mark_read_date']),
            ('unread_count_neutral', orm['reader.UserSubscription:unread_count_neutral']),
            ('unread_count_positive', orm['reader.UserSubscription:unread_count_positive']),
            ('unread_count_negative', orm['reader.UserSubscription:unread_count_negative']),
            ('unread_count_updated', orm['reader.UserSubscription:unread_count_updated']),
            ('needs_unread_recalc', orm['reader.UserSubscription:needs_unread_recalc']),
        ))
        db.send_create_signal('reader', ['UserSubscription'])
        
        # Adding model 'UserSubscriptionFolders'
        db.create_table('reader_usersubscriptionfolders', (
            ('id', orm['reader.UserSubscriptionFolders:id']),
            ('user', orm['reader.UserSubscriptionFolders:user']),
            ('folders', orm['reader.UserSubscriptionFolders:folders']),
        ))
        db.send_create_signal('reader', ['UserSubscriptionFolders'])
        
        # Adding model 'UserStory'
        db.create_table('reader_userstory', (
            ('id', orm['reader.UserStory:id']),
            ('user', orm['reader.UserStory:user']),
            ('feed', orm['reader.UserStory:feed']),
            ('story', orm['reader.UserStory:story']),
            ('read_date', orm['reader.UserStory:read_date']),
            ('opinion', orm['reader.UserStory:opinion']),
        ))
        db.send_create_signal('reader', ['UserStory'])
        
        # Creating unique_together for [user, feed] on UserSubscription.
        db.create_unique('reader_usersubscription', ['user_id', 'feed_id'])
        
        # Creating unique_together for [user, feed, story] on UserStory.
        db.create_unique('reader_userstory', ['user_id', 'feed_id', 'story_id'])
        
    
    
    def backwards(self, orm):
        
        # Deleting unique_together for [user, feed, story] on UserStory.
        db.delete_unique('reader_userstory', ['user_id', 'feed_id', 'story_id'])
        
        # Deleting unique_together for [user, feed] on UserSubscription.
        db.delete_unique('reader_usersubscription', ['user_id', 'feed_id'])
        
        # Deleting model 'UserSubscription'
        db.delete_table('reader_usersubscription')
        
        # Deleting model 'UserSubscriptionFolders'
        db.delete_table('reader_usersubscriptionfolders')
        
        # Deleting model 'UserStory'
        db.delete_table('reader_userstory')
        
    
    
    models = {
        'auth.group': {
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'name': ('django.db.models.fields.CharField', [], {'unique': 'True', 'max_length': '80'}),
            'permissions': ('django.db.models.fields.related.ManyToManyField', [], {'to': "orm['auth.Permission']", 'blank': 'True'})
        },
        'auth.permission': {
            'Meta': {'unique_together': "(('content_type', 'codename'),)"},
            'codename': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'content_type': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['contenttypes.ContentType']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'name': ('django.db.models.fields.CharField', [], {'max_length': '50'})
        },
        'auth.user': {
            'date_joined': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime.now'}),
            'email': ('django.db.models.fields.EmailField', [], {'max_length': '75', 'blank': 'True'}),
            'first_name': ('django.db.models.fields.CharField', [], {'max_length': '30', 'blank': 'True'}),
            'groups': ('django.db.models.fields.related.ManyToManyField', [], {'to': "orm['auth.Group']", 'blank': 'True'}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'is_active': ('django.db.models.fields.BooleanField', [], {'default': 'True', 'blank': 'True'}),
            'is_staff': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'blank': 'True'}),
            'is_superuser': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'blank': 'True'}),
            'last_login': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime.now'}),
            'last_name': ('django.db.models.fields.CharField', [], {'max_length': '30', 'blank': 'True'}),
            'password': ('django.db.models.fields.CharField', [], {'max_length': '128'}),
            'user_permissions': ('django.db.models.fields.related.ManyToManyField', [], {'to': "orm['auth.Permission']", 'blank': 'True'}),
            'username': ('django.db.models.fields.CharField', [], {'unique': 'True', 'max_length': '30'})
        },
        'contenttypes.contenttype': {
            'Meta': {'unique_together': "(('app_label', 'model'),)", 'db_table': "'django_content_type'"},
            'app_label': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'model': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'name': ('django.db.models.fields.CharField', [], {'max_length': '100'})
        },
        'reader.userstory': {
            'Meta': {'unique_together': "(('user', 'feed', 'story'),)"},
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'opinion': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'read_date': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'blank': 'True'}),
            'story': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Story']"}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['auth.User']"})
        },
        'reader.usersubscription': {
            'Meta': {'unique_together': "(('user', 'feed'),)"},
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'last_read_date': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime(2010, 5, 28, 16, 53, 30, 352483)'}),
            'mark_read_date': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime(2010, 5, 28, 16, 53, 30, 352527)'}),
            'needs_unread_recalc': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'blank': 'True'}),
            'unread_count_negative': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'unread_count_neutral': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'unread_count_positive': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'unread_count_updated': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime(2000, 1, 1, 0, 0)'}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['auth.User']"})
        },
        'reader.usersubscriptionfolders': {
            'folders': ('django.db.models.fields.TextField', [], {'default': "'[]'"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['auth.User']"})
        },
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
    
    complete_apps = ['reader']
