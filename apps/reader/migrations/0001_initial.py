# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations
import datetime
from django.conf import settings


class Migration(migrations.Migration):

    dependencies = [
        ('rss_feeds', '0001_initial'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Feature',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('description', models.TextField(default=b'')),
                ('date', models.DateTimeField(default=datetime.datetime.now)),
            ],
            options={
                'ordering': ['-date'],
            },
            bases=(models.Model,),
        ),
        migrations.CreateModel(
            name='UserSubscription',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('user_title', models.CharField(max_length=255, null=True, blank=True)),
                ('active', models.BooleanField(default=False)),
                ('last_read_date', models.DateTimeField(default=datetime.datetime(2020, 5, 6, 5, 45, 20, 134265))),
                ('mark_read_date', models.DateTimeField(default=datetime.datetime(2020, 5, 6, 5, 45, 20, 134265))),
                ('unread_count_neutral', models.IntegerField(default=0)),
                ('unread_count_positive', models.IntegerField(default=0)),
                ('unread_count_negative', models.IntegerField(default=0)),
                ('unread_count_updated', models.DateTimeField(default=datetime.datetime.now)),
                ('oldest_unread_story_date', models.DateTimeField(default=datetime.datetime.now)),
                ('needs_unread_recalc', models.BooleanField(default=False)),
                ('feed_opens', models.IntegerField(default=0)),
                ('is_trained', models.BooleanField(default=False)),
                ('feed', models.ForeignKey(related_name=b'subscribers', to='rss_feeds.Feed')),
                ('user', models.ForeignKey(related_name=b'subscriptions', to=settings.AUTH_USER_MODEL)),
            ],
            options={
            },
            bases=(models.Model,),
        ),
        migrations.CreateModel(
            name='UserSubscriptionFolders',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('folders', models.TextField(default=b'[]')),
                ('user', models.ForeignKey(to=settings.AUTH_USER_MODEL, unique=True)),
            ],
            options={
                'verbose_name': 'folder',
                'verbose_name_plural': 'folders',
            },
            bases=(models.Model,),
        ),
        migrations.AlterUniqueTogether(
            name='usersubscription',
            unique_together=set([('user', 'feed')]),
        ),
    ]
