from django.db import connections, migrations


def setup_cli_oauth(apps, schema_editor):
    """
    Create/update OAuth app for the NewsBlur CLI.
    Public client (no secret) with localhost redirect for the local callback flow.
    """
    client_id = "newsblur-cli"

    cursor = connections["default"].cursor()

    cursor.execute(
        "SELECT id FROM oauth2_provider_application WHERE client_id = %s",
        [client_id],
    )
    row = cursor.fetchone()

    if row:
        cursor.execute(
            """UPDATE oauth2_provider_application
               SET name = %s,
                   client_type = %s,
                   authorization_grant_type = %s,
                   client_secret = %s,
                   hash_client_secret = %s,
                   redirect_uris = %s,
                   skip_authorization = %s,
                   allowed_origins = %s
             WHERE client_id = %s""",
            [
                "NewsBlur CLI",
                "public",
                "authorization-code",
                "",
                False,
                "http://localhost",
                True,
                "",
                client_id,
            ],
        )
        print(f"\n ---> Updated OAuth application: {client_id}")
    else:
        cursor.execute(
            """INSERT INTO oauth2_provider_application
               (client_id, name, client_type, authorization_grant_type,
                client_secret, hash_client_secret, redirect_uris,
                skip_authorization, created, updated, algorithm,
                post_logout_redirect_uris, allowed_origins)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NOW(), NOW(), %s, %s, %s)""",
            [
                client_id,
                "NewsBlur CLI",
                "public",
                "authorization-code",
                "",
                False,
                "http://localhost",
                True,
                "",  # algorithm
                "",  # post_logout_redirect_uris
                "",  # allowed_origins
            ],
        )
        print(f"\n ---> Created OAuth application: {client_id}")


class Migration(migrations.Migration):
    dependencies = [
        ("mcp", "0002_fix_token_checksum_nullable"),
    ]

    operations = [
        migrations.RunPython(setup_cli_oauth, migrations.RunPython.noop),
    ]
