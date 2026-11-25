from django.db import migrations

from apps.oauth.reader_grants import WINBLUR_OWNER, grant_reader_accounts


def grant_winblur_owner(apps, schema_editor):
    grant_reader_accounts(
        apps, schema_editor.connection.alias, apply=True, report=print, owners=[WINBLUR_OWNER]
    )


class Migration(migrations.Migration):
    dependencies = [("oauth", "0002_grant_reader_owners")]
    operations = [migrations.RunPython(grant_winblur_owner, migrations.RunPython.noop)]
