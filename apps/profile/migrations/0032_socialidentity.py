import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("profile", "0031_paymenthistory_apple_transaction")]
    operations = [
        migrations.CreateModel(
            name="SocialIdentity",
            fields=[
                (
                    "id",
                    models.AutoField(primary_key=True, serialize=False, auto_created=True, verbose_name="ID"),
                ),
                ("provider", models.CharField(max_length=16)),
                ("subject", models.CharField(max_length=255)),
                ("email", models.EmailField(max_length=254)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="social_identities",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"unique_together": {("provider", "subject")}},
        )
    ]
