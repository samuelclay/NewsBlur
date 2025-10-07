from django.contrib.auth.models import User

from apps.feed_import.models import OPMLImporter, UploadedOPML
from apps.reader.models import UserSubscription
from apps.social.models import MActivity
from newsblur_web.celeryapp import app
from utils import log as logging


@app.task()
def ProcessOPML(user_id):
    user = User.objects.get(pk=user_id)
    logging.user(user, "~FR~SBOPML upload (task) starting...")

    opml = UploadedOPML.objects.filter(user_id=user_id).first()
    opml_importer = OPMLImporter(opml.opml_file.encode("utf-8"), user)
    opml_importer.process()

    feed_count = UserSubscription.objects.filter(user=user).count()
    user.profile.send_upload_opml_finished_email(feed_count)
    logging.user(user, "~FR~SBOPML upload (task): ~SK%s~SN~SB~FR feeds" % (feed_count))

    MActivity.new_opml_import(user_id=user.pk, count=feed_count)

    UserSubscription.queue_new_feeds(user)
    UserSubscription.refresh_stale_feeds(user, exclude_new=True)


@app.task()
def ProcessOPMLExport(user_id):
    user = User.objects.get(pk=user_id)
    logging.user(user, "~FR~SBOPML export (task) starting...")

    user.profile.send_opml_export_email(reason="Your OPML export is ready.", force=True)

    logging.user(user, "~FR~SBOPML export (task) complete: sent email to %s" % user.email)
