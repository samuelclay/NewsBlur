# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations
import utils.fields


class Migration(migrations.Migration):

    dependencies = [
    ]

    operations = [
        migrations.CreateModel(
            name='DuplicateFeed',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('duplicate_address', models.CharField(max_length=764, db_index=True)),
                ('duplicate_link', models.CharField(max_length=764, null=True, db_index=True)),
                ('duplicate_feed_id', models.CharField(max_length=255, null=True, db_index=True)),
            ],
            options={
            },
            bases=(models.Model,),
        ),
        migrations.CreateModel(
            name='Feed',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('feed_address', models.URLField(max_length=764, db_index=True)),
                ('feed_address_locked', models.NullBooleanField(default=False)),
                ('feed_link', models.URLField(default=b'', max_length=1000, null=True, blank=True)),
                ('feed_link_locked', models.BooleanField(default=False)),
                ('hash_address_and_link', models.CharField(unique=True, max_length=64)),
                ('feed_title', models.CharField(default=b'[Untitled]', max_length=255, null=True, blank=True)),
                ('is_push', models.NullBooleanField(default=False)),
                ('active', models.BooleanField(default=True, db_index=True)),
                ('num_subscribers', models.IntegerField(default=-1)),
                ('active_subscribers', models.IntegerField(default=-1, db_index=True)),
                ('premium_subscribers', models.IntegerField(default=-1)),
                ('active_premium_subscribers', models.IntegerField(default=-1)),
                ('last_update', models.DateTimeField(db_index=True)),
                ('next_scheduled_update', models.DateTimeField()),
                ('last_story_date', models.DateTimeField(null=True, blank=True)),
                ('fetched_once', models.BooleanField(default=False)),
                ('known_good', models.BooleanField(default=False)),
                ('has_feed_exception', models.BooleanField(default=False, db_index=True)),
                ('has_page_exception', models.BooleanField(default=False, db_index=True)),
                ('has_page', models.BooleanField(default=True)),
                ('exception_code', models.IntegerField(default=0)),
                ('errors_since_good', models.IntegerField(default=0)),
                ('min_to_decay', models.IntegerField(default=0)),
                ('days_to_trim', models.IntegerField(default=90)),
                ('creation', models.DateField(auto_now_add=True)),
                ('etag', models.CharField(max_length=255, null=True, blank=True)),
                ('last_modified', models.DateTimeField(null=True, blank=True)),
                ('stories_last_month', models.IntegerField(default=0)),
                ('average_stories_per_month', models.IntegerField(default=0)),
                ('last_load_time', models.IntegerField(default=0)),
                ('favicon_color', models.CharField(max_length=6, null=True, blank=True)),
                ('favicon_not_found', models.BooleanField(default=False)),
                ('s3_page', models.NullBooleanField(default=False)),
                ('s3_icon', models.NullBooleanField(default=False)),
                ('search_indexed', models.NullBooleanField(default=None)),
                ('branch_from_feed', models.ForeignKey(blank=True, to='rss_feeds.Feed', null=True)),
            ],
            options={
                'ordering': ['feed_title'],
                'db_table': 'feeds',
            },
            bases=(models.Model,),
        ),
        migrations.CreateModel(
            name='FeedData',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('feed_tagline', models.CharField(max_length=1024, null=True, blank=True)),
                ('story_count_history', models.TextField(null=True, blank=True)),
                ('feed_classifier_counts', models.TextField(null=True, blank=True)),
                ('popular_tags', models.CharField(max_length=1024, null=True, blank=True)),
                ('popular_authors', models.CharField(max_length=2048, null=True, blank=True)),
                ('feed', utils.fields.AutoOneToOneField(related_name=b'data', to='rss_feeds.Feed')),
            ],
            options={
            },
            bases=(models.Model,),
        ),
        migrations.AddField(
            model_name='duplicatefeed',
            name='feed',
            field=models.ForeignKey(related_name=b'duplicate_addresses', to='rss_feeds.Feed'),
            preserve_default=True,
        ),
    ]
