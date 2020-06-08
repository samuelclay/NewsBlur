# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations
import datetime
from django.conf import settings


class Migration(migrations.Migration):

    dependencies = [
        ('reader', '0002_auto_20200607_0310'),
    ]

    operations = [
        migrations.AlterField(
            model_name='usersubscription',
            name='last_read_date',
            field=models.DateTimeField(default=datetime.datetime(2020, 5, 9, 4, 7, 2, 250571)),
        ),
        migrations.AlterField(
            model_name='usersubscription',
            name='mark_read_date',
            field=models.DateTimeField(default=datetime.datetime(2020, 5, 9, 4, 7, 2, 250571)),
        ),
        migrations.AlterField(
            model_name='usersubscriptionfolders',
            name='user',
            field=models.OneToOneField(to=settings.AUTH_USER_MODEL),
        ),
    ]
