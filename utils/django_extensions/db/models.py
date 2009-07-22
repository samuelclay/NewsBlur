"""
Django Extensions abstract base model classes.
"""

from django.db import models
from django.utils.translation import ugettext_lazy as _
from django_extensions.db.fields import (ModificationDateTimeField,
                                         CreationDateTimeField, AutoSlugField)

class TimeStampedModel(models.Model):
    """ TimeStampedModel
    An abstract base class model that provides self-managed "created" and
    "modified" fields.
    """
    created = CreationDateTimeField(_('created'))
    modified = ModificationDateTimeField(_('modified'))

    class Meta:
        abstract = True

class TitleSlugDescriptionModel(models.Model):
    """ TitleSlugDescriptionModel
    An abstract base class model that provides title and description fields
    and a self-managed "slug" field that populates from the title.
    """
    title = models.CharField(_('title'), max_length=255)
    slug = AutoSlugField(_('slug'), populate_from='title')
    description = models.TextField(_('description'), blank=True, null=True)

    class Meta:
        abstract = True
