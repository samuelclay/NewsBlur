from django.db import connections, migrations


def fix_cli_redirect_uri(apps, schema_editor):
    """
    Fix the newsblur-cli OAuth app redirect URI.
    Migration 0003 was originally deployed with 'http://localhost' but the CLI
    uses http://127.0.0.1:<port>/callback. Update to the correct value.
    """
    cursor = connections["default"].cursor()
    cursor.execute(
        "UPDATE oauth2_provider_application SET redirect_uris = %s WHERE client_id = %s",
        ["http://127.0.0.1/callback", "newsblur-cli"],
    )
    if cursor.rowcount:
        print(f"\n ---> Fixed newsblur-cli redirect_uris to http://127.0.0.1/callback")


class Migration(migrations.Migration):
    dependencies = [
        ("mcp", "0003_setup_cli_oauth"),
    ]

    operations = [
        migrations.RunPython(fix_cli_redirect_uri, migrations.RunPython.noop),
    ]
