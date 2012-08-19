# -*- coding: utf-8 -*-
import datetime
from south.db import db
from south.v2 import DataMigration
from django.db import models
from apps.social.models import MInteraction, MActivity

class Migration(DataMigration):

    def forwards(self, orm):
        interactions = MInteraction.objects.all()
        print " ---> %s interactions" % interactions.count()
        
        for i, interaction in enumerate(interactions):
            if interaction.category == 'comment_reply':
                interaction.feed_id = "social:%s" % interaction.user_id
            elif interaction.category == 'reply_reply':
                interaction.feed_id = "social:%s" % interaction.feed_id
            elif interaction.category == 'comment_like':
                if not isinstance(interaction.feed_id, basestring):
                    interaction.story_feed_id = interaction.feed_id
                interaction.feed_id = "social:%s" % interaction.user_id
            elif interaction.category == 'story_reshare':
                if not isinstance(interaction.feed_id, basestring):
                    interaction.story_feed_id = interaction.feed_id
                interaction.feed_id = "social:%s" % interaction.with_user_id
            interaction.save()

        activities = MActivity.objects.all()
        print " ---> %s activities" % activities.count()
        for i, activity in enumerate(activities):
            if activity.category == 'comment_reply':
                if not isinstance(interaction.feed_id, basestring):
                    activity.story_feed_id = activity.feed_id
                activity.feed_id = "social:%s" % activity.with_user_id
            elif activity.category == 'comment_like':
                if not isinstance(interaction.feed_id, basestring):
                    activity.story_feed_id = activity.feed_id
                activity.feed_id = "social:%s" % activity.with_user_id
            elif activity.category == 'sharedstory':
                if not isinstance(interaction.feed_id, basestring):
                    activity.story_feed_id = activity.feed_id
                activity.feed_id = "social:%s" % activity.user_id
                activity.with_user_id = None
            activity.save()


    def backwards(self, orm):
        "Write your backwards methods here."

    models = {
        
    }

    complete_apps = ['social']
    symmetrical = True
