from django.db import connections, migrations


def _get_table_columns(cursor, table_name):
    """Return the set of column names for a table."""
    cursor.execute(
        "SELECT column_name FROM information_schema.columns WHERE table_name = %s",
        [table_name],
    )
    return {row[0] for row in cursor.fetchall()}


def setup_cli_oauth(apps, schema_editor):
    """
    Create/update OAuth app for the NewsBlur CLI.
    Public client (no secret) with localhost redirect for the local callback flow.
    """
    client_id = "newsblur-cli"

    cursor = connections["default"].cursor()
    columns = _get_table_columns(cursor, "oauth2_provider_application")
    has_hash = "hash_client_secret" in columns
    has_origins = "allowed_origins" in columns

    cursor.execute(
        "SELECT id FROM oauth2_provider_application WHERE client_id = %s",
        [client_id],
    )
    row = cursor.fetchone()

    if row:
        set_clauses = [
            "name = %s",
            "client_type = %s",
            "authorization_grant_type = %s",
            "client_secret = %s",
            "redirect_uris = %s",
            "skip_authorization = %s",
        ]
        params = [
            "NewsBlur CLI",
            "public",
            "authorization-code",
            "",
            "http://localhost",
            True,
        ]
        if has_hash:
            set_clauses.append("hash_client_secret = %s")
            params.append(False)
        if has_origins:
            set_clauses.append("allowed_origins = %s")
            params.append("")
        params.append(client_id)

        cursor.execute(
            f"UPDATE oauth2_provider_application SET {', '.join(set_clauses)} WHERE client_id = %s",
            params,
        )
        print(f"\n ---> Updated OAuth application: {client_id}")
    else:
        col_names = [
            "client_id", "name", "client_type", "authorization_grant_type",
            "client_secret", "redirect_uris", "skip_authorization",
            "created", "updated", "algorithm", "post_logout_redirect_uris",
        ]
        params = [
            client_id, "NewsBlur CLI", "public", "authorization-code",
            "", "http://localhost", True,
        ]
        placeholders = ["%s"] * len(params) + ["NOW()", "NOW()", "%s", "%s"]
        extra_params = ["", ""]  # algorithm, post_logout_redirect_uris

        if has_hash:
            col_names.append("hash_client_secret")
            placeholders.append("%s")
            extra_params.append(False)
        if has_origins:
            col_names.append("allowed_origins")
            placeholders.append("%s")
            extra_params.append("")

        cursor.execute(
            f"""INSERT INTO oauth2_provider_application ({', '.join(col_names)})
                VALUES ({', '.join(placeholders)})""",
            params + extra_params,
        )
        print(f"\n ---> Created OAuth application: {client_id}")


class Migration(migrations.Migration):
    dependencies = [
        ("mcp", "0002_fix_token_checksum_nullable"),
    ]

    operations = [
        migrations.RunPython(setup_cli_oauth, migrations.RunPython.noop),
    ]
