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

        # Changing field 'PayPalNVP.ipaddress'
        db.alter_column('paypal_nvp', 'ipaddress', self.gf('django.db.models.fields.GenericIPAddressField')(max_length=39, null=True))

    def backwards(self, orm):

        # Changing field 'PayPalNVP.ipaddress'
        db.alter_column('paypal_nvp', 'ipaddress', self.gf('django.db.models.fields.IPAddressField')(default='0.0.0.0', max_length=15))

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
            'ipaddress': ('django.db.models.fields.GenericIPAddressField', [], {'max_length': '39', 'null': 'True', 'blank': 'True'}),
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