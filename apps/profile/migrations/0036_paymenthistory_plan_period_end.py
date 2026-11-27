from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("profile", "0035_profile_is_archive_extra"),
    ]

    operations = [
        # 0036 adds two nullable columns to profile_paymenthistory, which every payment sync writes. If a long query
        # holds the table, give up after 5 seconds (the deploy stops before restarting anything) rather than queue
        # payment writes behind the ALTER.
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.AddField(
            model_name="paymenthistory",
            name="plan",
            field=models.CharField(blank=True, max_length=32, null=True),
        ),
        migrations.AddField(
            model_name="paymenthistory",
            name="period_end",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
