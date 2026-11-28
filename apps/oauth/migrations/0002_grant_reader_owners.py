from django.db import migrations

# In production this granted lifetime Premium Pro to the reader partners who own OAuth applications. Those
# grants ended when oauth.0004_applicationexemption exempted the applications instead, so it does nothing now.


class Migration(migrations.Migration):
    dependencies = [
        ("oauth", "0001_initial"),
        ("profile", "0034_language_cohort_index"),
    ]
    operations = []
