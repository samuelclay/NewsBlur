from django.db import migrations


class Migration(migrations.Migration):
    atomic = False
    dependencies = [("profile", "0033_language_analytics")]

    # 0034_language_cohort_index.py indexes Django's auth table without changing its owned model state.
    # PaymentHistory.user_id and Profile.user_id already index the other sides of the cohort joins.
    operations = [
        migrations.RunSQL(
            "CREATE INDEX CONCURRENTLY newsblur_user_date_joined_idx ON auth_user (date_joined)",
            "DROP INDEX CONCURRENTLY newsblur_user_date_joined_idx",
        ),
    ]
