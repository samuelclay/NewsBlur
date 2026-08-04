import datetime

from django.core.management.base import BaseCommand

from apps.profile.models import PaymentHistory, Profile


class Command(BaseCommand):
    help = (
        "Recompute premium_expire for accounts inflated by the old 365-days-per-payment "
        "calculation, which gave monthly Premium Pro subscribers a full year of premium "
        "for every $29 charge."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "-u",
            "--username",
            type=str,
            default=None,
            help="Only fix a specific user by username",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            default=False,
            help="Report what would change without saving",
        )
        parser.add_argument(
            "-y",
            "--years",
            type=float,
            default=2.0,
            help="Only consider accounts expiring more than this many years out (default: 2)",
        )
        parser.add_argument(
            "--floor-days",
            type=int,
            default=30,
            help=(
                "Never shorten an account to fewer than this many days from now, so a "
                "paid-up subscriber keeps a grace window to notice and react (default: 30)"
            ),
        )

    def handle(self, *args, **options):
        username = options["username"]
        dry_run = options["dry_run"]
        years = options["years"]
        floor_days = options["floor_days"]

        now = datetime.datetime.now()
        floor = now + datetime.timedelta(days=floor_days)

        profiles = Profile.objects.filter(premium_expire__isnull=False)
        if username:
            profiles = profiles.filter(user__username=username)
        else:
            profiles = profiles.filter(premium_expire__gt=now + datetime.timedelta(days=365 * years))
        profiles = profiles.select_related("user").order_by("-premium_expire")

        shortened = 0
        floored = 0
        skipped = 0

        for profile in profiles:
            payments = PaymentHistory.objects.filter(user_id=profile.user_id)
            expiration, free_lifetime_premium, recent_count = Profile.premium_expire_from_payments(payments)

            # A $0 gift is a deliberate lifetime grant, not a billing artifact. Leave it be.
            if free_lifetime_premium:
                skipped += 1
                self.stdout.write(
                    " ---> %-25s SKIP (free lifetime premium) expire=%s"
                    % (profile.user.username, profile.premium_expire.date())
                )
                continue

            # No recent payments means there is nothing to recompute from. These are
            # long-lapsed accounts whose inflated date came from payments that have since
            # aged out of the trailing year, so shortening them would be a guess.
            if not expiration:
                skipped += 1
                self.stdout.write(
                    " ---> %-25s SKIP (no payments in the last year) expire=%s"
                    % (profile.user.username, profile.premium_expire.date())
                )
                continue

            if expiration >= profile.premium_expire:
                skipped += 1
                continue

            corrected = expiration
            if corrected < floor:
                corrected = floor
                floored += 1

            self.stdout.write(
                " ---> %-25s %s -> %s (%s payments in the last year)%s"
                % (
                    profile.user.username,
                    profile.premium_expire.date(),
                    corrected.date(),
                    recent_count,
                    " [floored]" if corrected == floor else "",
                )
            )

            if not dry_run:
                profile.premium_expire = corrected
                profile.save()
            shortened += 1

        self.stdout.write("")
        self.stdout.write(
            " ---> %s %s corrected, %s floored to a %s-day grace window, %s left alone"
            % (
                "Would correct" if dry_run else "Corrected",
                shortened,
                floored,
                floor_days,
                skipped,
            )
        )
        if dry_run:
            self.stdout.write(" ---> Dry run, nothing saved. Re-run without --dry-run to apply.")
