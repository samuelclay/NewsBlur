from base64 import binascii
from django.db import models
from django.utils.text import compress_string
from django.db.models.signals import post_init
from django.utils.encoding import smart_unicode

from south.modelsinspector import add_introspection_rules
add_introspection_rules([], ["^utils\.compressed_textfield\.StoryField"])
add_introspection_rules([], ["^utils\.compressed_textfield\.CompressedTextField"])

def uncompress_string(s):
    '''helper function to reverse django.utils.text.compress_string'''
    import cStringIO, gzip
    try:
        zbuf = cStringIO.StringIO(s)
        zfile = gzip.GzipFile(fileobj=zbuf)
        ret = zfile.read()
        zfile.close()
    except:
        ret = s
    return ret
    
class StoryField(models.TextField):
    
    __metaclass__ = models.SubfieldBase
    
    def to_python(self, value):
        
        if not value:
            return None
            
        # print 'From DB: %s %s' % (len(value), value[:25],)
        try:
            return unicode(value.decode('base64').decode('zlib'))
        except:
            return value
        
    def get_prep_save(self, value):
        
        if value:
            # print "Pre To DB: %s %s" % (len(value), value[:25])
            value = value.encode('zlib').encode('base64')            
            # print "Post To DB: %s %s" % (len(value), value[:25])
        
        return super(StoryField, self).get_prep_save(value)


class CompressedTextField(models.TextField):
    '''transparently compress data before hitting the db and uncompress after fetching'''

    def get_db_prep_save(self, value):
        if value is not None:
            value = compress_string(value) 
        return models.TextField.get_db_prep_save(self, value)
 
    def _get_val_from_obj(self, obj):
        if obj:
            return uncompress_string(getattr(obj, self.attname))
        else:
            return self.get_default() 
    
    def post_init(self, instance=None, **kwargs):
        value = self._get_val_from_obj(instance)
        if value:
            setattr(instance, self.attname, value)

    def contribute_to_class(self, cls, name):
        super(CompressedTextField, self).contribute_to_class(cls, name)
        post_init.connect(self.post_init, sender=cls)
    
    def get_internal_type(self):
        return "TextField"
                
    def db_type(self):
        from django.conf import settings
        db_types = {'mysql':'longblob','sqlite3':'blob'}
        try:
            return db_types[settings.DATABASE_ENGINE]
        except KeyError:
            raise Exception, '%s currently works only with: %s'%(self.__class__.__name__,','.join(db_types.keys()))