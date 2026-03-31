from django.conf import settings
from django.db import connections, migrations


def _get_table_columns(cursor, table_name):
    """Return the set of column names for a table."""
    cursor.execute(
        "SELECT column_name FROM information_schema.columns WHERE table_name = %s",
        [table_name],
    )
    return {row[0] for row in cursor.fetchall()}


def setup_mcp_oauth(apps, schema_editor):
    """
    Create/update OAuth app for the NewsBlur MCP server.
    The MCP server uses this as its upstream OAuth application
    to proxy authentication for AI agent clients.

    Dynamically detects available columns to work across
    different versions of django-oauth-toolkit.
    """
    from django.contrib.auth.hashers import make_password

    client_id = "newsblur-mcp-server"
    client_secret = getattr(settings, "MCP_OAUTH_CLIENT_SECRET", "newsblur-mcp-dev-secret")
    newsblur_url = getattr(settings, "NEWSBLUR_URL", "https://localhost")

    redirect_uris = [
        # Production callback (HAProxy routes /mcp/* to MCP server)
        "https://newsblur.com/mcp/auth/callback",
        "https://www.newsblur.com/mcp/auth/callback",
        # Localhost development (various worktree ports)
        f"{newsblur_url}/mcp/auth/callback",
        "https://localhost/mcp/auth/callback",
        "http://localhost/mcp/auth/callback",
        "http://localhost:8099/auth/callback",
    ]
    # Add common worktree port range (HAProxy HTTPS and HTTP)
    for port in range(9100, 9500):
        redirect_uris.append(f"https://localhost:{port}/mcp/auth/callback")
        redirect_uris.append(f"http://localhost:{port}/mcp/auth/callback")

    seen = set()
    unique_uris = [u for u in redirect_uris if not (u in seen or seen.add(u))]
    redirect_uris_str = "\n".join(unique_uris)

    hashed_secret = make_password(client_secret)

    cursor = connections["default"].cursor()
    columns = _get_table_columns(cursor, "oauth2_provider_application")
    has_hash = "hash_client_secret" in columns
    has_origins = "allowed_origins" in columns

    # Check if it already exists
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
            "NewsBlur MCP Server",
            "confidential",
            "authorization-code",
            hashed_secret,
            redirect_uris_str,
            True,
        ]
        if has_hash:
            set_clauses.append("hash_client_secret = %s")
            params.append(True)
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
            client_id, "NewsBlur MCP Server", "confidential", "authorization-code",
            hashed_secret, redirect_uris_str, True,
        ]
        placeholders = ["%s"] * len(params) + ["NOW()", "NOW()", "%s", "%s"]
        extra_params = ["", ""]  # algorithm, post_logout_redirect_uris

        if has_hash:
            col_names.append("hash_client_secret")
            placeholders.append("%s")
            extra_params.append(True)
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

    print(f"      Domain: {newsblur_url}")
    print(f"      Secret: {client_secret}")


class Migration(migrations.Migration):
    dependencies = [
        ("oauth2_provider", "0007_application_post_logout_redirect_uris"),
    ]

    operations = [
        migrations.RunPython(setup_mcp_oauth, migrations.RunPython.noop),
    ]
