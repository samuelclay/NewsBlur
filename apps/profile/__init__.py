"""User profiles, premium subscription management, and account preferences.

Manages subscription tiers (Free, Premium, Archive, Pro) with Stripe and PayPal
billing, per-user preferences, timezone settings, and feed count limits.
"""

default_app_config = "apps.profile.apps.ProfileConfig"
