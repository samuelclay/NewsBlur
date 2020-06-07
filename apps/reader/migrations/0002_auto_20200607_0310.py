# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations
import datetime


class Migration(migrations.Migration):

    dependencies = [
        ('reader', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='usersubscription',
            name='last_read_date',
            field=models.DateTimeField(default=datetime.datetime(2020, 5, 8, 3, 10, 23, 333888)),
        ),
        migrations.AlterField(
            model_name='usersubscription',
            name='mark_read_date',
            field=models.DateTimeField(default=datetime.datetime(2020, 5, 8, 3, 10, 23, 333888)),
        ),
    ]
