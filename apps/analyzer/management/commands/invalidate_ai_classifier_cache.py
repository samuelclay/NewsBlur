"""
Management command to drop cached AI prompt classifier verdicts.

Hidden classifiers used to be sent to the model with no indication of their
direction, so the model read a bare topic ("sports") as the user's interests
and returned +1. apps/reader/views.py only honors -1 for a hidden classifier,
so those verdicts were discarded and nothing was ever hidden — and they sit in
Redis for up to 30 days. This clears them so the fixed classifier reclassifies.

Run this only AFTER the fix in utils/ai_functions.py is deployed to the task
servers (`make celery`). Run against the old code and the stale verdicts are
simply rewritten with the same wrong sign.
"""

from django.core.management.base import BaseCommand

from apps.analyzer.models import MClassifierPrompt


class Command(BaseCommand):
    help = "Invalidate cached AI prompt classifier scores so stories get reclassified"

    def add_arguments(self, parser):
        parser.add_argument(
            "--type",
            choices=["hidden", "focus", "all"],
            default="hidden",
            help="Which classifier types to invalidate (default: hidden, the ones affected by the sign bug)",
        )
        parser.add_argument(
            "--user-id",
            type=int,
            default=None,
            help="Limit to a single user, for verifying on one account before a wider run",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="List what would be invalidated without touching Redis",
        )

    def handle(self, *args, **options):
        query = {}
        if options["type"] != "all":
            query["classifier_type"] = options["type"]
        if options["user_id"]:
            query["user_id"] = options["user_id"]

        prompts = list(MClassifierPrompt.objects.filter(**query))
        if not prompts:
            self.stdout.write("No matching prompt classifiers found.")
            return

        users = {prompt.user_id for prompt in prompts}
        self.stdout.write(
            "%s %s prompt classifier(s) across %s user(s)"
            % (
                "Would invalidate" if options["dry_run"] else "Invalidating",
                len(prompts),
                len(users),
            )
        )

        for prompt in prompts:
            label = "user %s / feed %s / %s: %r" % (
                prompt.user_id,
                prompt.feed_id,
                prompt.classifier_type,
                prompt.prompt[:60],
            )
            if options["dry_run"]:
                self.stdout.write("  would clear %s" % label)
                continue
            MClassifierPrompt.invalidate_cache(prompt.user_id, str(prompt.id))
            self.stdout.write("  cleared %s" % label)

        if not options["dry_run"]:
            self.stdout.write(
                self.style.SUCCESS(
                    "Done. Stories reclassify on the next feed fetch, which bills each user again."
                )
            )
