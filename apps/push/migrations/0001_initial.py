# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations
import datetime


class Migration(migrations.Migration):

    dependencies = [
        ('rss_feeds', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='PushSubscription',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('hub', models.URLField(db_index=True)),
                ('topic', models.URLField(db_index=True)),
                ('verified', models.BooleanField(default=False)),
                ('verify_token', models.CharField(max_length=60)),
                ('lease_expires', models.DateTimeField(default=datetime.datetime.now)),
                ('feed', models.OneToOneField(related_name=b'push', to='rss_feeds.Feed')),
            ],
            options={
            },
            bases=(models.Model,),
        ),
    ]
