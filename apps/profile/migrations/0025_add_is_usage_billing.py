from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("profile", "0024_add_has_scoped_classifiers"),
    ]

    operations = [
        migrations.AddField(
            model_name="profile",
            name="is_usage_billing",
            field=models.BooleanField(blank=True, default=False, null=True),
        ),
    ]
