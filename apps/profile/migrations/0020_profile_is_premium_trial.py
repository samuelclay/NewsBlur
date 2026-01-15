from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("profile", "0019_auto_20251203_2046"),
    ]

    operations = [
        migrations.AddField(
            model_name="profile",
            name="is_premium_trial",
            field=models.BooleanField(blank=True, default=None, null=True),
        ),
    ]
