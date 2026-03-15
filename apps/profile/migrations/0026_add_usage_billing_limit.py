from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("profile", "0025_add_is_usage_billing"),
        ("profile", "0025_google_play_ids"),
    ]

    operations = [
        migrations.AddField(
            model_name="profile",
            name="usage_billing_limit",
            field=models.DecimalField(
                blank=True,
                decimal_places=2,
                help_text="Optional monthly spending limit in USD for AI classifiers",
                max_digits=8,
                null=True,
            ),
        ),
    ]
