from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("rss_feeds", "0014_feed_branch_from_feed_protect"),
    ]

    operations = [
        # rss_feeds_feed is written by every feed fetch, so fail fast rather than queue
        # those writes behind a lock this ALTER is still waiting for.
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.AddField(
            model_name="feed",
            name="page_last_read_date",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
