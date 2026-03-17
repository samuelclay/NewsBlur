from django.conf import settings
from django.db import connections, migrations


def setup_mcp_oauth(apps, schema_editor):
    """
    Create/update OAuth app for the NewsBlur MCP server.
    The MCP server uses this as its upstream OAuth application
    to proxy authentication for AI agent clients.

    Uses raw SQL because the DB schema has columns (hash_client_secret,
    allowed_origins) not present in the Django ORM model.
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

    # Check if it already exists
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
                "NewsBlur MCP Server",
                "confidential",
                "authorization-code",
                hashed_secret,
                True,
                redirect_uris_str,
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
                "NewsBlur MCP Server",
                "confidential",
                "authorization-code",
                hashed_secret,
                True,
                redirect_uris_str,
                True,
                "",  # algorithm
                "",  # post_logout_redirect_uris
                "",  # allowed_origins
            ],
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
