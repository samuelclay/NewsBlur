# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('ipn', '0005_auto_20151217_0948'),
    ]

    operations = [
        migrations.AddField(
            model_name='paypalipn',
            name='option_selection1',
            field=models.CharField(max_length=200, blank=True),
        ),
        migrations.AddField(
            model_name='paypalipn',
            name='option_selection2',
            field=models.CharField(max_length=200, blank=True),
        ),
    ]
