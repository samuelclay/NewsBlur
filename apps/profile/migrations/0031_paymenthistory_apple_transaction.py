from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("profile", "0030_premiumpricingmigration_resubscribed_amount")]

    operations = [
        migrations.AddField(
            model_name="paymenthistory",
            name="apple_original_transaction_id",
            field=models.CharField(blank=True, db_index=True, max_length=100, null=True),
        ),
        migrations.AddField(
            model_name="paymenthistory",
            name="apple_expires_date",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
