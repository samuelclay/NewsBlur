# -*- coding: utf-8 -*-
import datetime
from south.db import db
from south.v2 import DataMigration
from django.db import models

from apps.social.models import MActivity

class Migration(DataMigration):

    def forwards(self, orm):
        activities = MActivity.objects.filter(category='sharedstory', with_user_id__ne=True)
        print "Found %s activities missing sharedstory with_user." % activities.count()
        for activity in activities:
            activity.with_user_id = activity.user_id
            activity.save()
        
    def backwards(self, orm):
        "Write your backwards methods here."

    models = {
        
    }

    complete_apps = ['social']
    symmetrical = True
