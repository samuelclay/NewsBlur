from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("team", "0005_team_last_payment_date_own_lifetime"),
    ]

    operations = [
        migrations.AddField(
            model_name="teamprogrant",
            name="own_premium_expire",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
