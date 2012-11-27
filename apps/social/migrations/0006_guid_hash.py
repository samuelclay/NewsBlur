# -*- coding: utf-8 -*-
import datetime
import hashlib
from south.db import db
from south.v2 import DataMigration
from django.db import models
from apps.social.models import MSharedStory

class Migration(DataMigration):

    def forwards(self, orm):
        shared_stories = MSharedStory.objects.all()
        count = shared_stories.count()
        
        print "%s shared stories..." % count
        for s, story in enumerate(shared_stories):
            if s % 100 == 0:
                print "%s/%s" % (s+1, count)
            story.story_guid_hash = hashlib.sha1(story.story_guid).hexdigest()[:6]
            story.save()

    def backwards(self, orm):
        "Write your backwards methods here."

    models = {
        
    }

    complete_apps = ['social']
    symmetrical = True
