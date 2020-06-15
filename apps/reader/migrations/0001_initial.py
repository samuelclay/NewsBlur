# -*- coding: utf-8 -*-


from django.db import models, migrations
import datetime
import apps.reader.models
from django.conf import settings


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('rss_feeds', '0001_initial'),
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
        ),
        migrations.CreateModel(
            name='UserSubscription',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('user_title', models.CharField(max_length=255, null=True, blank=True)),
                ('active', models.BooleanField(default=False)),
                ('last_read_date', models.DateTimeField(default=apps.reader.models.unread_cutoff_default)),
                ('mark_read_date', models.DateTimeField(default=apps.reader.models.unread_cutoff_default)),
                ('unread_count_neutral', models.IntegerField(default=0)),
                ('unread_count_positive', models.IntegerField(default=0)),
                ('unread_count_negative', models.IntegerField(default=0)),
                ('unread_count_updated', models.DateTimeField(default=datetime.datetime.now)),
                ('oldest_unread_story_date', models.DateTimeField(default=datetime.datetime.now)),
                ('needs_unread_recalc', models.BooleanField(default=False)),
                ('feed_opens', models.IntegerField(default=0)),
                ('is_trained', models.BooleanField(default=False)),
                ('feed', models.ForeignKey(related_name='subscribers', to='rss_feeds.Feed')),
                ('user', models.ForeignKey(related_name='subscriptions', to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name='UserSubscriptionFolders',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('folders', models.TextField(default=b'[]')),
                ('user', models.OneToOneField(to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'folder',
                'verbose_name_plural': 'folders',
            },
        ),
        migrations.AlterUniqueTogether(
            name='usersubscription',
            unique_together=set([('user', 'feed')]),
        ),
    ]
