# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('pdt', '0003_auto_20141117_1647'),
    ]

    operations = [
        migrations.AlterField(
            model_name='paypalpdt',
            name='address_status',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='auth_status',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='case_id',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='case_type',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='charset',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='payer_status',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='payment_cycle',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='payment_status',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='payment_type',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='pending_reason',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='period1',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='period2',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='period3',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='period_type',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='product_name',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='product_type',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='profile_status',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='protection_eligibility',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='reason_code',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='receipt_id',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='receiver_email',
            field=models.EmailField(max_length=254, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='receiver_id',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='recurring_payment_id',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='transaction_entity',
            field=models.CharField(max_length=255, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='txn_id',
            field=models.CharField(help_text=b'PayPal transaction ID.', max_length=255, verbose_name=b'Transaction ID', db_index=True, blank=True),
        ),
        migrations.AlterField(
            model_name='paypalpdt',
            name='txn_type',
            field=models.CharField(help_text=b'PayPal transaction type.', max_length=255, verbose_name=b'Transaction Type', blank=True),
        ),
    ]
