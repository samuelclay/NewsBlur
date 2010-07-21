# encoding: utf-8
import datetime
from south.db import db
from south.v2 import SchemaMigration
from django.db import models

class Migration(SchemaMigration):

    def forwards(self, orm):
        
        # Adding field 'UserSubscription.feed_opens'
        db.add_column('reader_usersubscription', 'feed_opens', self.gf('django.db.models.fields.IntegerField')(default=0), keep_default=False)


    def backwards(self, orm):
        
        # Deleting field 'UserSubscription.feed_opens'
        db.delete_column('reader_usersubscription', 'feed_opens')


    models = {
        'auth.group': {
            'Meta': {'object_name': 'Group'},
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'name': ('django.db.models.fields.CharField', [], {'unique': 'True', 'max_length': '80'}),
            'permissions': ('django.db.models.fields.related.ManyToManyField', [], {'to': "orm['auth.Permission']", 'symmetrical': 'False', 'blank': 'True'})
        },
        'auth.permission': {
            'Meta': {'unique_together': "(('content_type', 'codename'),)", 'object_name': 'Permission'},
            'codename': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'content_type': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['contenttypes.ContentType']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'name': ('django.db.models.fields.CharField', [], {'max_length': '50'})
        },
        'auth.user': {
            'Meta': {'object_name': 'User'},
            'date_joined': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime.now'}),
            'email': ('django.db.models.fields.EmailField', [], {'max_length': '75', 'blank': 'True'}),
            'first_name': ('django.db.models.fields.CharField', [], {'max_length': '30', 'blank': 'True'}),
            'groups': ('django.db.models.fields.related.ManyToManyField', [], {'to': "orm['auth.Group']", 'symmetrical': 'False', 'blank': 'True'}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'is_active': ('django.db.models.fields.BooleanField', [], {'default': 'True', 'blank': 'True'}),
            'is_staff': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'blank': 'True'}),
            'is_superuser': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'blank': 'True'}),
            'last_login': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime.now'}),
            'last_name': ('django.db.models.fields.CharField', [], {'max_length': '30', 'blank': 'True'}),
            'password': ('django.db.models.fields.CharField', [], {'max_length': '128'}),
            'user_permissions': ('django.db.models.fields.related.ManyToManyField', [], {'to': "orm['auth.Permission']", 'symmetrical': 'False', 'blank': 'True'}),
            'username': ('django.db.models.fields.CharField', [], {'unique': 'True', 'max_length': '30'})
        },
        'contenttypes.contenttype': {
            'Meta': {'unique_together': "(('app_label', 'model'),)", 'object_name': 'ContentType', 'db_table': "'django_content_type'"},
            'app_label': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'model': ('django.db.models.fields.CharField', [], {'max_length': '100'}),
            'name': ('django.db.models.fields.CharField', [], {'max_length': '100'})
        },
        'reader.feature': {
            'Meta': {'object_name': 'Feature'},
            'date': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime.now'}),
            'description': ('django.db.models.fields.TextField', [], {'default': "''"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'})
        },
        'reader.userstory': {
            'Meta': {'unique_together': "(('user', 'feed', 'story'),)", 'object_name': 'UserStory'},
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'opinion': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'read_date': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'blank': 'True'}),
            'story': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Story']"}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['auth.User']"})
        },
        'reader.usersubscription': {
            'Meta': {'unique_together': "(('user', 'feed'),)", 'object_name': 'UserSubscription'},
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'feed_opens': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'last_read_date': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime(2010, 7, 6, 20, 17, 40, 108259)'}),
            'mark_read_date': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime(2010, 7, 6, 20, 17, 40, 108313)'}),
            'needs_unread_recalc': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'blank': 'True'}),
            'unread_count_negative': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'unread_count_neutral': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'unread_count_positive': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'unread_count_updated': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime(2000, 1, 1, 0, 0)'}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['auth.User']"})
        },
        'reader.usersubscriptionfolders': {
            'Meta': {'object_name': 'UserSubscriptionFolders'},
            'folders': ('django.db.models.fields.TextField', [], {'default': "'[]'"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['auth.User']"})
        },
        'rss_feeds.feed': {
            'Meta': {'object_name': 'Feed', 'db_table': "'feeds'"},
            'active': ('django.db.models.fields.BooleanField', [], {'default': 'True', 'blank': 'True'}),
            'creation': ('django.db.models.fields.DateField', [], {'auto_now_add': 'True', 'blank': 'True'}),
            'days_to_trim': ('django.db.models.fields.IntegerField', [], {'default': '90'}),
            'etag': ('django.db.models.fields.CharField', [], {'max_length': '50', 'null': 'True', 'blank': 'True'}),
            'feed_address': ('django.db.models.fields.URLField', [], {'unique': 'True', 'max_length': '255'}),
            'feed_link': ('django.db.models.fields.URLField', [], {'default': "''", 'max_length': '200', 'null': 'True', 'blank': 'True'}),
            'feed_tagline': ('django.db.models.fields.CharField', [], {'default': "''", 'max_length': '1024', 'null': 'True', 'blank': 'True'}),
            'feed_title': ('django.db.models.fields.CharField', [], {'default': "''", 'max_length': '255', 'null': 'True', 'blank': 'True'}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'last_load_time': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'last_modified': ('django.db.models.fields.DateTimeField', [], {'null': 'True', 'blank': 'True'}),
            'last_update': ('django.db.models.fields.DateTimeField', [], {'default': '0', 'auto_now': 'True', 'blank': 'True'}),
            'min_to_decay': ('django.db.models.fields.IntegerField', [], {'default': '15'}),
            'next_scheduled_update': ('django.db.models.fields.DateTimeField', [], {'default': 'datetime.datetime.now'}),
            'num_subscribers': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'popular_authors': ('django.db.models.fields.CharField', [], {'max_length': '2048', 'null': 'True', 'blank': 'True'}),
            'popular_tags': ('django.db.models.fields.CharField', [], {'max_length': '1024', 'null': 'True', 'blank': 'True'}),
            'stories_per_month': ('django.db.models.fields.IntegerField', [], {'default': '0'})
        },
        'rss_feeds.story': {
            'Meta': {'unique_together': "(('story_feed', 'story_guid_hash'),)", 'object_name': 'Story', 'db_table': "'stories'"},
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'story_author': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.StoryAuthor']"}),
            'story_author_name': ('django.db.models.fields.CharField', [], {'max_length': '500', 'null': 'True', 'blank': 'True'}),
            'story_content': ('utils.compressed_textfield.StoryField', [], {'null': 'True', 'blank': 'True'}),
            'story_content_type': ('django.db.models.fields.CharField', [], {'max_length': '255', 'null': 'True', 'blank': 'True'}),
            'story_date': ('django.db.models.fields.DateTimeField', [], {}),
            'story_feed': ('django.db.models.fields.related.ForeignKey', [], {'related_name': "'stories'", 'to': "orm['rss_feeds.Feed']"}),
            'story_guid': ('django.db.models.fields.CharField', [], {'max_length': '1000'}),
            'story_guid_hash': ('django.db.models.fields.CharField', [], {'max_length': '40'}),
            'story_original_content': ('utils.compressed_textfield.StoryField', [], {'null': 'True', 'blank': 'True'}),
            'story_past_trim_date': ('django.db.models.fields.BooleanField', [], {'default': 'False', 'blank': 'True'}),
            'story_permalink': ('django.db.models.fields.CharField', [], {'max_length': '1000'}),
            'story_tags': ('django.db.models.fields.CharField', [], {'max_length': '2000', 'null': 'True', 'blank': 'True'}),
            'story_title': ('django.db.models.fields.CharField', [], {'max_length': '255'}),
            'tags': ('django.db.models.fields.related.ManyToManyField', [], {'to': "orm['rss_feeds.Tag']", 'symmetrical': 'False'})
        },
        'rss_feeds.storyauthor': {
            'Meta': {'object_name': 'StoryAuthor'},
            'author_name': ('django.db.models.fields.CharField', [], {'max_length': '255', 'null': 'True', 'blank': 'True'}),
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'})
        },
        'rss_feeds.tag': {
            'Meta': {'object_name': 'Tag'},
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'name': ('django.db.models.fields.CharField', [], {'max_length': '255'})
        }
    }

    complete_apps = ['reader']
