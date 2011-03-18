import datetime
import urlparse
from utils import log as logging
import oauth2 as oauth
from django.contrib.sites.models import Site
from django.db import IntegrityError
from django.http import HttpResponse, HttpResponseRedirect
from django.conf import settings
from django.core.urlresolvers import reverse
from django.template import RequestContext
from django.contrib.auth import login as login_user
from django.shortcuts import render_to_response
from apps.reader.forms import SignupForm
from apps.reader.models import UserSubscription
from apps.feed_import.models import OAuthToken, OPMLImporter, OPMLExporter, GoogleReaderImporter
from utils import json_functions as json
from utils.user_functions import ajax_login_required, get_user


@ajax_login_required
def opml_upload(request):
    xml_opml = None
    message = "OK"
    code = 1
    payload = {}
    
    if request.method == 'POST':
        if 'file' in request.FILES:
            logging.user(request.user, "~FR~SBOPML upload starting...")
            file = request.FILES['file']
            xml_opml = file.read()
            opml_importer = OPMLImporter(xml_opml, request.user)
            folders = opml_importer.process()

            feeds = UserSubscription.objects.filter(user=request.user).values()
            payload = dict(folders=folders, feeds=feeds)
            logging.user(request.user, "~FR~SBOPML Upload: ~SK%s~SN~SB~FR feeds" % (len(feeds)))
            
            request.session['import_from_google_reader'] = False
        else:
            message = "Attach an .opml file."
            code = -1
            
    data = json.encode(dict(message=message, code=code, payload=payload))
    return HttpResponse(data, mimetype='text/plain')

def opml_export(request):
    user     = get_user(request)
    exporter = OPMLExporter(user)
    opml     = exporter.process()
    now      = datetime.datetime.now()
    
    response = HttpResponse(opml, mimetype='text/xml')
    response['Content-Disposition'] = 'attachment; filename=NewsBlur Subscriptions - %s' % (
        now.strftime('%d %B %Y')
    )
    
    return response
        
def reader_authorize(request):
    logging.user(request.user, "~BB~FW~SBAuthorize Google Reader import - %s" % (
        request.META['REMOTE_ADDR'],
    ))
    oauth_key = settings.OAUTH_KEY
    oauth_secret = settings.OAUTH_SECRET
    scope = "http://www.google.com/reader/api"
    request_token_url = ("https://www.google.com/accounts/OAuthGetRequestToken?"
                         "scope=%s&oauth_callback=http://%s%s") % (
                            scope,
                            Site.objects.get_current().domain,
                            reverse('google-reader-callback'),
                         )
    authorize_url = 'https://www.google.com/accounts/OAuthAuthorizeToken'
    
    # Grab request token from Google's OAuth
    consumer = oauth.Consumer(oauth_key, oauth_secret)
    client = oauth.Client(consumer)
    resp, content = client.request(request_token_url, "GET")
    request_token = dict(urlparse.parse_qsl(content))
    
    # Save request token and delete old tokens
    auth_token_dict = dict(request_token=request_token['oauth_token'], 
                           request_token_secret=request_token['oauth_token_secret'])
    if request.user.is_authenticated():
        OAuthToken.objects.filter(user=request.user).delete()
        auth_token_dict['user'] = request.user
    else:
        OAuthToken.objects.filter(session_id=request.session.session_key).delete()
        OAuthToken.objects.filter(remote_ip=request.META['REMOTE_ADDR']).delete()
    auth_token_dict['session_id'] = request.session.session_key
    auth_token_dict['remote_ip'] = request.META['REMOTE_ADDR']
    OAuthToken.objects.create(**auth_token_dict)
                              
    redirect = "%s?oauth_token=%s" % (authorize_url, request_token['oauth_token'])
    return HttpResponseRedirect(redirect)

def reader_callback(request):
    access_token_url = 'https://www.google.com/accounts/OAuthGetAccessToken'
    consumer = oauth.Consumer(settings.OAUTH_KEY, settings.OAUTH_SECRET)
    user_token = None

    if request.user.is_authenticated():
        user_token = OAuthToken.objects.get(user=request.user)
    else:
        try:
            user_token = OAuthToken.objects.get(session_id=request.session.session_key)
        except OAuthToken.DoesNotExist:
            user_tokens = OAuthToken.objects.filter(remote_ip=request.META['REMOTE_ADDR']).order_by('-created_date')
            # logging.info("Found ip user_tokens: %s" % user_tokens)
            if user_tokens:
                user_token = user_tokens[0]
                user_token.session_id = request.session.session_key
                user_token.save()
    
    if user_token and request.GET.get('oauth_verifier'):
        # logging.info("Google Reader request.GET: %s" % request.GET)
        # Authenticated in Google, so verify and fetch access tokens
        token = oauth.Token(user_token.request_token, user_token.request_token_secret)
        token.set_verifier(request.GET['oauth_verifier'])
        client = oauth.Client(consumer, token)
        resp, content = client.request(access_token_url, "POST")
        access_token = dict(urlparse.parse_qsl(content))
        user_token.access_token = access_token.get('oauth_token')
        user_token.access_token_secret = access_token.get('oauth_token_secret')
        try:
            user_token.save()
        except IntegrityError:
            logging.info(" ***> [%s] Bad token from Google Reader. Re-authenticating." % (request.user,))
            return HttpResponseRedirect(reverse('google-reader-authorize'))
    
        # Fetch imported feeds on next page load
        request.session['import_from_google_reader'] = True
    
        logging.user(request.user, "~BB~FW~SBFinishing Google Reader import - %s" % (request.META['REMOTE_ADDR'],))
    
        if request.user.is_authenticated():
            return HttpResponseRedirect(reverse('index'))
    else:
        logging.info(" ***> [%s] Bad token from Google Reader. Re-authenticating." % (request.user,))
        return HttpResponseRedirect(reverse('google-reader-authorize'))    

    return HttpResponseRedirect(reverse('import-signup'))
    
@json.json_view
def import_from_google_reader(request):
    scope = "http://www.google.com/reader/api"
    sub_url = "%s/0/subscription/list" % scope
    code = 0

    if request.user.is_authenticated():
        user_tokens = OAuthToken.objects.filter(user=request.user)
        if user_tokens.count():
            user_token = user_tokens[0]
            consumer = oauth.Consumer(settings.OAUTH_KEY, settings.OAUTH_SECRET)
            token = oauth.Token(user_token.access_token, user_token.access_token_secret)
            client = oauth.Client(consumer, token)

            resp, content = client.request(sub_url, 'GET')
            reader_importer = GoogleReaderImporter(content, request.user)
            reader_importer.process()
            code = 1
            if 'import_from_google_reader' in request.session:
                del request.session['import_from_google_reader']

    return dict(code=code)

def import_signup(request):
    if request.method == "POST":
        signup_form = SignupForm(prefix='signup', data=request.POST)
        if signup_form.is_valid():
            new_user = signup_form.save()
            try:
                user_token = OAuthToken.objects.get(session_id=request.session.session_key)
            except OAuthToken.DoesNotExist:
                user_tokens = OAuthToken.objects.filter(remote_ip=request.META['REMOTE_ADDR']).order_by('-created_date')
                if user_tokens:
                    user_token = user_tokens[0]
                    user_token.session_id = request.session.session_key
                    user_token.save()
            user_token.user = new_user
            user_token.save()
            login_user(request, new_user)
            return HttpResponseRedirect(reverse('index'))
    else:
        signup_form = SignupForm(prefix='signup')

    return render_to_response('import/signup.xhtml', {
        'signup_form': signup_form,
    }, context_instance=RequestContext(request))