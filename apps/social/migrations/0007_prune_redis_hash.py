# -*- coding: utf-8 -*-
import datetime
from south.db import db
from south.v2 import DataMigration
from django.db import models
import redis
from django.conf import settings

class Migration(DataMigration):

    def forwards(self, orm):
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        keys = r.keys("*:*:????????????????????????????????????????")
        print " ---> %s keys" % len(keys)
        for key in keys:
            print "Deleting %s" % key
            r.delete(key)
        
    def backwards(self, orm):
        "Write your backwards methods here."

    models = {
        
    }

    complete_apps = ['social']
    symmetrical = True
