# -*- coding: utf-8 -*-


from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('ipn', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='paypalipn',
            name='ipaddress',
            field=models.GenericIPAddressField(null=True, blank=True),
        ),
    ]
