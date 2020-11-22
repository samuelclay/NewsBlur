# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('ipn', '0004_auto_20150612_1826'),
    ]

    operations = [
        migrations.AlterField(
            model_name='paypalipn',
            name='custom',
            field=models.CharField(max_length=256, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='transaction_subject',
            field=models.CharField(max_length=256, blank=True),
        ),
    ]
