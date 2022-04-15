import datetime
import pickle
import base64
from utils import log as logging
from oauth2client.client import OAuth2WebServerFlow, FlowExchangeError
from bson.errors import InvalidStringData
import uuid
from django.contrib.sites.models import Site
from django.contrib.auth.models import User
# from django.db import IntegrityError
from django.http import HttpResponse, HttpResponseRedirect
from django.conf import settings
from django.urls import reverse
from django.contrib.auth import login as login_user
from mongoengine.errors import ValidationError
from apps.reader.forms import SignupForm
from apps.reader.models import UserSubscription
from apps.feed_import.models import OAuthToken
from apps.feed_import.models import OPMLImporter, OPMLExporter, UploadedOPML
from apps.feed_import.tasks import ProcessOPML
from utils import json_functions as json
from utils.user_functions import ajax_login_required, get_user
from utils.feed_functions import TimeoutError


@ajax_login_required
def opml_upload(request):
    xml_opml = None
    message = "OK"
    code = 1
    payload = {}
    
    if request.method == 'POST':
        if 'file' in request.FILES:
            logging.user(request, "~FR~SBOPML upload starting...")
            file = request.FILES['file']
            xml_opml = file.read()
            try:
                UploadedOPML.objects.create(user_id=request.user.pk, opml_file=xml_opml)
            except (UnicodeDecodeError, ValidationError, InvalidStringData):
                folders = None
                code = -1
                message = "There was a Unicode decode error when reading your OPML file. Ensure it's a text file with a .opml or .xml extension. Is it a zip file?"
            
            opml_importer = OPMLImporter(xml_opml, request.user)
            try:
                folders = opml_importer.try_processing()
            except TimeoutError:
                folders = None
                ProcessOPML.delay(request.user.pk)
                feed_count = opml_importer.count_feeds_in_opml()
                logging.user(request, "~FR~SBOPML upload took too long, found %s feeds. Tasking..." % feed_count)
                payload = dict(folders=folders, delayed=True, feed_count=feed_count)
                code = 2
                message = ""
            except AttributeError:
                code = -1
                message = "OPML import failed. Couldn't parse XML file."
                folders = None

            if folders:
                code = 1
                feeds = UserSubscription.objects.filter(user=request.user).values()
                payload = dict(folders=folders, feeds=feeds)
                logging.user(request, "~FR~SBOPML Upload: ~SK%s~SN~SB~FR feeds" % (len(feeds)))
                from apps.social.models import MActivity
                MActivity.new_opml_import(user_id=request.user.pk, count=len(feeds))
                UserSubscription.queue_new_feeds(request.user)
                UserSubscription.refresh_stale_feeds(request.user, exclude_new=True)
        else:
            message = "Attach an .opml file."
            code = -1
            
    return HttpResponse(json.encode(dict(message=message, code=code, payload=payload)),
                        content_type='text/html')

def opml_export(request):
    user     = get_user(request)
    now      = datetime.datetime.now()
    if request.GET.get('user_id') and user.is_staff:
        user = User.objects.get(pk=request.GET['user_id'])
    exporter = OPMLExporter(user)
    opml     = exporter.process()

    from apps.social.models import MActivity
    MActivity.new_opml_export(user_id=user.pk, count=exporter.feed_count)

    response = HttpResponse(opml, content_type='text/xml; charset=utf-8')
    response['Content-Disposition'] = 'attachment; filename=NewsBlur-%s-%s.opml' % (
        user.username,
        now.strftime('%Y-%m-%d')
    )
    
    return response

