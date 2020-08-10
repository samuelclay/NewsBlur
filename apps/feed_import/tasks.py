from celery.task import Task
from django.contrib.auth.models import User
from apps.feed_import.models import UploadedOPML, OPMLImporter
from apps.reader.models import UserSubscription
from utils import log as logging


class ProcessOPML(Task):
    
    def run(self, user_id):
        user = User.objects.get(pk=user_id)
        logging.user(user, "~FR~SBOPML upload (task) starting...")

        opml = UploadedOPML.objects.filter(user_id=user_id).first()
        opml_importer = OPMLImporter(opml.opml_file, user)
        opml_importer.process()
        
        feed_count = UserSubscription.objects.filter(user=user).count()
        user.profile.send_upload_opml_finished_email(feed_count)
        logging.user(user, "~FR~SBOPML upload (task): ~SK%s~SN~SB~FR feeds" % (feed_count))

