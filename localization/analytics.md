# Language adoption and signup revenue

The **Languages & Localization Revenue** row in the existing NewsBlur Grafana dashboard uses
`/monitor/languages`. Both Prometheus configurations scrape it every five minutes. The endpoint caches
three grouped PostgreSQL queries for five minutes and emits a bounded series for every supported
language, including zeros. Account identifiers never appear in labels.

## Definitions

- **Explicit choices:** the account's `preferences.language`; missing, invalid and `auto` mean automatic.
  Explicit English is separate from automatic. Automatic can resolve to any supported device language.
- **Language use:** the explicit preference, or `Profile.last_read_language` for automatic accounts.
  This is the language on the last reader activity request, not a count of devices. Accounts without an
  observation are `unknown`. Changing an explicit preference changes this distribution immediately.
  Automatic requests without an `Accept-Language` header preserve the last observation, so scripts
  cannot replace a known device language with the English fallback.
- **Active:** `Profile.last_seen_on` within the preceding 30 days, matching the existing monthly active
  account definition. Activity is recorded on the home and feed loading/refresh endpoints, including
  native clients. Background refresh can count as activity, as it does in the existing metric.
- **New-signup cohort:** accounts created on or after **2026-10-16 23:25:40 UTC**, the requested “now”
  cutoff in `LANGUAGE_ANALYTICS_COHORT_START`. `Profile.signup_language` is captured once inside
  `SignupForm.save`, before login, for web, API and social signup flows. Native clients already send
  their resolved language through `Accept-Language`. Anonymous web language choices take precedence
  over detection. An existing account logging in through the signup form is not attributed again.
- **Unknown signup language:** accounts created between the cutoff and deployment, or through a creation
  path without request context. Historical preferences are never used to invent acquisition language.
- **Payments:** sum of signed `PaymentHistory.payment_amount` for the cohort, grouped by immutable
  signup language. Includes first payments and renewals from Stripe, PayPal, iOS and Android subscription
  providers; excludes gift redemptions, promotional credits and scheduled payments. The all-time chart
  starts at the cohort cutoff; the other chart uses the trailing 30 days. Provider histories can store
  dates at midnight, so the lower payment boundary includes the entire signup cutoff day while account
  eligibility uses the precise timestamp. Future-dated payments are excluded.
- **Refunds:** negative ledger entries reduce payments once and are also exported as positive refund
  dollars. Positive payments marked `refunded=True` remain in the sum because local refund paths also
  record a negative entry. A refund flag alone does not establish the refunded amount, particularly for
  partially refunded imported payments. Missing negative ledger entries are not reconstructed here.

These are operational subscription ledger totals, not payout accounting. The existing ledger stores
integer dollars, and mobile receipts use USD plan values rather than localized prices or store proceeds.
Fees, taxes, foreign exchange, unrecorded refunds and AI usage charges are not reconciled. Deleting an
account cascades its payment history and can reduce these totals. All metrics are gauges: do not use
`rate()` or `increase()` on them. Revenue from a language cohort does not prove localization caused the
signups; that would require a separate experiment or acquisition evidence.

## Queries and schema

`apps/monitor/views/newsblur_languages.py` aggregates preferences, activity and signup cohorts in SQL.
Preference extraction only reads the normalized ASCII language token; production contains escaped NULs
in unrelated legacy preferences which make a whole-blob PostgreSQL JSON cast fail. The production
preference aggregation took approximately 0.34 seconds over 592,906 accounts on October 16, 2026.

Migration `0033_language_analytics` adds nullable signup and reader language columns without backfilling
acquisition data. `last_read_language` is intentionally separate from email localization’s
`last_seen_language`, which records device detection for email delivery rather than reader activity.
Migration `0034_language_cohort_index` creates an index on `auth_user.date_joined` concurrently for cohort
selection. Existing `Profile.user_id` and `PaymentHistory.user_id` indexes cover the joins. Language
distribution needs all accounts, so a low-cardinality language index would not avoid that scan.

## Rollout

Apply the profile migrations before restarting application workers that load the new model fields.
The change requires the normal scoped web and Celery deployments because both load `Profile`, followed
by the Prometheus/Grafana configuration deployment. Those production actions require a separate deployment
request. No mobile release is required for this tracking.

After deployment, verify `/monitor/languages`, the Prometheus `languages` target and the dashboard row.
Allow up to ten minutes for a cached snapshot to reach Prometheus. Automatic language coverage fills in
as accounts return; signup attribution begins immediately for newly created accounts. The unknown signup
panel makes the gap between the cutoff and deployment visible.
