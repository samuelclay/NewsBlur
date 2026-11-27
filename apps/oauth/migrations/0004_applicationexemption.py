import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models

from apps.oauth.access import exempt_existing_applications


def exempt_applications(apps, schema_editor):
    exempt_existing_applications(apps, schema_editor.connection.alias)


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.OAUTH2_PROVIDER_APPLICATION_MODEL),
        ("oauth", "0003_grant_winblur_owner"),
    ]

    operations = [
        migrations.CreateModel(
            name="ApplicationExemption",
            fields=[
                (
                    "id",
                    models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID"),
                ),
                ("created", models.DateTimeField(auto_now_add=True)),
                (
                    "application",
                    models.OneToOneField(
                        on_delete=django.db.models.deletion.CASCADE,
                        to=settings.OAUTH2_PROVIDER_APPLICATION_MODEL,
                    ),
                ),
            ],
        ),
        migrations.RunPython(exempt_applications, migrations.RunPython.noop),
    ]
