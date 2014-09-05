# -*- coding: utf-8 -*-
import datetime
from south.db import db
from south.v2 import DataMigration
from django.db import models
from apps.social.models import MSocialProfile

class Migration(DataMigration):

    def forwards(self, orm):
        facebooks = MSocialProfile.objects.filter(photo_url__startswith="//graph.facebook.com")
        print " ---> %s facebooks" % facebooks.count()
        for i, fb in enumerate(facebooks):
            fb.photo_url = fb.photo_url.replace("//graph.facebook.com", "https://graph.facebook.com")
            if i % 1000 == 0: 
                print " At: %s" % i
                print fb.photo_url
            fb.save()

        gravatars = MSocialProfile.objects.filter(photo_url__startswith="http://www.gravatar.com")
        print " ---> %s gravatars" % gravatars.count()
        for i, g in enumerate(gravatars):
            g.photo_url = g.photo_url.replace("http://", "https://")
            if i % 10 == 0: 
                print " At: %s" % i
                print g.photo_url
            g.save()

    def backwards(self, orm):
        "Write your backwards methods here."

    models = {
        
    }

    complete_apps = ['social']
    symmetrical = True
