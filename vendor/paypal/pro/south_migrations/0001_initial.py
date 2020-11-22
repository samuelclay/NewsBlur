# -*- coding: utf-8 -*-
from south.utils import datetime_utils as datetime
from south.db import db
from south.v2 import SchemaMigration
from django.db import models

try:
    from django.contrib.auth import get_user_model
except ImportError:
    from django.contrib.auth.models import User
else:
    User = get_user_model()
# With the default User model these will be 'auth.User' and 'auth.user'
# so instead of using orm['auth.User'] we can use orm[user_orm_label]
user_orm_label = '%s.%s' % (User._meta.app_label, User._meta.object_name)
user_model_label = '%s.%s' % (User._meta.app_label, User._meta.module_name)

class Migration(SchemaMigration):

    def forwards(self, orm):
        # Adding model 'PayPalNVP'
        db.create_table('paypal_nvp', (
            (u'id', self.gf('django.db.models.fields.AutoField')(primary_key=True)),
            ('method', self.gf('django.db.models.fields.CharField')(max_length=64, blank=True)),
            ('ack', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
            ('profilestatus', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
            ('timestamp', self.gf('django.db.models.fields.DateTimeField')(null=True, blank=True)),
            ('profileid', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
            ('profilereference', self.gf('django.db.models.fields.CharField')(max_length=128, blank=True)),
            ('correlationid', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
            ('token', self.gf('django.db.models.fields.CharField')(max_length=64, blank=True)),
            ('payerid', self.gf('django.db.models.fields.CharField')(max_length=64, blank=True)),
            ('firstname', self.gf('django.db.models.fields.CharField')(max_length=255, blank=True)),
            ('lastname', self.gf('django.db.models.fields.CharField')(max_length=255, blank=True)),
            ('street', self.gf('django.db.models.fields.CharField')(max_length=255, blank=True)),
            ('city', self.gf('django.db.models.fields.CharField')(max_length=255, blank=True)),
            ('state', self.gf('django.db.models.fields.CharField')(max_length=255, blank=True)),
            ('countrycode', self.gf('django.db.models.fields.CharField')(max_length=2, blank=True)),
            ('zip', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
            ('invnum', self.gf('django.db.models.fields.CharField')(max_length=255, blank=True)),
            ('custom', self.gf('django.db.models.fields.CharField')(max_length=255, blank=True)),
            ('user', self.gf('django.db.models.fields.related.ForeignKey')(to=orm[user_orm_label], null=True, blank=True)),
            ('flag', self.gf('django.db.models.fields.BooleanField')(default=False)),
            ('flag_code', self.gf('django.db.models.fields.CharField')(max_length=32, blank=True)),
            ('flag_info', self.gf('django.db.models.fields.TextField')(blank=True)),
            ('ipaddress', self.gf('django.db.models.fields.IPAddressField')(max_length=15, blank=True)),
            ('query', self.gf('django.db.models.fields.TextField')(blank=True)),
            ('response', self.gf('django.db.models.fields.TextField')(blank=True)),
            ('created_at', self.gf('django.db.models.fields.DateTimeField')(auto_now_add=True, blank=True)),
            ('updated_at', self.gf('django.db.models.fields.DateTimeField')(auto_now=True, blank=True)),
        ))
        db.send_create_signal(u'pro', ['PayPalNVP'])


    def backwards(self, orm):
        # Deleting model 'PayPalNVP'
        db.delete_table('paypal_nvp')


    models = {
        user_model_label: {
            'Meta': {'object_name': User.__name__,
                     'db_table': "'%s'" % User._meta.db_table
            },
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
        },
        u'pro.paypalnvp': {
            'Meta': {'object_name': 'PayPalNVP', 'db_table': "'paypal_nvp'"},
            'ack': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'city': ('django.db.models.fields.CharField', [], {'max_length': '255', 'blank': 'True'}),
            'correlationid': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'countrycode': ('django.db.models.fields.CharField', [], {'max_length': '2', 'blank': 'True'}),
            'created_at': ('django.db.models.fields.DateTimeField', [], {'auto_now_add': 'True', 'blank': 'True'}),
            'custom': ('django.db.models.fields.CharField', [], {'max_length': '255', 'blank': 'True'}),
            'firstname': ('django.db.models.fields.CharField', [], {'max_length': '255', 'blank': 'True'}),
            'flag': ('django.db.models.fields.BooleanField', [], {'default': 'False'}),
            'flag_code': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'flag_info': ('django.db.models.fields.TextField', [], {'blank': 'True'}),
            u'id': ('django.db.models.fields.AutoField', [], {'primary_key': 'True'}),
            'invnum': ('django.db.models.fields.CharField', [], {'max_length': '255', 'blank': 'True'}),
            'ipaddress': ('django.db.models.fields.IPAddressField', [], {'max_length': '15', 'blank': 'True'}),
            'lastname': ('django.db.models.fields.CharField', [], {'max_length': '255', 'blank': 'True'}),
            'method': ('django.db.models.fields.CharField', [], {'max_length': '64', 'blank': 'True'}),
            'payerid': ('django.db.models.fields.CharField', [], {'max_length': '64', 'blank': 'True'}),
            'profileid': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'profilereference': ('django.db.models.fields.CharField', [], {'max_length': '128', 'blank': 'True'}),
            'profilestatus': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'}),
            'query': ('django.db.models.fields.TextField', [], {'blank': 'True'}),
            'response': ('django.db.models.fields.TextField', [], {'blank': 'True'}),
            'state': ('django.db.models.fields.CharField', [], {'max_length': '255', 'blank': 'True'}),
            'street': ('django.db.models.fields.CharField', [], {'max_length': '255', 'blank': 'True'}),
            'timestamp': ('django.db.models.fields.DateTimeField', [], {'null': 'True', 'blank': 'True'}),
            'token': ('django.db.models.fields.CharField', [], {'max_length': '64', 'blank': 'True'}),
            'updated_at': ('django.db.models.fields.DateTimeField', [], {'auto_now': 'True', 'blank': 'True'}),
            'user': ('django.db.models.fields.related.ForeignKey', [], {'to': u"orm[user_orm_label]", 'null': 'True', 'blank': 'True'}),
            'zip': ('django.db.models.fields.CharField', [], {'max_length': '32', 'blank': 'True'})
        }
    }

    complete_apps = ['pro']