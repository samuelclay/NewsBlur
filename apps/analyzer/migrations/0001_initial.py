
from south.db import db
from django.db import models
from apps.analyzer.models import *

class Migration:
    
    def forwards(self, orm):
        
        # Adding model 'FeatureCategory'
        db.create_table('analyzer_featurecategory', (
            ('id', orm['analyzer.FeatureCategory:id']),
            ('user', orm['analyzer.FeatureCategory:user']),
            ('feed', orm['analyzer.FeatureCategory:feed']),
            ('feature', orm['analyzer.FeatureCategory:feature']),
            ('category', orm['analyzer.FeatureCategory:category']),
            ('count', orm['analyzer.FeatureCategory:count']),
        ))
        db.send_create_signal('analyzer', ['FeatureCategory'])
        
        # Adding model 'ClassifierTag'
        db.create_table('analyzer_classifiertag', (
            ('id', orm['analyzer.ClassifierTag:id']),
            ('user', orm['analyzer.ClassifierTag:user']),
            ('score', orm['analyzer.ClassifierTag:score']),
            ('tag', orm['analyzer.ClassifierTag:tag']),
            ('feed', orm['analyzer.ClassifierTag:feed']),
            ('original_story', orm['analyzer.ClassifierTag:original_story']),
            ('creation_date', orm['analyzer.ClassifierTag:creation_date']),
        ))
        db.send_create_signal('analyzer', ['ClassifierTag'])
        
        # Adding model 'ClassifierFeed'
        db.create_table('analyzer_classifierfeed', (
            ('id', orm['analyzer.ClassifierFeed:id']),
            ('user', orm['analyzer.ClassifierFeed:user']),
            ('score', orm['analyzer.ClassifierFeed:score']),
            ('feed', orm['analyzer.ClassifierFeed:feed']),
            ('original_story', orm['analyzer.ClassifierFeed:original_story']),
            ('creation_date', orm['analyzer.ClassifierFeed:creation_date']),
        ))
        db.send_create_signal('analyzer', ['ClassifierFeed'])
        
        # Adding model 'ClassifierTitle'
        db.create_table('analyzer_classifiertitle', (
            ('id', orm['analyzer.ClassifierTitle:id']),
            ('user', orm['analyzer.ClassifierTitle:user']),
            ('score', orm['analyzer.ClassifierTitle:score']),
            ('title', orm['analyzer.ClassifierTitle:title']),
            ('feed', orm['analyzer.ClassifierTitle:feed']),
            ('original_story', orm['analyzer.ClassifierTitle:original_story']),
            ('creation_date', orm['analyzer.ClassifierTitle:creation_date']),
        ))
        db.send_create_signal('analyzer', ['ClassifierTitle'])
        
        # Adding model 'Category'
        db.create_table('analyzer_category', (
            ('id', orm['analyzer.Category:id']),
            ('user', orm['analyzer.Category:user']),
            ('feed', orm['analyzer.Category:feed']),
            ('category', orm['analyzer.Category:category']),
            ('count', orm['analyzer.Category:count']),
        ))
        db.send_create_signal('analyzer', ['Category'])
        
        # Adding model 'ClassifierAuthor'
        db.create_table('analyzer_classifierauthor', (
            ('id', orm['analyzer.ClassifierAuthor:id']),
            ('user', orm['analyzer.ClassifierAuthor:user']),
            ('score', orm['analyzer.ClassifierAuthor:score']),
            ('author', orm['analyzer.ClassifierAuthor:author']),
            ('feed', orm['analyzer.ClassifierAuthor:feed']),
            ('original_story', orm['analyzer.ClassifierAuthor:original_story']),
            ('creation_date', orm['analyzer.ClassifierAuthor:creation_date']),
        ))
        db.send_create_signal('analyzer', ['ClassifierAuthor'])
        
    
    
    def backwards(self, orm):
        
        # Deleting model 'FeatureCategory'
        db.delete_table('analyzer_featurecategory')
        
        # Deleting model 'ClassifierTag'
        db.delete_table('analyzer_classifiertag')
        
        # Deleting model 'ClassifierFeed'
        db.delete_table('analyzer_classifierfeed')
        
        # Deleting model 'ClassifierTitle'
        db.delete_table('analyzer_classifiertitle')
        
        # Deleting model 'Category'
        db.delete_table('analyzer_category')
        
        # Deleting model 'ClassifierAuthor'
        db.delete_table('analyzer_classifierauthor')
        
    
    
    models = {
        'analyzer.category': {
            'category': ('django.db.models.fields.CharField', [], {'max_length': '255'}),
            'count': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['auth.User']"})
        },
        'analyzer.classifierauthor': {
            'author': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.StoryAuthor']"}),
            'creation_date': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'blank': 'True'}),
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'original_story': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Story']", 'null': 'True'}),
            'score': ('django.db.models.fields.SmallIntegerField', [], {}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['auth.User']"})
        },
        'analyzer.classifierfeed': {
            'creation_date': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'blank': 'True'}),
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'original_story': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Story']", 'null': 'True'}),
            'score': ('django.db.models.fields.SmallIntegerField', [], {}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['auth.User']"})
        },
        'analyzer.classifiertag': {
            'creation_date': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'blank': 'True'}),
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'original_story': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Story']", 'null': 'True'}),
            'score': ('django.db.models.fields.SmallIntegerField', [], {}),
            'tag': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Tag']"}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['auth.User']"})
        },
        'analyzer.classifiertitle': {
            'creation_date': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'blank': 'True'}),
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'original_story': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Story']", 'null': 'True'}),
            'score': ('django.db.models.fields.SmallIntegerField', [], {}),
            'title': ('django.db.models.fields.CharField', [], {'max_length': '255'}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['auth.User']"})
        },
        'analyzer.featurecategory': {
            'category': ('django.db.models.fields.CharField', [], {'max_length': '255'}),
            'count': ('django.db.models.fields.IntegerField', [], {'default': '0'}),
            'feature': ('django.db.models.fields.CharField', [], {'max_length': '255'}),
            'feed': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['rss_feeds.Feed']"}),
            'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': "orm['auth.User']"})
        },
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
    
    complete_apps = ['analyzer']
