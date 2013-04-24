from celery.task import Task
from django.contrib.auth.models import User
from apps.feed_import.models import UploadedOPML, OPMLImporter, GoogleReaderImporter
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import MStarredStory
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


class ProcessReaderImport(Task):
    
    def run(self, user_id, auto_active=False):
        user = User.objects.get(pk=user_id)
        logging.user(user, "~FR~SBGoogle Reader import (task) starting...")

        importer = GoogleReaderImporter(user=user)
        importer.import_feeds(auto_active=auto_active)
        importer.import_starred_items(count=10)
        
        feed_count = UserSubscription.objects.filter(user=user).count()
        user.profile.send_import_reader_finished_email(feed_count)
        logging.user(user, "~FR~SBGoogle Reader import (task): ~SK%s~SN~SB~FR feeds" % (feed_count))


class ProcessReaderStarredImport(Task):
    
    def run(self, user_id):
        user = User.objects.get(pk=user_id)
        logging.user(user, "~FR~SBGoogle Reader starred stories import (task) starting...")

        importer = GoogleReaderImporter(user=user)
        importer.import_starred_items(count=1000)
        
        feed_count = UserSubscription.objects.filter(user=user).count()
        starred_count = MStarredStory.objects.filter(user_id=user.pk).count()
        user.profile.send_import_reader_starred_finished_email(feed_count, starred_count)
        logging.user(user, "~FR~SBGoogle Reader starred stories import (task): ~SK%s~SN~SB~FR feeds, ~SK%s~SN~SB~FR starred stories" % (feed_count, starred_count))

