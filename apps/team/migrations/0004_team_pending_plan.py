from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("team", "0003_team_billing"),
    ]

    operations = [
        migrations.AddField(
            model_name="team",
            name="pending_plan",
            field=models.CharField(blank=True, max_length=32, null=True),
        ),
    ]
