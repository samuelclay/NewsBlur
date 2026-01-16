from django.conf import settings
from django.db import migrations


def setup_archive_oauth(apps, schema_editor):
    """
    Create/update OAuth app for NewsBlur Archive browser extension.
    Runs automatically during 'make' or 'python manage.py migrate'.
    """
    from oauth2_provider.models import Application

    client_id = "newsblur-archive-extension"
    newsblur_url = getattr(settings, "NEWSBLUR_URL", "https://localhost")

    redirect_uris = [
        # Custom domain callback (from settings)
        f"{newsblur_url}/oauth/extension-callback/",
        # Production NewsBlur callback (for compatibility)
        "https://newsblur.com/oauth/extension-callback/",
        "https://www.newsblur.com/oauth/extension-callback/",
        # Localhost development
        "https://localhost/oauth/extension-callback/",
        "http://localhost/oauth/extension-callback/",
        "https://localhost:9381/oauth/extension-callback/",
        "http://localhost:8938/oauth/extension-callback/",
        # Browser extension schemes
        "https://*.chromiumapp.org/",
        "https://*.extensions.allizom.org/",
        "https://*.extensions.mozilla.org/",
        "https://*.microsoftedge.microsoft.com/",
        "https://localhost/callback",
        "http://localhost/callback",
    ]

    # Remove duplicates while preserving order
    seen = set()
    unique_uris = [u for u in redirect_uris if not (u in seen or seen.add(u))]

    app, created = Application.objects.update_or_create(
        client_id=client_id,
        defaults={
            "name": "NewsBlur Archive Extension",
            "client_type": Application.CLIENT_PUBLIC,
            "authorization_grant_type": Application.GRANT_AUTHORIZATION_CODE,
            "redirect_uris": "\n".join(unique_uris),
            "skip_authorization": True,
        },
    )

    action = "Created" if created else "Updated"
    print(f"\n ---> {action} OAuth application: {client_id}")
    print(f"      Domain: {newsblur_url}")


class Migration(migrations.Migration):
    dependencies = [
        ("oauth2_provider", "0007_application_post_logout_redirect_uris"),
    ]

    operations = [
        migrations.RunPython(setup_archive_oauth, migrations.RunPython.noop),
    ]
