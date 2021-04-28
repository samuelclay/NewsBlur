import django
from django.db.transaction import atomic
from django.db.models import OneToOneField
try:
    from django.db.models.fields.related_descriptors import (
        ReverseOneToOneDescriptor,
    )
except ImportError:
    from django.db.models.fields.related import SingleRelatedObjectDescriptor as ReverseOneToOneDescriptor


class AutoSingleRelatedObjectDescriptor(ReverseOneToOneDescriptor):
    """
    The descriptor that handles the object creation for an AutoOneToOneField.
    """

    @atomic
    def __get__(self, instance, instance_type=None):
        model = getattr(self.related, 'related_model', self.related.model)

        try:
            return (
                super(AutoSingleRelatedObjectDescriptor, self)
                .__get__(instance, instance_type)
            )
        except model.DoesNotExist:
            # Using get_or_create instead() of save() or create() as it better handles race conditions
            obj, _ = model.objects.get_or_create(**{self.related.field.name: instance})

            # Update Django's cache, otherwise first 2 calls to obj.relobj
            # will return 2 different in-memory objects
            if django.VERSION >= (2, 0):
                self.related.set_cached_value(instance, obj)
                self.related.field.set_cached_value(obj, instance)
            else:
                setattr(instance, self.cache_name, obj)
                setattr(obj, self.related.field.get_cache_name(), instance)
            return obj

class AutoOneToOneField(OneToOneField):
    '''
    OneToOneField creates related object on first call if it doesnt exist yet.
    Use it instead of original OneToOne field.

    example:
        
        class MyProfile(models.Model):
            user = AutoOneToOneField(User, primary_key=True)
            home_page = models.URLField(max_length=255, blank=True)
            icq = models.IntegerField(max_length=255, null=True)
    '''
    def contribute_to_related_class(self, cls, related):
        setattr(cls, related.get_accessor_name(), AutoSingleRelatedObjectDescriptor(related))
