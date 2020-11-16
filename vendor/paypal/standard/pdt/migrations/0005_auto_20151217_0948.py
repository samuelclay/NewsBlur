# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('pdt', '0004_auto_20151029_1515'),
    ]

    operations = [
        migrations.AlterField(
            model_name='paypalpdt',
            name='custom',
            field=models.CharField(max_length=256, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='transaction_subject',
            field=models.CharField(max_length=256, blank=True),
        ),
    ]
