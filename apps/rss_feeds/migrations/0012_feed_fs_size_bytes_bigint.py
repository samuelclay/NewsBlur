from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("rss_feeds", "0011_auto_20250305_0552"),
    ]

    operations = [
        migrations.AlterField(
            model_name="feed",
            name="fs_size_bytes",
            field=models.BigIntegerField(blank=True, null=True),
        ),
    ]
