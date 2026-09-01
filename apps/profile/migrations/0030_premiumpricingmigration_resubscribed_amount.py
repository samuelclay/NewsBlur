# Adds resubscribed_amount so the resubscribe dashboard can split cancelled-then-returned
# subscribers by tier (premium/archive/pro), and backfills it for rows already recorded as
# resubscribed (apps/profile/models.py PremiumPricingMigration).

from django.db import migrations, models


def backfill_resubscribed_amount(apps, schema_editor):
    PremiumPricingMigration = apps.get_model("profile", "PremiumPricingMigration")
    PaymentHistory = apps.get_model("profile", "PaymentHistory")
    rows = PremiumPricingMigration.objects.filter(
        resubscribed_date__isnull=False, resubscribed_amount__isnull=True
    )
    for row in rows:
        payment = (
            PaymentHistory.objects.filter(
                user_id=row.user_id,
                payment_date=row.resubscribed_date,
                payment_provider=row.resubscribed_provider,
            )
            .exclude(refunded=True)
            .order_by("-payment_amount")
            .first()
        )
        if payment:
            row.resubscribed_amount = payment.payment_amount
            row.save(update_fields=["resubscribed_amount"])


class Migration(migrations.Migration):
    dependencies = [
        ("profile", "0029_premiumpricingmigration"),
    ]

    operations = [
        migrations.AddField(
            model_name="premiumpricingmigration",
            name="resubscribed_amount",
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.RunPython(backfill_resubscribed_amount, migrations.RunPython.noop),
    ]
