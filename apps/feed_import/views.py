import datetime
import pickle
import base64
from utils import log as logging
from oauth2client.client import OAuth2WebServerFlow
import uuid
from django.contrib.sites.models import Site
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
                uploaded_opml = UploadedOPML.objects.create(user_id=request.user.pk, opml_file=xml_opml)
            except UnicodeDecodeError:
                uploaded_opml = None
                folders = None
                code = -1
                message = "There was a Unicode decode error when reading your OPML file."
            
            if uploaded_opml:
                opml_importer = OPMLImporter(xml_opml, request.user)
                try:
                    folders = opml_importer.try_processing()
                except TimeoutError:
                    folders = None
                    ProcessOPML.delay(request.user.pk)
                    feed_count = opml_importer.count_feeds_in_opml()
                    logging.user(request, "~FR~SBOPML pload took too long, found %s feeds. Tasking..." % feed_count)
                    payload = dict(folders=folders, delayed=True, feed_count=feed_count)
                    code = 2
                    message = ""

            if folders:
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
    exporter = OPMLExporter(user)
    opml     = exporter.process()
    now      = datetime.datetime.now()
    
    response = HttpResponse(opml, mimetype='text/xml')
    response['Content-Disposition'] = 'attachment; filename=NewsBlur Subscriptions - %s' % (
        now.strftime('%Y-%m-%d')
    )
    
    return response


def reader_authorize(request): 
    # is_modal = request.GET.get('modal', False)
    domain = Site.objects.get_current().domain
    STEP2_URI = "http://%s%s" % (
        (domain + '.com') if not domain.endswith('.com') else domain,
        reverse('google-reader-callback'),
    )

    FLOW = OAuth2WebServerFlow(
        client_id=settings.GOOGLE_OAUTH2_CLIENTID,
        client_secret=settings.GOOGLE_OAUTH2_SECRET,
        scope="http://www.google.com/reader/api",
        redirect_uri=STEP2_URI,
        user_agent='NewsBlur Pro, www.newsblur.com',
        )
    logging.user(request, "~BB~FW~SBAuthorize Google Reader import - %s" % (
        request.META['REMOTE_ADDR'],
    ))

    authorize_url = FLOW.step1_get_authorize_url(redirect_uri=STEP2_URI)
    response = render_to_response('social/social_connect.xhtml', {
        'next': authorize_url,
    }, context_instance=RequestContext(request))
    
    # Save request token and delete old tokens
    auth_token_dict = dict()
    if request.user.is_authenticated():
        OAuthToken.objects.filter(user=request.user).delete()
        auth_token_dict['user'] = request.user
    else:
        OAuthToken.objects.filter(session_id=request.session.session_key).delete()
        OAuthToken.objects.filter(remote_ip=request.META['REMOTE_ADDR']).delete()
    auth_token_dict['uuid'] = str(uuid.uuid4())
    auth_token_dict['session_id'] = request.session.session_key
    auth_token_dict['remote_ip'] = request.META['REMOTE_ADDR']
    OAuthToken.objects.create(**auth_token_dict)

    response.set_cookie('newsblur_reader_uuid', str(uuid.uuid4()))
    return response

def reader_callback(request):
    
    domain = Site.objects.get_current().domain
    STEP2_URI = "http://%s%s" % (
        (domain + '.com') if not domain.endswith('.com') else domain,
        reverse('google-reader-callback'),
    )
    FLOW = OAuth2WebServerFlow(
        client_id=settings.GOOGLE_OAUTH2_CLIENTID,
        client_secret=settings.GOOGLE_OAUTH2_SECRET,
        scope="http://www.google.com/reader/api",
        redirect_uri=STEP2_URI,
        user_agent='NewsBlur Pro, www.newsblur.com',
        )
    FLOW.redirect_uri = STEP2_URI
    is_modal = request.GET.get('modal', False)

    credential = FLOW.step2_exchange(request.REQUEST)
    
    user_token = None
    if request.user.is_authenticated():
        user_token = OAuthToken.objects.filter(user=request.user).order_by('-created_date')
    if not user_token:
        user_uuid = request.COOKIES.get('newsblur_reader_uuid')
        if user_uuid:
            user_token = OAuthToken.objects.filter(uuid=user_uuid).order_by('-created_date')
    if not user_token:
        session = request.session
        if session.session_key:
            user_token = OAuthToken.objects.filter(session_id=request.session.session_key).order_by('-created_date')
    if not user_token:
        user_token = OAuthToken.objects.filter(remote_ip=request.META['REMOTE_ADDR']).order_by('-created_date')

    if user_token:
        user_token = user_token[0]
        user_token.credential = base64.b64encode(pickle.dumps(credential))
        user_token.session_id = request.session.session_key
        user_token.save()
    
    # 
    # try:
    #     if not user_token.access_token:
    #         raise IntegrityError
    #     user_token.save()
    # except IntegrityError:
    #     if is_modal:
    #         return render_to_response('social/social_connect.xhtml', {
    #             'error': 'There was an error trying to import from Google Reader. Trying again will probably fix the issue.'
    #         }, context_instance=RequestContext(request))
    #     logging.info(" ***> [%s] Bad token from Google Reader. Re-authenticating." % (request.user,))
    #     return HttpResponseRedirect(reverse('google-reader-authorize'))

    # Fetch imported feeds on next page load
    request.session['import_from_google_reader'] = True

    logging.user(request, "~BB~FW~SBFinishing Google Reader import - %s" % (request.META['REMOTE_ADDR'],))

    if request.user.is_authenticated():
        if is_modal or True:
            return render_to_response('social/social_connect.xhtml', {}, context_instance=RequestContext(request))
        else:
            return HttpResponseRedirect(reverse('index'))

    return HttpResponseRedirect(reverse('import-signup'))
    
@json.json_view
def import_from_google_reader(request):
    code = 0

    if request.user.is_authenticated():
        reader_importer = GoogleReaderImporter(request.user)
        auto_active = bool(request.REQUEST.get('auto_active') or False)
        try:
            reader_importer.import_feeds(auto_active=auto_active)
            reader_importer.import_starred_items()
        except AssertionError:
            code = -1
        else:
            code = 1
        if 'import_from_google_reader' in request.session:
            del request.session['import_from_google_reader']

    return dict(code=code)

def import_signup(request):
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
                user_token = OAuthToken.objects.filter(remote_ip=request.META['REMOTE_ADDR']).order_by('-created_date')

            if user_token:
                user_token = user_token[0]
                user_token.session_id = request.session.session_key
                user_token.user = new_user
                user_token.save()
                login_user(request, new_user)
                return HttpResponseRedirect(reverse('index'))
            else:
                logging.user(request, "~BR~FW ***> Can't find user token during import/signup. Re-authenticating...")
                return HttpResponseRedirect(reverse('google-reader-authorize'))
    else:
        signup_form = SignupForm(prefix='signup')

    return render_to_response('import/signup.xhtml', {
        'signup_form': signup_form,
    }, context_instance=RequestContext(request))