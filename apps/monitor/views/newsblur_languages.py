"""Account language adoption and recorded payments from the new-signup cohort."""

import datetime

from django.conf import settings
from django.db.models import CharField, Count, Func, Q, Sum, Value
from django.http import HttpResponse
from django.views import View

from apps.profile.models import PaymentHistory, Profile
from apps.statistics.models import MStatistics
from utils.languages import LANGUAGES, normalize_language

PAYMENT_PROVIDERS = (
    "stripe",
    "paypal",
    "ios-subscription",
    "ios-archive-subscription",
    "ios-pro-subscription",
    "android-subscription",
    "android-archive",
    "android-pro",
)


def cohort_start():
    return datetime.datetime.fromisoformat(settings.LANGUAGE_ANALYTICS_COHORT_START)


def language_bucket(value):
    language = normalize_language(value)
    return language if language in LANGUAGES else "unknown"


def language_metrics(now=None):
    now = now or datetime.datetime.utcnow()
    month_ago = now - datetime.timedelta(days=30)
    start = cohort_start()
    languages = (*LANGUAGES, "unknown")
    preferences = {language: {"all": 0, "active_30d": 0} for language in ("auto", *LANGUAGES)}
    usage = {language: {"all": 0, "active_30d": 0} for language in languages}
    signups = {language: {"all": 0, "active_30d": 0} for language in languages}
    payments = {language: {"since_start": 0, "last_30d": 0} for language in languages}
    refunds = {language: {"since_start": 0, "last_30d": 0} for language in languages}

    # newsblur_languages.py extracts the normalized ASCII preference without casting the whole legacy
    # JSON blob: production has escaped NULs in unrelated keys, which PostgreSQL JSON casts reject.
    choice = Func(
        "preferences",
        Value(r'"language"\s*:\s*"([A-Za-z_-]+)"'),
        function="substring",
        output_field=CharField(),
    )
    rows = (
        Profile.objects.annotate(choice=choice)
        .values("choice", "last_read_language")
        .annotate(all=Count("pk"), active_30d=Count("pk", filter=Q(last_seen_on__gte=month_ago)))
        .order_by()
    )
    for row in rows:
        choice = normalize_language(row["choice"]) or "auto"
        language = language_bucket(row["last_read_language"] if choice == "auto" else choice)
        for period in ("all", "active_30d"):
            preferences[choice][period] += row[period]
            usage[language][period] += row[period]

    rows = (
        Profile.objects.filter(user__date_joined__gte=start, user__date_joined__lte=now)
        .values("signup_language")
        .annotate(all=Count("pk"), active_30d=Count("pk", filter=Q(last_seen_on__gte=month_ago)))
        .order_by()
    )
    for row in rows:
        language = language_bucket(row["signup_language"])
        for period in ("all", "active_30d"):
            signups[language][period] += row[period]

    # newsblur_languages.py sums signed ledger rows, INCLUDING positive rows flagged refunded:
    # models.py writes a separate negative refund. Dropping the original would subtract twice.
    rows = (
        PaymentHistory.objects.filter(
            payment_provider__in=PAYMENT_PROVIDERS,
            user__date_joined__gte=start,
            user__date_joined__lte=now,
            payment_date__date__gte=start.date(),
            payment_date__lte=now,
        )
        .values("user__profile__signup_language")
        .annotate(
            since_start=Sum("payment_amount"),
            last_30d=Sum("payment_amount", filter=Q(payment_date__gte=month_ago)),
            refunds_since_start=Sum("payment_amount", filter=Q(payment_amount__lt=0)),
            refunds_last_30d=Sum(
                "payment_amount", filter=Q(payment_amount__lt=0, payment_date__gte=month_ago)
            ),
        )
        .order_by()
    )
    for row in rows:
        language = language_bucket(row["user__profile__signup_language"])
        for period in ("since_start", "last_30d"):
            payments[language][period] += row[period] or 0
            refunds[language][period] -= row["refunds_" + period] or 0

    data = []
    for name, help_text, groups, dimension in (
        (
            "newsblur_language_preferences",
            "Accounts by explicit preference; auto is device detection.",
            preferences,
            "activity",
        ),
        (
            "newsblur_language_users",
            "Accounts by explicit language or last observed automatic language.",
            usage,
            "activity",
        ),
        (
            "newsblur_language_signups",
            "Accounts created since the cohort cutoff, by immutable signup language.",
            signups,
            "activity",
        ),
        (
            "newsblur_language_payments_dollars",
            "Signed whole-dollar subscription ledger for new signups; excludes gift credits; not store payouts.",
            payments,
            "period",
        ),
        (
            "newsblur_language_refunds_dollars",
            "Negative ledger entries for new signups, reported as positive dollars.",
            refunds,
            "period",
        ),
    ):
        data.extend([f"# HELP {name} {help_text}", f"# TYPE {name} gauge"])
        for language, periods in groups.items():
            for period, value in periods.items():
                data.append(f'{name}{{language="{language}",{dimension}="{period}"}} {value}')
    data.extend(
        [
            "# HELP newsblur_language_cohort_start_seconds Signup cohort cutoff in Unix seconds.",
            "# TYPE newsblur_language_cohort_start_seconds gauge",
            f"newsblur_language_cohort_start_seconds {start.replace(tzinfo=datetime.timezone.utc).timestamp()}",
        ]
    )
    return "\n".join(data) + "\n"


class Languages(View):
    def get(self, request):
        data = MStatistics.get(
            "languages:v1:" + settings.LANGUAGE_ANALYTICS_COHORT_START,
            language_metrics,
            set_default=True,
            expiration_sec=300,
        )
        return HttpResponse(data, content_type="text/plain; version=0.0.4; charset=utf-8")
