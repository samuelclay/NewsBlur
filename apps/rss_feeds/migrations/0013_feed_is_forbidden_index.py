from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("rss_feeds", "0012_feed_fs_size_bytes_bigint"),
    ]

    operations = [
        migrations.AddIndex(
            model_name="feed",
            index=models.Index(fields=["is_forbidden"], name="feeds_is_forbidden_idx"),
        ),
    ]
