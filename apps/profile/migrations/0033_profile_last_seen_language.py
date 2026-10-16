from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("profile", "0032_socialidentity"),
    ]

    operations = [
        migrations.AddField(
            model_name="profile",
            name="last_seen_language",
            field=models.CharField(blank=True, max_length=16, null=True),
        ),
    ]
