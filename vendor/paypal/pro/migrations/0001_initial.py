# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations
from django.conf import settings


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='PayPalNVP',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('method', models.CharField(max_length=64, blank=True)),
                ('ack', models.CharField(max_length=32, blank=True)),
                ('profilestatus', models.CharField(max_length=32, blank=True)),
                ('timestamp', models.DateTimeField(null=True, blank=True)),
                ('profileid', models.CharField(max_length=32, blank=True)),
                ('profilereference', models.CharField(max_length=128, blank=True)),
                ('correlationid', models.CharField(max_length=32, blank=True)),
                ('token', models.CharField(max_length=64, blank=True)),
                ('payerid', models.CharField(max_length=64, blank=True)),
                ('firstname', models.CharField(max_length=255, verbose_name='First Name', blank=True)),
                ('lastname', models.CharField(max_length=255, verbose_name='Last Name', blank=True)),
                ('street', models.CharField(max_length=255, verbose_name='Street Address', blank=True)),
                ('city', models.CharField(max_length=255, verbose_name='City', blank=True)),
                ('state', models.CharField(max_length=255, verbose_name='State', blank=True)),
                ('countrycode', models.CharField(max_length=2, verbose_name='Country', blank=True)),
                ('zip', models.CharField(max_length=32, verbose_name='Postal / Zip Code', blank=True)),
                ('invnum', models.CharField(max_length=255, blank=True)),
                ('custom', models.CharField(max_length=255, blank=True)),
                ('flag', models.BooleanField(default=False)),
                ('flag_code', models.CharField(max_length=32, blank=True)),
                ('flag_info', models.TextField(blank=True)),
                ('ipaddress', models.IPAddressField(blank=True)),
                ('query', models.TextField(blank=True)),
                ('response', models.TextField(blank=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.ForeignKey(blank=True, to=settings.AUTH_USER_MODEL, null=True)),
            ],
            options={
                'db_table': 'paypal_nvp',
                'verbose_name': 'PayPal NVP',
            },
            bases=(models.Model,),
        ),
    ]
