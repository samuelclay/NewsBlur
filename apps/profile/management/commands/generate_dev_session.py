import os
from importlib import import_module

from django.conf import settings
from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = "Generate a development session cookie for a user (DEBUG mode only)"

    SESSION_FILE = ".dev_session"

    def add_arguments(self, parser):
        parser.add_argument(
            "--username",
            type=str,
            default="samuel",
            help="Username to generate session for (default: samuel)",
        )
        parser.add_argument(
            "--force",
            action="store_true",
            help="Force regeneration even if session file exists",
        )

    def handle(self, *args, **options):
        # Check if we're in development
        if not settings.DEBUG:
            raise CommandError("This command can only be used in DEBUG mode!")

        username = options["username"]
        force = options["force"]

        # Check if session file exists and is not being forced to regenerate
        session_file_path = os.path.join(settings.BASE_DIR, self.SESSION_FILE)
        if os.path.exists(session_file_path) and not force:
            with open(session_file_path, "r") as f:
                session_key = f.read().strip()
            self.stdout.write(self.style.SUCCESS(f"Using existing session from {self.SESSION_FILE}"))
            self.stdout.write(self.style.SUCCESS(f"Session ID: {session_key}"))
            self.stdout.write(f'\nUsage: curl -H "Cookie: sessionid={session_key}" https://localhost/')
            self.stdout.write(
                f"\nTo regenerate, run: docker exec newsblur_web ./manage.py generate_dev_session --force"
            )
            return

        # Get the user
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            raise CommandError(f'User "{username}" not found')

        self.stdout.write(f"User: {user.username} (email: {user.email})")

        # Create a new session
        engine = import_module(settings.SESSION_ENGINE)
        session = engine.SessionStore()
        session.cycle_key()
        session["_auth_user_id"] = str(user.pk)
        session["_auth_user_backend"] = "django.contrib.auth.backends.ModelBackend"
        session["_auth_user_hash"] = user.get_session_auth_hash()

        session.save()

        # Save session to file
        with open(session_file_path, "w") as f:
            f.write(session.session_key)

        self.stdout.write(self.style.SUCCESS(f"\n✓ Development session created!"))
        self.stdout.write(self.style.SUCCESS(f"Session ID: {session.session_key}"))
        self.stdout.write(self.style.SUCCESS(f"Saved to: {self.SESSION_FILE}"))
        self.stdout.write(f'\nUsage: curl -H "Cookie: sessionid={session.session_key}" https://localhost/')
