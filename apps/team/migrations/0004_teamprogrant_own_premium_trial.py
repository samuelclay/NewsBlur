from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("team", "0003_teammember_departure"),
    ]

    operations = [
        migrations.AddField(
            model_name="teamprogrant",
            name="own_premium_trial",
            field=models.BooleanField(blank=True, null=True),
        ),
    ]
