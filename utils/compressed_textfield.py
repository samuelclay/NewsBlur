from django.db import models

from south.modelsinspector import add_introspection_rules
add_introspection_rules([], ["^utils\.compressed_textfield\.StoryField"])

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
