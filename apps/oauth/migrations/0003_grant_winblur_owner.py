from django.db import migrations

# In production this granted lifetime Premium Pro to the owner of the Winblur OAuth application. That grant
# ended when oauth.0004_applicationexemption exempted the application instead, so it does nothing now.


class Migration(migrations.Migration):
    dependencies = [("oauth", "0002_grant_reader_owners")]
    operations = []
