from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("profile", "0034_language_cohort_index"),
    ]

    operations = [
        # 0035 runs against the live database while the previous release serves every request through
        # profile_profile. Adding a nullable column is instant but needs a brief exclusive lock; if a long
        # query holds the table, give up after 5 seconds (the deploy stops before restarting anything)
        # rather than queue every profile query behind the ALTER.
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.AddField(
            model_name="profile",
            name="is_archive_extra",
            field=models.BooleanField(blank=True, default=False, null=True),
        ),
    ]
