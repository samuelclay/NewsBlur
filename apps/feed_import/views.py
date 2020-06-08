import datetime
import pickle
import base64
import httplib2
from utils import log as logging
from oauth2client.client import OAuth2WebServerFlow, FlowExchangeError
from bson.errors import InvalidStringData
import uuid
from django.contrib.sites.models import Site
from django.contrib.auth.models import User
# from django.db import IntegrityError
from django.http import HttpResponse, HttpResponseRedirect
from django.conf import settings
from django.core.urlresolvers import reverse
from django.template import RequestContext
from django.contrib.auth import login as login_user
from django.shortcuts import render_to_response
from apps.reader.forms import SignupForm
from apps.reader.models import UserSubscription
from apps.feed_import.models import OAuthToken, GoogleReaderImporter
from apps.feed_import.models import OPMLImporter, OPMLExporter, UploadedOPML
from apps.feed_import.tasks import ProcessOPML, ProcessReaderImport, ProcessReaderStarredImport
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
            xml_opml = str(file.read().decode('utf-8', 'ignore'))
            try:
                UploadedOPML.objects.create(user_id=request.user.pk, opml_file=xml_opml)
            except (UnicodeDecodeError, InvalidStringData):
                folders = None
                code = -1
                message = "There was a Unicode decode error when reading your OPML file."
            
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
            
            request.session['import_from_google_reader'] = False
        else:
            message = "Attach an .opml file."
            code = -1
            
    return HttpResponse(json.encode(dict(message=message, code=code, payload=payload)),
                        mimetype='text/html')

def opml_export(request):
    user     = get_user(request)
    now      = datetime.datetime.now()
    if request.GET.get('user_id') and user.is_staff:
        user = User.objects.get(pk=request.GET['user_id'])
    exporter = OPMLExporter(user)
    opml     = exporter.process()
    
    response = HttpResponse(opml, mimetype='text/xml')
    response['Content-Disposition'] = 'attachment; filename=NewsBlur-%s-%s' % (
        user.username,
        now.strftime('%Y-%m-%d')
    )
    
    return response

def import_signup(request):
    ip = request.META.get('HTTP_X_FORWARDED_FOR', None) or request.META.get('REMOTE_ADDR', "")
    
    if request.method == "POST":
        signup_form = SignupForm(prefix='signup', data=request.POST)
        if signup_form.is_valid():
            new_user = signup_form.save()
            
            user_token = OAuthToken.objects.filter(user=new_user)
            if not user_token:
                user_uuid = request.COOKIES.get('newsblur_reader_uuid')
                if user_uuid:
                    user_token = OAuthToken.objects.filter(uuid=user_uuid).order_by('-created_date')
            if not user_token:
                if request.session.session_key:
                    user_token = OAuthToken.objects.filter(session_id=request.session.session_key).order_by('-created_date')
            if not user_token:
                user_token = OAuthToken.objects.filter(remote_ip=ip).order_by('-created_date')

            if user_token:
                user_token = user_token[0]
                user_token.session_id = request.session.session_key
                user_token.user = new_user
                user_token.save()
                login_user(request, new_user)
                if request.user.profile.is_premium:
                    return HttpResponseRedirect(reverse('index'))
                url = "https://%s%s" % (Site.objects.get_current().domain,
                                         reverse('stripe-form'))
                return HttpResponseRedirect(url)
            else:
                logging.user(request, "~BR~FW ***> Can't find user token during import/signup. Re-authenticating...")
                return HttpResponseRedirect(reverse('google-reader-authorize'))
    else:
        signup_form = SignupForm(prefix='signup')

    return render_to_response('import/signup.xhtml', {
        'signup_form': signup_form,
    }, context_instance=RequestContext(request))