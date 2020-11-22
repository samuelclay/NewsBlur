# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('pdt', '0002_paypalpdt_mp_id'),
    ]

    operations = [
        migrations.AlterField(
            model_name='paypalpdt',
            name='ipaddress',
            field=models.GenericIPAddressField(null=True, blank=True),
        ),
    ]
