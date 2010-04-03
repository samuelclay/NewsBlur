from base64 import binascii
from django.db import models
from django.utils.text import compress_string
from django.db.models.signals import post_init
from django.utils.encoding import smart_unicode

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
            