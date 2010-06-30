# -*- coding: utf-8 -*-
from apps.reader.models import UserSubscription
from utils import json
from apps.feed_import.models import OAuthToken, OPMLImporter, GoogleReaderImporter
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.http import HttpResponse, HttpResponseRedirect
from django.conf import settings
from django.core.urlresolvers import reverse
import urlparse
import oauth2 as oauth


def opml_upload(request):
    xml_opml = None
    message = "OK"
    code = 1
    payload = {}
    
    if request.method == 'POST':
        if 'file' in request.FILES:
            file = request.FILES['file']
            xml_opml = file.read()
            
            opml_importer = OPMLImporter(xml_opml, request.user)
            folders = opml_importer.process()

            feeds = UserSubscription.objects.filter(user=request.user).values()
            payload = dict(folders=folders, feeds=feeds)
        else:
            message = "Attach an .opml file."
            code = -1
            
    data = json.encode(dict(message=message, code=code, payload=payload))
    return HttpResponse(data, mimetype='text/plain')

        
def reader_authorize(request):
    oauth_key = settings.OAUTH_KEY
    oauth_secret = settings.OAUTH_SECRET
    scope = "http://www.google.com/reader/api"
    request_token_url = "https://www.google.com/accounts/OAuthGetRequestToken?scope=%s&oauth_callback=http://%s%s" % (
        scope,
        Site.objects.get_current().domain,
        reverse('opml-reader-callback'),
    )
    authorize_url = 'https://www.google.com/accounts/OAuthAuthorizeToken'
    
    consumer = oauth.Consumer(oauth_key, oauth_secret)
    client = oauth.Client(consumer)
    resp, content = client.request(request_token_url, "GET")
    request_token = dict(urlparse.parse_qsl(content))

    OAuthToken.objects.filter(user=request.user).delete()
    OAuthToken.objects.create(user=request.user, 
                              request_token=request_token['oauth_token'], 
                              request_token_secret=request_token['oauth_token_secret'])
                              
    redirect = "%s?oauth_token=%s" % (authorize_url, request_token['oauth_token'])
    return HttpResponseRedirect(redirect)

def reader_callback(request):
    access_token_url = 'https://www.google.com/accounts/OAuthGetAccessToken'
    consumer = oauth.Consumer(settings.OAUTH_KEY, settings.OAUTH_SECRET)
    
    user_token = OAuthToken.objects.get(user=request.user)
    token = oauth.Token(user_token.request_token, user_token.request_token_secret)
    token.set_verifier(request.GET['oauth_verifier'])
    client = oauth.Client(consumer, token)
    resp, content = client.request(access_token_url, "POST")
    access_token = dict(urlparse.parse_qsl(content))

    user_token.access_token = access_token['oauth_token']
    user_token.access_token_secret = access_token['oauth_token_secret']
    user_token.save()
    
    request.session['import_from_google_reader'] = True
    
    return HttpResponseRedirect(reverse('index'))
    
def import_from_google_reader(user):
    scope = "http://www.google.com/reader/api"
    sub_url = "%s/0/subscription/list" % scope
    user_tokens = OAuthToken.objects.filter(user=user)
    if user_tokens.count():
        user_token = user_tokens[0]
        consumer = oauth.Consumer(settings.OAUTH_KEY, settings.OAUTH_SECRET)
        token = oauth.Token(user_token.access_token, user_token.access_token_secret)
        client = oauth.Client(consumer, token)

        resp, content = client.request(sub_url, 'GET')
        reader_importer = GoogleReaderImporter(content, user)
        return reader_importer.process()
    