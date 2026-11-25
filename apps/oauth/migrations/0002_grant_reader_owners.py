from django.db import migrations

from apps.oauth.reader_grants import grant_reader_accounts


def grant_lifetime_pro(apps, schema_editor):
    grant_reader_accounts(apps, schema_editor.connection.alias, apply=True, report=print)


class Migration(migrations.Migration):
    dependencies = [
        ("oauth", "0001_initial"),
        ("profile", "0034_language_cohort_index"),
    ]
    operations = [migrations.RunPython(grant_lifetime_pro, migrations.RunPython.noop)]
