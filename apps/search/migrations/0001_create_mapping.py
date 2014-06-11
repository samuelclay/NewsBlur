# -*- coding: utf-8 -*-
import datetime
from south.db import db
from south.v2 import DataMigration
from django.db import models
from apps.search.models import SearchStory

class Migration(DataMigration):

    def forwards(self, orm):
        SearchStory.create_elasticsearch_mapping()
        
    def backwards(self, orm):
        "Write your backwards methods here."

    models = {
        
    }

    complete_apps = ['search']
    symmetrical = True
