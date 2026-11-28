from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("team", "0004_team_pending_plan"),
    ]

    operations = [
        migrations.AddField(
            model_name="team",
            name="last_payment_date",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="teamprogrant",
            name="own_lifetime",
            field=models.BooleanField(blank=True, null=True),
        ),
    ]
