"""Monthly AI credits for natural language text and image filters.

ai_credits.py: A credit is one US cent of what AI filters cost NewsBlur to run: Jev's charge
for every request (apps/analyzer/jev.py) and the one-time rewrite of each filter. Every plan
includes credits each month, in the reader's own calendar month. Once they're used, filters
pause until the 1st, unless the reader turned on usage billing. Usage billing bills what's
past the included credits at cost, 1 cent per credit, to a metered Stripe subscription
(apps/profile/views.py setup_usage_billing), and pauses filters at the reader's monthly limit
if they set one.

Spending is counted in Redis in millionths of a dollar, as LLMCostTracker.record_usage
(utils/llm_costs.py) records each request. Whole credits past the included ones add up as
they're used and go to Stripe's meter a dollar at a time (MINIMUM_CHARGE_CREDITS). Stripe
charges what the meter holds at the end of the subscription's month, so no charge is under
$1, and what's under a dollar waits for later months until it reaches one. Overage that
reaches $10 within a month is charged right away (BILLING_THRESHOLD_CENTS), so a runaway
filter can't build up a large bill before the month ends.
"""

import calendar
import datetime
import math

import redis
from django.conf import settings

from utils import log as logging
from vendor.timezones.utilities import localtime_for_timezone

# ai_credits.py: Credits included each month. Premium Pro is checked first since it
# sets is_archive and is_premium too, then Premium Archive, then Premium.
MONTHLY_CREDITS_PRO = 500
MONTHLY_CREDITS_ARCHIVE = 50
MONTHLY_CREDITS_PREMIUM = 5

CREDIT_USD = 0.01
MICRODOLLARS_PER_CREDIT = 10_000

# ai_credits.py: The features LLMCostTracker records for AI filters. Ask AI, briefings and
# the rest are part of their plans and never spend credits.
CREDIT_FEATURES = ("story_classification", "vision_classification", "classifier_description")

# ai_credits.py: What one story costs a filter, from Jev's charges on real readers' filters:
# about 700 stories per credit through text filters and 100 through image filters, which
# read up to three images (apps/analyzer/jev.py MAX_IMAGES_PER_STORY). The trainer
# multiplies these by how many stories a site published last month to estimate a filter.
TEXT_STORY_CREDITS = 0.0014
IMAGE_STORY_CREDITS = 0.01

# ai_credits.py: The reader sees a notice once this much of the month's credits is used.
WARNING_FRACTION = 0.8

# ai_credits.py: The forecast projects the pace of the last week onto the rest of the month,
# so a filter added mid-month predicts from the days it has run, not from the whole month.
PACE_DAYS = 7

# ai_credits.py: The Stripe meter every overage credit is reported to. The metered price
# STRIPE_PRICE_AI_CREDITS bills 1 cent for each one
# (apps/profile/management/commands/create_ai_credit_price.py creates both).
METER_EVENT_NAME = "nb_ai_credits"

# ai_credits.py: Overage credits are reported to Stripe only once this many have built up,
# so every charge is at least $1. The rest waits, across months if it has to.
MINIMUM_CHARGE_CREDITS = 100

# ai_credits.py: The Stripe billing threshold on every usage billing subscription: once this
# much overage builds up within a month, Stripe charges it immediately instead of at the
# end of the month (apps/profile/models.py stripe_checkout_session_completed sets it).
BILLING_THRESHOLD_CENTS = 1000

KEY_PREFIX = "AICR"
MONTH_KEY_TTL = 100 * 24 * 60 * 60
DAY_KEY_TTL = (PACE_DAYS + 2) * 24 * 60 * 60
UNBILLED_KEY_TTL = 400 * 24 * 60 * 60

# ai_credits.py: In one step, so two workers finishing requests at the same moment can't
# both bill the same credit: raises this month's count of overage credits (KEYS[1]) to the
# number due, adds the new ones to the reader's unbilled credits (KEYS[2]), and takes out
# and returns the whole dollars of unbilled credits that are ready to report.
_RESERVE_OVERAGE_CREDITS = """
local due = tonumber(ARGV[1])
local counted = tonumber(redis.call('GET', KEYS[1]) or '0')
if due > counted then
    redis.call('SET', KEYS[1], due, 'EX', tonumber(ARGV[2]))
    redis.call('INCRBY', KEYS[2], due - counted)
    redis.call('EXPIRE', KEYS[2], tonumber(ARGV[3]))
end
local unbilled = tonumber(redis.call('GET', KEYS[2]) or '0')
local chunk = tonumber(ARGV[4])
local ready = math.floor(unbilled / chunk) * chunk
if ready > 0 then
    redis.call('DECRBY', KEYS[2], ready)
end
return ready
"""


def _redis():
    return redis.Redis(connection_pool=settings.REDIS_POOL)


def is_unlimited():
    """True on a server without Stripe usage billing, like a self-hosted NewsBlur, whose owner
    pays for Jev directly. Credits there are never counted against anyone.

    ai_credits.py: A server that still only has the per-classification prices from before
    credits counts them too, so a deploy that lands before STRIPE_PRICE_AI_CREDITS can't
    leave filters running without a limit.
    """
    return not (
        getattr(settings, "STRIPE_PRICE_AI_CREDITS", "")
        or getattr(settings, "STRIPE_PRICE_TEXT_CLASSIFICATION", "")
    )


def is_billing_available():
    """Whether readers can turn on usage billing for credits past their plan's."""
    return bool(getattr(settings, "STRIPE_PRICE_AI_CREDITS", ""))


def monthly_credits(profile):
    """The credits this reader's plan includes each month."""
    if profile.is_pro:
        return MONTHLY_CREDITS_PRO
    if profile.is_archive:
        return MONTHLY_CREDITS_ARCHIVE
    if profile.is_premium:
        return MONTHLY_CREDITS_PREMIUM
    return 0


def has_usage_billing(profile):
    """Whether overage is billed to this reader's metered Stripe subscription."""
    return bool(profile.is_usage_billing and profile.stripe_id and is_billing_available())


def _now_local(profile):
    return localtime_for_timezone(datetime.datetime.now(), profile.timezone)


def _month(local_now):
    return local_now.strftime("%Y-%m")


def _month_key(user_id, month):
    return "%s:%s:%s" % (KEY_PREFIX, user_id, month)


def _day_key(user_id, day):
    return "%s:%s:d:%s" % (KEY_PREFIX, user_id, day.isoformat())


def _overage_key(user_id, month):
    return "%s:%s:%s:overage" % (KEY_PREFIX, user_id, month)


def _unbilled_key(user_id):
    return "%s:%s:unbilled" % (KEY_PREFIX, user_id)


def _emailed_key(user_id, month, reason):
    return "%s:%s:%s:emailed:%s" % (KEY_PREFIX, user_id, month, reason)


def _limit_microdollars(profile):
    if not profile.usage_billing_limit:
        return None
    return int(round(float(profile.usage_billing_limit) * 1_000_000))


def _pause_reason(profile, used_micro):
    """Why filters aren't running this month, or None while they are."""
    if is_unlimited():
        return None
    included_micro = monthly_credits(profile) * MICRODOLLARS_PER_CREDIT
    if used_micro < included_micro:
        return None
    if not has_usage_billing(profile):
        return "plan" if not included_micro else "credits"
    limit_micro = _limit_microdollars(profile)
    if limit_micro is not None and used_micro - included_micro >= limit_micro:
        return "limit"
    return None


def can_run(profile):
    """Whether this reader's AI filters score stories right now."""
    if is_unlimited():
        return True
    if not monthly_credits(profile) and not has_usage_billing(profile):
        return False
    used_micro = int(_redis().get(_month_key(profile.user_id, _month(_now_local(profile)))) or 0)
    return _pause_reason(profile, used_micro) is None


def spend(user_id, feature, cost_usd):
    """Charge one AI filter request to the reader's credits for this month.

    ai_credits.py: Called by LLMCostTracker.record_usage (utils/llm_costs.py) for every request.
    Reports any whole credits past the included ones to Stripe, and emails the reader once a
    month when their filters pause.
    """
    if feature not in CREDIT_FEATURES or not user_id or is_unlimited():
        return
    from apps.profile.models import Profile

    try:
        profile = Profile.objects.get(user_id=user_id)
    except Profile.DoesNotExist:
        return
    included_micro = monthly_credits(profile) * MICRODOLLARS_PER_CREDIT
    billing = has_usage_billing(profile)
    if not included_micro and not billing:
        # Free accounts test filters on NewsBlur's dime (apps/analyzer/views.py).
        return

    cost_micro = max(1, int(round(cost_usd * 1_000_000)))
    local_now = _now_local(profile)
    month = _month(local_now)
    r = _redis()
    pipe = r.pipeline()
    pipe.incrby(_month_key(user_id, month), cost_micro)
    pipe.expire(_month_key(user_id, month), MONTH_KEY_TTL)
    pipe.incrby(_day_key(user_id, local_now.date()), cost_micro)
    pipe.expire(_day_key(user_id, local_now.date()), DAY_KEY_TTL)
    used_micro = pipe.execute()[0]
    previous_micro = used_micro - cost_micro

    if billing:
        _report_overage(profile, month, used_micro, included_micro)

    reason = _pause_reason(profile, used_micro)
    if reason in ("credits", "limit") and _pause_reason(profile, previous_micro) is None:
        if r.set(_emailed_key(user_id, month, reason), 1, nx=True, ex=MONTH_KEY_TTL):
            from apps.profile.tasks import EmailAICreditsPaused

            EmailAICreditsPaused.delay(user_id, reason)


def _report_overage(profile, month, used_micro, included_micro):
    """Count the whole credits past the included ones, and report them to Stripe once they add
    up to MINIMUM_CHARGE_CREDITS."""
    import stripe

    over_micro = used_micro - included_micro
    limit_micro = _limit_microdollars(profile)
    if limit_micro is not None:
        over_micro = min(over_micro, limit_micro)
    due = over_micro // MICRODOLLARS_PER_CREDIT
    if due <= 0:
        return
    r = _redis()
    unbilled_key = _unbilled_key(profile.user_id)
    ready = int(
        r.eval(
            _RESERVE_OVERAGE_CREDITS,
            2,
            _overage_key(profile.user_id, month),
            unbilled_key,
            due,
            MONTH_KEY_TTL,
            UNBILLED_KEY_TTL,
            MINIMUM_CHARGE_CREDITS,
        )
    )
    if not ready:
        return
    stripe.api_key = settings.STRIPE_SECRET
    try:
        stripe.billing.MeterEvent.create(
            event_name=METER_EVENT_NAME,
            # The same credits can't be billed twice, even if this report is retried.
            identifier="%s:%s:%s" % (profile.user_id, month, due),
            payload={"stripe_customer_id": profile.stripe_id, "value": str(ready)},
        )
    except stripe.error.StripeError as e:
        # Hand the credits back, so the next request reports them again.
        r.incrby(unbilled_key, ready)
        logging.error("~BR~FWCouldn't report %s AI credits to Stripe: %s" % (ready, e))


def _pace_microdollars_per_day(profile, local_now):
    """The reader's spending per day over the last PACE_DAYS days, counted from their first
    day of spending in that window, so a filter added yesterday isn't averaged over a week."""
    days = [local_now.date() - datetime.timedelta(days=n) for n in range(PACE_DAYS)]
    values = _redis().mget([_day_key(profile.user_id, day) for day in days])
    spent = [int(v or 0) for v in values]
    if not any(spent):
        return 0
    first_index = max(i for i, micro in enumerate(spent) if micro)
    start_of_first_day = local_now.replace(hour=0, minute=0, second=0, microsecond=0) - datetime.timedelta(
        days=first_index
    )
    elapsed_days = max(1.0, (local_now - start_of_first_day).total_seconds() / 86400)
    return sum(spent) / elapsed_days


def estimate_monthly_credits(stories_per_month, include_images):
    """About how many credits a filter on a site with this many stories a month spends."""
    per_story = IMAGE_STORY_CREDITS if include_images else TEXT_STORY_CREDITS
    return round(stories_per_month * per_story, 2)


def _credits(microdollars):
    return round(microdollars / MICRODOLLARS_PER_CREDIT, 2)


def state(profile):
    """Everything the web, iOS and Android show about a reader's credits this month.

    ai_credits.py: Sent with the profile (apps/profile/models.py canonical) and by
    /analyzer/ai_classifier_usage and /profile/usage_billing_history.
    """
    local_now = _now_local(profile)
    month = _month(local_now)
    last_day = calendar.monthrange(local_now.year, local_now.month)[1]
    month_start = local_now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    next_month = month_start + datetime.timedelta(days=last_day)
    included = monthly_credits(profile)
    unlimited = is_unlimited()
    billing = has_usage_billing(profile)
    used_micro, unbilled = 0, 0
    if not unlimited:
        values = _redis().mget([_month_key(profile.user_id, month), _unbilled_key(profile.user_id)])
        used_micro, unbilled = int(values[0] or 0), int(values[1] or 0)
    included_micro = included * MICRODOLLARS_PER_CREDIT
    over_micro = max(0, used_micro - included_micro) if billing else 0
    limit_micro = _limit_microdollars(profile) if billing else None
    if limit_micro is not None:
        over_micro = min(over_micro, limit_micro)
    reason = _pause_reason(profile, used_micro)
    # Near the end of the included credits, or of the monthly limit on usage billing.
    is_warning = bool(included_micro) and used_micro >= included_micro * WARNING_FRACTION
    if limit_micro and over_micro >= limit_micro * WARNING_FRACTION:
        is_warning = True

    forecast = None
    pace = 0 if unlimited else _pace_microdollars_per_day(profile, local_now)
    if pace:
        days_left = max(0.0, (next_month - local_now).total_seconds() / 86400)
        projected_micro = used_micro + pace * days_left
        runs_out_on = None
        if used_micro < included_micro and projected_micro > included_micro:
            runs_out = local_now + datetime.timedelta(days=(included_micro - used_micro) / pace)
            runs_out_on = runs_out.date().isoformat()
        projected_over_micro = max(0, projected_micro - included_micro)
        forecast = {
            "credits": _credits(projected_micro),
            "credits_per_day": _credits(pace),
            "runs_out_on": runs_out_on,
            # What the month would cost with usage billing, before any limit.
            "overage_usd": round(math.ceil(projected_over_micro / MICRODOLLARS_PER_CREDIT) * CREDIT_USD, 2),
        }

    return {
        "included": included,
        "used": _credits(used_micro),
        "remaining": _credits(max(0, included_micro - used_micro)),
        "month": month,
        "resets_on": next_month.date().isoformat(),
        "is_unlimited": unlimited,
        "is_billing_available": is_billing_available(),
        "is_usage_billing": billing,
        "monthly_limit": float(profile.usage_billing_limit) if profile.usage_billing_limit else None,
        "overage_credits": over_micro // MICRODOLLARS_PER_CREDIT,
        "overage_usd": round((over_micro // MICRODOLLARS_PER_CREDIT) * CREDIT_USD, 2),
        # Overage that waits to be charged until it reaches the $1 minimum charge.
        "unbilled_usd": round(unbilled * CREDIT_USD, 2) if billing else 0.0,
        "minimum_charge_usd": round(MINIMUM_CHARGE_CREDITS * CREDIT_USD, 2),
        "is_paused": reason is not None,
        "pause_reason": reason,
        "is_warning": is_warning,
        "credit_usd": CREDIT_USD,
        "forecast": forecast,
    }
