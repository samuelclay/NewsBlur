# -*- coding: utf-8 -*-
import datetime
from south.db import db
from south.v2 import DataMigration
from django.db import models
from bson.objectid import ObjectId
from apps.social.models import MSharedStory

class Migration(DataMigration):

    def forwards(self, orm):
        stories = MSharedStory.objects.filter(has_replies=True)
        story_count = stories.count()
        print " ---> %s stories with replies" % story_count
        for i, story in enumerate(stories):
            print " ---> %s/%s: %s replies" % (i+1, story_count, len(story.replies))
            replies = []
            for reply in story.replies:
                if not reply.reply_id:
                    reply.reply_id = ObjectId()
                replies.append(reply)
            story.replies = replies
            story.save()

    def backwards(self, orm):
        "Write your backwards methods here."

    models = {
        
    }

    complete_apps = ['social']
    symmetrical = True
