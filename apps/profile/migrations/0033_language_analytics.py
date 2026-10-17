from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("profile", "0033_profile_last_seen_language")]

    operations = [
        migrations.RunSQL("SET LOCAL lock_timeout = '5s'", migrations.RunSQL.noop),
        migrations.AddField(
            model_name="profile",
            name="signup_language",
            field=models.CharField(max_length=16, null=True, blank=True),
        ),
        migrations.AddField(
            model_name="profile",
            name="last_read_language",
            field=models.CharField(max_length=16, null=True, blank=True),
        ),
    ]
