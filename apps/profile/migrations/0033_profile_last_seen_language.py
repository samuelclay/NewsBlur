from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("profile", "0032_socialidentity"),
    ]

    operations = [
        # 0033 runs against the live database while the previous release serves every request through
        # profile_profile. Adding a nullable column is instant but needs a brief exclusive lock; if a long
        # query holds the table, give up after 5 seconds (the deploy stops before restarting anything)
        # rather than queue every profile query behind the ALTER.
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.AddField(
            model_name="profile",
            name="last_seen_language",
            field=models.CharField(blank=True, max_length=16, null=True),
        ),
    ]
