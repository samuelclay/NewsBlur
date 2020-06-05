# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations
import datetime
from django.conf import settings


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='OAuthToken',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('session_id', models.CharField(max_length=50, null=True, blank=True)),
                ('uuid', models.CharField(max_length=50, null=True, blank=True)),
                ('remote_ip', models.CharField(max_length=50, null=True, blank=True)),
                ('request_token', models.CharField(max_length=50)),
                ('request_token_secret', models.CharField(max_length=50)),
                ('access_token', models.CharField(max_length=50)),
                ('access_token_secret', models.CharField(max_length=50)),
                ('credential', models.TextField(null=True, blank=True)),
                ('created_date', models.DateTimeField(default=datetime.datetime.now)),
                ('user', models.OneToOneField(null=True, blank=True, to=settings.AUTH_USER_MODEL)),
            ],
            options={
            },
            bases=(models.Model,),
        ),
    ]
