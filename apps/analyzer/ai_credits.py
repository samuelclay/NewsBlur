"""Monthly AI credits for natural language text and image filters.

ai_credits.py: A credit is one US cent of what AI filters cost NewsBlur to run: Jev's charge
for every request (apps/analyzer/jev.py) and the one-time rewrite of each filter. Every plan
includes credits each month, in the reader's own calendar month. Once they're used, filters
pause until the 1st, unless the reader turned on usage billing. Usage billing charges what's
past the included credits at cost, 1 cent per credit, to the card the reader saved on Stripe
(apps/profile/views.py setup_usage_billing), and pauses filters at the reader's monthly limit
if they set one.

Spending is counted in Redis in millionths of a dollar, as LLMCostTracker.record_usage
(utils/llm_costs.py) records each request. Whole credits past the included ones add up as
unbilled credits, kept by the month they were used in. Once a month is over
(ChargeMonthlyAICreditOverage in apps/profile/tasks.py) a Stripe invoice charges the past
months' credits, if they come to at least $1 (MINIMUM_CHARGE_CREDITS); a smaller amount waits
for a later month. Unbilled credits that reach $10 (IMMEDIATE_CHARGE_CREDITS) are charged right
away, so a runaway filter can't build up a large bill before the month ends.
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

# ai_credits.py: A charge is never under $1. Smaller amounts wait, across months if they have to.
MINIMUM_CHARGE_CREDITS = 100

# ai_credits.py: Unbilled credits are charged as soon as they reach $10, instead of at the end
# of the month.
IMMEDIATE_CHARGE_CREDITS = 1000

# ai_credits.py: Marks the Stripe invoices usage billing creates, for the account dialog's list
# of charges and the payment webhooks (apps/profile/models.py).
INVOICE_PURPOSE = "ai_credits"

KEY_PREFIX = "AICR"
MONTH_KEY_TTL = 100 * 24 * 60 * 60
DAY_KEY_TTL = (PACE_DAYS + 2) * 24 * 60 * 60
UNBILLED_KEY_TTL = 400 * 24 * 60 * 60

# ai_credits.py: In one step, so two workers finishing requests at the same moment can't both
# count the same credit: raises this month's count of overage credits (KEYS[1]) to the number
# due, adds the new ones to the month's field (ARGV[4]) in the reader's unbilled credits hash
# (KEYS[2]), and returns all of the reader's unbilled credits.
_COUNT_OVERAGE_CREDITS = """
local due = tonumber(ARGV[1])
local counted = tonumber(redis.call('GET', KEYS[1]) or '0')
if due > counted then
    redis.call('SET', KEYS[1], due, 'EX', tonumber(ARGV[2]))
    redis.call('HINCRBY', KEYS[2], ARGV[4], due - counted)
    redis.call('EXPIRE', KEYS[2], tonumber(ARGV[3]))
end
local total = 0
for _, credits in ipairs(redis.call('HVALS', KEYS[2])) do
    total = total + tonumber(credits)
end
return total
"""

# ai_credits.py: Takes the reader's unbilled credits (KEYS[1]) from every month before ARGV[2],
# or from every month when ARGV[2] is empty, if they add up to at least ARGV[1]. In one step,
# so two charges running at once can't both take them. Returns month, credits, month, credits...
_TAKE_UNBILLED_CREDITS = """
local fields = redis.call('HGETALL', KEYS[1])
local taken = {}
local total = 0
for i = 1, #fields, 2 do
    if ARGV[2] == '' or fields[i] < ARGV[2] then
        table.insert(taken, fields[i])
        table.insert(taken, fields[i + 1])
        total = total + tonumber(fields[i + 1])
    end
end
if total == 0 or total < tonumber(ARGV[1]) then
    return {}
end
for i = 1, #taken, 2 do
    redis.call('HDEL', KEYS[1], taken[i])
end
return taken
"""


def _redis():
    return redis.Redis(connection_pool=settings.REDIS_POOL)


def is_unlimited():
    """True on a server without Stripe usage billing, like a self-hosted NewsBlur, whose owner
    pays for Jev directly. Credits there are never counted against anyone.

    ai_credits.py: A server that still only has the per-classification prices from before
    credits counts them too, so a deploy that lands before AI_CREDITS_USAGE_BILLING is set
    can't leave filters running without a limit.
    """
    return not (
        getattr(settings, "AI_CREDITS_USAGE_BILLING", False)
        or getattr(settings, "STRIPE_PRICE_TEXT_CLASSIFICATION", "")
    )


def is_billing_available():
    """Whether readers can turn on usage billing for credits past their plan's."""
    return bool(getattr(settings, "AI_CREDITS_USAGE_BILLING", False))


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
    """Whether credits past the plan's are charged to the card the reader saved on Stripe."""
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


def _charge_number_key(user_id):
    return "%s:%s:charges" % (KEY_PREFIX, user_id)


def unbilled_credits(profile):
    """Credits past the plan's that haven't been charged yet, from every month."""
    return sum(int(credits) for credits in _redis().hvals(_unbilled_key(profile.user_id)))


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
    pipe = _redis().pipeline()
    pipe.incrby(_month_key(user_id, month), cost_micro)
    pipe.expire(_month_key(user_id, month), MONTH_KEY_TTL)
    pipe.incrby(_day_key(user_id, local_now.date()), cost_micro)
    pipe.expire(_day_key(user_id, local_now.date()), DAY_KEY_TTL)
    used_micro = pipe.execute()[0]
    previous_micro = used_micro - cost_micro

    if billing:
        _count_overage(profile, month, used_micro, included_micro)

    # The request that pauses filters is the only one whose spending crosses the line, since
    # INCRBY hands each request its own total, so the reader is emailed once.
    reason = _pause_reason(profile, used_micro)
    if reason in ("credits", "limit") and _pause_reason(profile, previous_micro) is None:
        from apps.profile.tasks import EmailAICreditsPaused

        EmailAICreditsPaused.delay(user_id, reason)


def _count_overage(profile, month, used_micro, included_micro):
    """Add the whole credits past the included ones to the reader's unbilled credits, and charge
    them right away once they reach IMMEDIATE_CHARGE_CREDITS."""
    over_micro = used_micro - included_micro
    limit_micro = _limit_microdollars(profile)
    if limit_micro is not None:
        over_micro = min(over_micro, limit_micro)
    due = over_micro // MICRODOLLARS_PER_CREDIT
    if due <= 0:
        return
    unbilled = int(
        _redis().eval(
            _COUNT_OVERAGE_CREDITS,
            2,
            _overage_key(profile.user_id, month),
            _unbilled_key(profile.user_id),
            due,
            MONTH_KEY_TTL,
            UNBILLED_KEY_TTL,
            month,
        )
    )
    if unbilled >= IMMEDIATE_CHARGE_CREDITS:
        from apps.profile.tasks import ChargeAICreditOverage

        ChargeAICreditOverage.delay(profile.user_id, IMMEDIATE_CHARGE_CREDITS)


def charge_unbilled(profile, minimum_credits=MINIMUM_CHARGE_CREDITS, before_month=None):
    """Charge the reader's unbilled credits to their saved card with a Stripe invoice, if there
    are at least minimum_credits. Only months before before_month ("YYYY-MM") are charged when
    it's given. Returns the credits charged.

    ai_credits.py: The invoice is created so that Stripe won't collect it on its own, and only
    finalized for collection once its line is on it. If a request fails partway, the invoice is
    deleted or voided before the credits go back to be charged again, so an invoice that did get
    through can't charge the same credits twice. A declined card leaves the open invoice to
    Stripe's retries and turns usage billing off, so filters pause once the plan's credits are
    used instead of running up more.
    """
    import stripe

    if not profile.stripe_id:
        return 0
    r = _redis()
    unbilled_key = _unbilled_key(profile.user_id)
    taken = r.eval(_TAKE_UNBILLED_CREDITS, 1, unbilled_key, minimum_credits, before_month or "")
    taken = {_text(month): int(credits) for month, credits in zip(taken[::2], taken[1::2])}
    credits = sum(taken.values())
    if not credits:
        return 0

    def give_back():
        pipe = r.pipeline()
        for month, month_credits in taken.items():
            pipe.hincrby(unbilled_key, month, month_credits)
        pipe.expire(unbilled_key, UNBILLED_KEY_TTL)
        pipe.execute()

    charge_number = r.incr(_charge_number_key(profile.user_id))
    # The same charge can't be made twice, even when a request to Stripe is retried.
    idempotency_key = "ai-credits-%s-%s" % (profile.user_id, charge_number)
    description = "NewsBlur AI credits past your plan: %s credits at 1 cent" % credits
    metadata = {"purpose": INVOICE_PURPOSE, "newsblur_user_id": profile.user_id, "credits": credits}
    stripe.api_key = settings.STRIPE_SECRET
    invoice_id = None
    try:
        invoice = stripe.Invoice.create(
            customer=profile.stripe_id,
            collection_method="charge_automatically",
            auto_advance=False,
            pending_invoice_items_behavior="exclude",
            description=description,
            metadata=metadata,
            idempotency_key=idempotency_key + "-invoice",
        )
        invoice_id = invoice.id
        stripe.InvoiceItem.create(
            customer=profile.stripe_id,
            invoice=invoice_id,
            amount=int(round(credits * CREDIT_USD * 100)),
            currency="usd",
            description=description,
            metadata=metadata,
            idempotency_key=idempotency_key + "-item",
        )
        stripe.Invoice.finalize_invoice(invoice_id, auto_advance=True)
    except stripe.error.StripeError as e:
        if invoice_id is None or _cancel_invoice(invoice_id):
            give_back()
            logging.error("~BR~FWCouldn't invoice %s AI credits, they'll be charged later: %s" % (credits, e))
        else:
            logging.error("~BR~FWCouldn't finish invoice %s for %s AI credits: %s" % (invoice_id, credits, e))
        return 0
    try:
        stripe.Invoice.pay(invoice_id)
    except stripe.error.StripeError as e:
        # The invoice stays open for Stripe to retry, so the credits are owed, not returned.
        profile.is_usage_billing = False
        profile.save()
        # Stripe's invoice.payment_failed webhook tells staff (apps/profile/models.py).
        logging.user(
            profile.user, "~BR~FWAI credit charge of %s credits failed, usage billing off: %s" % (credits, e)
        )
        return 0
    logging.user(profile.user, "~BC~SB~FBCharged %s AI credits past the plan" % credits)
    return credits


def _cancel_invoice(invoice_id):
    """Make sure an AI credits invoice a failed request left behind can never collect. Returns
    whether that's certain: a draft is deleted and an open invoice voided, but a paid one, or
    one Stripe can't be asked about, has to be left alone."""
    import stripe

    try:
        invoice = stripe.Invoice.retrieve(invoice_id)
        if invoice.status == "draft":
            stripe.Invoice.delete(invoice_id)
            return True
        if invoice.status == "open":
            stripe.Invoice.void_invoice(invoice_id)
            return True
        return invoice.status == "void"
    except stripe.error.StripeError as e:
        logging.error("~BR~FWCouldn't check AI credits invoice %s: %s" % (invoice_id, e))
        return False


def _text(value):
    return value.decode() if isinstance(value, bytes) else value


def charge_last_month(profile, local_now=None):
    """Charge the unbilled credits from months that are over, if they come to at least $1.

    ai_credits.py: ChargeMonthlyAICreditOverage runs this daily for every reader with usage
    billing. The month that's still going is never charged here, however early in it the job
    runs, so a reader is charged once a month is over; a day the job misses or Stripe fails is
    made up the next day.
    """
    local_now = local_now or _now_local(profile)
    return charge_unbilled(profile, MINIMUM_CHARGE_CREDITS, before_month=_month(local_now))


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
        used_micro = int(_redis().get(_month_key(profile.user_id, month)) or 0)
        unbilled = unbilled_credits(profile)
    included_micro = included * MICRODOLLARS_PER_CREDIT
    over_micro = max(0, used_micro - included_micro) if billing else 0
    limit_micro = _limit_microdollars(profile) if billing else None
    if limit_micro is not None:
        over_micro = min(over_micro, limit_micro)
    reason = _pause_reason(profile, used_micro)
    # Near the end of the included credits, or, with usage billing, which the reader turned on
    # to go past them, near the end of their monthly limit.
    if billing:
        is_warning = bool(limit_micro) and over_micro >= limit_micro * WARNING_FRACTION
    else:
        is_warning = bool(included_micro) and used_micro >= included_micro * WARNING_FRACTION

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
        # Overage waiting to be charged: once its month is over if it's at least
        # minimum_charge_usd, or right away once it reaches immediate_charge_usd.
        "unbilled_usd": round(unbilled * CREDIT_USD, 2) if billing else 0.0,
        "minimum_charge_usd": round(MINIMUM_CHARGE_CREDITS * CREDIT_USD, 2),
        "immediate_charge_usd": round(IMMEDIATE_CHARGE_CREDITS * CREDIT_USD, 2),
        "is_paused": reason is not None,
        "pause_reason": reason,
        "is_warning": is_warning,
        "credit_usd": CREDIT_USD,
        "forecast": forecast,
    }
