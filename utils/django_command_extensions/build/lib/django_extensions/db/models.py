"""
Django Extensions abstract base model classes.
"""

from django.db import models
from django_extensions.db.fields import ModificationDateTimeField, CreationDateTimeField

class TimeStampedModel(models.Model):
    """ TimeStampedModel
    An abstract base class model that provides self-managed "created" and
    "modified" fields.
    """
    created = CreationDateTimeField()
    modified = ModificationDateTimeField()
    
    class Meta:
        abstract = True
