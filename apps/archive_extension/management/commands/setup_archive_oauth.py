from django.core.management.base import BaseCommand
from oauth2_provider.models import Application


class Command(BaseCommand):
    help = "Set up OAuth application for NewsBlur Archive browser extension"

    def add_arguments(self, parser):
        parser.add_argument(
            "--extension-id",
            type=str,
            help="Chrome extension ID to add to redirect URIs",
        )

    def handle(self, *args, **options):
        client_id = "newsblur-archive-extension"
        extension_id = options.get("extension_id")

        # Build redirect URIs list
        redirect_uris = [
            # Web-based extension callback (recommended approach)
            "https://newsblur.com/oauth/extension-callback/",
            "https://localhost/oauth/extension-callback/",
            "http://localhost/oauth/extension-callback/",
            # Localhost development with various ports
            "https://localhost:9381/oauth/extension-callback/",
            "http://localhost:8938/oauth/extension-callback/",
            # Chrome identity API redirect URIs
            "https://*.chromiumapp.org/",
            # Firefox extension redirect URIs
            "https://*.extensions.allizom.org/",
            "https://*.extensions.mozilla.org/",
            # Edge extension redirect URIs
            "https://*.microsoftedge.microsoft.com/",
            # Generic extension callback (Safari, etc.)
            "https://localhost/callback",
            "http://localhost/callback",
        ]

        # Add specific extension ID if provided
        if extension_id:
            redirect_uris.append(f"chrome-extension://{extension_id}/src/popup/oauth-callback.html")
            self.stdout.write(f"Adding extension ID: {extension_id}")

        # Check if application already exists
        app, created = Application.objects.update_or_create(
            client_id=client_id,
            defaults={
                "name": "NewsBlur Archive Extension",
                "client_type": Application.CLIENT_PUBLIC,
                "authorization_grant_type": Application.GRANT_AUTHORIZATION_CODE,
                "redirect_uris": "\n".join(redirect_uris),
                "skip_authorization": True,
            },
        )

        if created:
            self.stdout.write(self.style.SUCCESS(f"Created OAuth application: {client_id}"))
        else:
            self.stdout.write(self.style.SUCCESS(f"Updated OAuth application: {client_id}"))

        self.stdout.write(f"  Client ID: {app.client_id}")
        self.stdout.write(f"  Client Type: {app.client_type}")
        self.stdout.write(f"  Grant Type: {app.authorization_grant_type}")
        self.stdout.write(f"  Redirect URIs:\n    " + "\n    ".join(app.redirect_uris.split("\n")))
