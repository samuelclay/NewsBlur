# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('ipn', '0003_auto_20141117_1647'),
    ]

    operations = [
        migrations.AlterField(
            model_name='paypalipn',
            name='address_status',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='auth_status',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='case_id',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='case_type',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='charset',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='payer_status',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='payment_cycle',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='payment_status',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='payment_type',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='pending_reason',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='period1',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='period2',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='period3',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='period_type',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='product_name',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='product_type',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='profile_status',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='protection_eligibility',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='reason_code',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='receipt_id',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='receiver_email',
            field=models.EmailField(max_length=254, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='receiver_id',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='recurring_payment_id',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='transaction_entity',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='txn_id',
            field=models.CharField(help_text=b'PayPal transaction ID.', max_length=255, verbose_name=b'Transaction ID', db_index=True, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalipn',
            name='txn_type',
            field=models.CharField(help_text=b'PayPal transaction type.', max_length=255, verbose_name=b'Transaction Type', blank=True),
        ),
    ]
