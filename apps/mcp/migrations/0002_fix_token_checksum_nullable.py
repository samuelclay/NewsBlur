from django.db import migrations


def make_token_checksum_nullable(apps, schema_editor):
    """
    The DB has a token_checksum NOT NULL column on oauth2_provider_accesstoken
    added by a newer django-oauth-toolkit migration, but the installed ORM
    version doesn't know about it. This causes INSERT failures when creating
    access tokens. Make it nullable so the ORM can create tokens without it.
    """
    cursor = schema_editor.connection.cursor()

    # Check if the column exists before altering
    cursor.execute("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'oauth2_provider_accesstoken'
        AND column_name = 'token_checksum'
    """)
    if cursor.fetchone():
        cursor.execute(
            "ALTER TABLE oauth2_provider_accesstoken ALTER COLUMN token_checksum DROP NOT NULL"
        )
        print("\n ---> Made oauth2_provider_accesstoken.token_checksum nullable")


class Migration(migrations.Migration):
    dependencies = [
        ("mcp", "0001_setup_mcp_oauth"),
    ]

    operations = [
        migrations.RunPython(make_token_checksum_nullable, migrations.RunPython.noop),
    ]
