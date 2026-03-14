import datetime

from django.core.management.base import BaseCommand

from apps.profile.models import MPremiumTrial, MSentEmail, Profile


class Command(BaseCommand):
    help = "Backfill MPremiumTrial collection from MSentEmail records and active trials."

    def handle(self, *args, **options):
        count = 0

        # 1. Users currently on trial: derive start from premium_expire - 30 days
        active_trials = Profile.objects.filter(
            is_premium=True, is_premium_trial=True, premium_expire__isnull=False
        )
        for profile in active_trials:
            end_date = profile.premium_expire
            start_date = end_date - datetime.timedelta(days=30)
            MPremiumTrial.record(user_id=profile.user_id, start_date=start_date, end_date=end_date)
            count += 1
            print(f"  Active trial: user {profile.user_id} ({start_date.date()} - {end_date.date()})")

        # 2. Past trials from MSentEmail welcome records
        trial_emails = MSentEmail.objects.filter(email_type="premium_trial_welcome")
        for email in trial_emails:
            if MPremiumTrial.objects.filter(user_id=email.receiver_user_id).first():
                continue
            start_date = email.date_sent
            end_date = start_date + datetime.timedelta(days=30)
            MPremiumTrial.record(user_id=email.receiver_user_id, start_date=start_date, end_date=end_date)
            count += 1
            print(f"  Past trial: user {email.receiver_user_id} ({start_date.date()} - {end_date.date()})")

        print(f"\nBackfilled {count} premium trial records.")
