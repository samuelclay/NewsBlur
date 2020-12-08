# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations
from django.conf import settings


class Migration(migrations.Migration):

    dependencies = [
        ('rss_feeds', '0001_initial'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='RecommendedFeed',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('description', models.TextField(null=True, blank=True)),
                ('is_public', models.BooleanField(default=False)),
                ('created_date', models.DateField(auto_now_add=True)),
                ('approved_date', models.DateField(null=True)),
                ('declined_date', models.DateField(null=True)),
                ('twitter', models.CharField(max_length=50, null=True, blank=True)),
                ('feed', models.ForeignKey(related_name=b'recommendations', to='rss_feeds.Feed')),
                ('user', models.ForeignKey(related_name=b'recommendations', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-approved_date', '-created_date'],
            },
            bases=(models.Model,),
        ),
        migrations.CreateModel(
            name='RecommendedFeedUserFeedback',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('score', models.IntegerField(default=0)),
                ('created_date', models.DateField(auto_now_add=True)),
                ('recommendation', models.ForeignKey(related_name=b'feedback', to='recommendations.RecommendedFeed')),
                ('user', models.ForeignKey(related_name=b'feed_feedback', to=settings.AUTH_USER_MODEL)),
            ],
            options={
            },
            bases=(models.Model,),
        ),
    ]
