from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("profile", "0036_paymenthistory_plan_period_end"),
    ]

    operations = [
        # 0037 adds a nullable column to profile_paymenthistory, which every payment sync writes. If a long query holds
        # the table, give up after 5 seconds (the deploy stops before restarting anything) rather than queue payment
        # writes behind the ALTER.
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.AddField(
            model_name="paymenthistory",
            name="sandbox",
            field=models.BooleanField(blank=True, null=True),
        ),
    ]
