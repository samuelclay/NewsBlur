
from south.db import db
from django.db import models
from apps.feed_import.models import *

class Migration:
    
    def forwards(self, orm):
        "Write your forwards migration here"
    
    
    def backwards(self, orm):
        "Write your backwards migration here"
    
    
    models = {
        
    }
    
    complete_apps = ['feed_import']
