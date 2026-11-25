from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError

from apps.listen.usage import ListenUsageTracker


class Command(BaseCommand):
    help = """Start an account's Listen weekly cap and daily allowances over from now.

    Records a manual reset (apps/listen/usage.py reset_usage) and leaves the usage rows as they were. The User Admin
    dialog on the web does the same thing."""

    def add_arguments(self, parser):
        parser.add_argument("username", help="Username of the account to reset")

    def handle(self, *args, **options):
        user = User.objects.filter(username=options["username"]).first()
        if not user:
            raise CommandError("No account named %s" % options["username"])
        tracker = ListenUsageTracker(user)
        before = tracker.snapshot()
        tracker.reset_usage()
        after = tracker.snapshot()
        self.stdout.write(
            "Reset %s (%s): %s seconds used this week before, %s now"
            % (user.username, after["tier"], before["seconds_used"], after["seconds_used"])
        )
