# encoding: utf-8
import datetime
from south.db import db
from south.v2 import DataMigration
from django.db import models
from apps.social.models import MSharedStory

class Migration(DataMigration):

    def forwards(self, orm):
        stories = MSharedStory.objects.filter(story_db_id__exists=False)
        story_count = stories.count()
        print " ---> %s stories with no story_db_id" % story_count
        for i, story in enumerate(stories):
            print " ---> %s/%s" % (i+1, story_count)
            story.ensure_story_db_id()

    def backwards(self, orm):
        "Write your backwards methods here."


    models = {
        
    }

    complete_apps = ['social']
