"""Feed import tasks: process OPML imports and exports for bulk subscription management."""

from django.contrib.auth.models import User
from django.db import connection

from apps.feed_import.models import OPMLImporter, UploadedOPML
from apps.reader.models import UserSubscription
from apps.social.models import MActivity
from newsblur_web.celeryapp import app
from utils import log as logging

OPML_IMPORT_LOCK_NAMESPACE = 0x4F504D4C
OPML_IMPORT_LOCK_RETRY_SECONDS = 30


def _acquire_opml_import_lock(user_id):
    """Hold one PostgreSQL session-level import lock per user (apps/feed_import/tasks.py)."""
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT pg_try_advisory_lock(%s, %s)",
            [OPML_IMPORT_LOCK_NAMESPACE, user_id],
        )
        return cursor.fetchone()[0]


def _release_opml_import_lock(user_id):
    """Release the per-user import lock acquired by this database session (apps/feed_import/tasks.py)."""
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT pg_advisory_unlock(%s, %s)",
            [OPML_IMPORT_LOCK_NAMESPACE, user_id],
        )


def _uploaded_opml_for_task(user_id, uploaded_opml_id=None):
    if uploaded_opml_id:
        return UploadedOPML.objects.get(pk=uploaded_opml_id, user_id=user_id)

    # Compatibility for tasks queued before uploaded_opml_id was added. Explicitly
    # order here as well as in UploadedOPML.meta so a legacy task uses the latest file.
    return UploadedOPML.objects.filter(user_id=user_id).order_by("-upload_date").first()


def _process_uploaded_opml(user, uploaded_opml):
    logging.user(user, "~FR~SBOPML upload (task) starting...")

    opml_importer = OPMLImporter(uploaded_opml.opml_file.encode("utf-8"), user)
    opml_importer.process()

    feed_count = UserSubscription.objects.filter(user=user).count()
    user.profile.send_upload_opml_finished_email(feed_count)
    logging.user(user, "~FR~SBOPML upload (task): ~SK%s~SN~SB~FR feeds" % (feed_count))

    MActivity.new_opml_import(user_id=user.pk, count=feed_count)

    UserSubscription.queue_new_feeds(user)
    UserSubscription.refresh_stale_feeds(user, exclude_new=True)


@app.task(bind=True, max_retries=None)
def ProcessOPML(self, user_id, uploaded_opml_id=None):
    if not _acquire_opml_import_lock(user_id):
        logging.debug(" ---> OPML import already running for user %s; retrying" % user_id)
        raise self.retry(countdown=OPML_IMPORT_LOCK_RETRY_SECONDS)

    try:
        user = User.objects.get(pk=user_id)
        uploaded_opml = _uploaded_opml_for_task(user_id, uploaded_opml_id)
        if not uploaded_opml:
            logging.error(" ---> OPML import has no uploaded document for user %s" % user_id)
            return
        _process_uploaded_opml(user, uploaded_opml)
    finally:
        _release_opml_import_lock(user_id)


@app.task()
def ProcessOPMLExport(user_id):
    user = User.objects.get(pk=user_id)
    logging.user(user, "~FR~SBOPML export (task) starting...")

    user.profile.send_opml_export_email(reason="Your OPML export is ready.", force=True)

    logging.user(user, "~FR~SBOPML export (task) complete: sent email to %s" % user.email)
