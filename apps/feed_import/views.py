import base64
import datetime
import pickle
import uuid

from bson.errors import InvalidStringData
from django.conf import settings
from django.contrib.auth import login as login_user
from django.contrib.auth.models import User
from django.contrib.sites.models import Site

# from django.db import IntegrityError
from django.http import HttpResponse, HttpResponseRedirect
from django.urls import reverse
from mongoengine.errors import ValidationError
from oauth2client.client import FlowExchangeError, OAuth2WebServerFlow

from apps.feed_import.models import OAuthToken, OPMLExporter, OPMLImporter, UploadedOPML
from apps.feed_import.tasks import ProcessOPML, ProcessOPMLExport
from apps.reader.forms import SignupForm
from apps.reader.models import UserSubscription
from utils import json_functions as json
from utils import log as logging
from utils.feed_functions import TimeoutError, timelimit
from utils.user_functions import ajax_login_required, get_user


@ajax_login_required
def opml_upload(request):
    xml_opml = None
    message = "OK"
    code = 1
    payload = {}

    if request.method == "POST":
        if "file" in request.FILES:
            logging.user(request, "~FR~SBOPML upload starting...")
            file = request.FILES["file"]
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
                logging.user(
                    request, "~FR~SBOPML upload took too long, found %s feeds. Tasking..." % feed_count
                )
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

    return HttpResponse(
        json.encode(dict(message=message, code=code, payload=payload)), content_type="text/html"
    )


def opml_export(request):
    user = get_user(request)
    now = datetime.datetime.now()
    if request.GET.get("user_id") and user.is_staff:
        user = User.objects.get(pk=request.GET["user_id"])

    # Try to export OPML with a 15 second timeout (0.01s in dev for testing)
    timeout_seconds = 0.01 if settings.DEBUG else 15

    @timelimit(timeout_seconds)
    def try_opml_export():
        exporter = OPMLExporter(user)
        opml = exporter.process()
        return exporter, opml

    try:
        exporter, opml = try_opml_export()

        from apps.social.models import MActivity

        MActivity.new_opml_export(user_id=user.pk, count=exporter.feed_count)

        response = HttpResponse(opml, content_type="text/xml; charset=utf-8")
        response["Content-Disposition"] = "attachment; filename=NewsBlur-%s-%s.opml" % (
            user.username,
            now.strftime("%Y-%m-%d"),
        )
        return response

    except TimeoutError:
        # If export takes too long, queue task to email user
        ProcessOPMLExport.delay(user.pk)
        logging.user(user, "~FR~SBOPML export took too long, emailing...")

        # Check if this is an AJAX request
        if request.headers.get("X-Requested-With") == "XMLHttpRequest":
            return HttpResponse(
                json.encode(
                    {
                        "code": 2,
                        "message": "Your OPML export is being processed. You will receive an email shortly with your subscription backup.",
                    }
                ),
                content_type="application/json",
            )
        else:
            # Return HTML page for non-AJAX requests
            from django.shortcuts import render

            return render(
                request,
                "reader/opml_export_delayed.xhtml",
                {
                    "user": user,
                },
            )
