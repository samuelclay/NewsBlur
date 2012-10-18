import os
import base64
import yaml
from django.conf import settings
from django.http import HttpResponse
from django.shortcuts import render_to_response
from django.template import RequestContext
from apps.profile.models import Profile
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from utils import json_functions as json
from utils import log as logging

def about(request):
    return render_to_response('static/about.xhtml', {}, 
                              context_instance=RequestContext(request))
                              
def faq(request):
    return render_to_response('static/faq.xhtml', {}, 
                              context_instance=RequestContext(request))
                              
def api(request):
    filename     = settings.TEMPLATE_DIRS[0] + '/static/api.yml'
    api_yml_file = open(filename).read()
    data         = yaml.load(api_yml_file)

    return render_to_response('static/api.xhtml', {
        'data': data
    }, context_instance=RequestContext(request))
                              
def press(request):
    return render_to_response('static/press.xhtml', {}, 
                              context_instance=RequestContext(request))
                              
def feedback(request):
    return render_to_response('static/feedback.xhtml', {}, 
                              context_instance=RequestContext(request))

def firefox(request):
    filename = settings.MEDIA_ROOT + '/extensions/firefox/manifest.json'
    manifest = open(filename).read()
    
    return HttpResponse(manifest, content_type='application/x-web-app-manifest+json')

def ios(request):
    return render_to_response('static/ios.xhtml', {},
                              context_instance=RequestContext(request))
    
def android(request):
    return render_to_response('static/android.xhtml', {},
                              context_instance=RequestContext(request))
    
def ios_download(request):
    return render_to_response('static/ios_download.xhtml', {},
                              context_instance=RequestContext(request))
                              
def ios_plist(request):
    filename = settings.MEDIA_ROOT + '/ios/NewsBlur.plist'
    manifest = open(filename).read()
    
    logging.user(request, "~SK~FR~BBDownloading NewsBlur.plist...")
    return HttpResponse(manifest, content_type='text/xml')
    
def ios_ipa(request):
    filename = settings.MEDIA_ROOT + '/ios/NewsBlur.ipa'
    manifest = open(filename).read()
    
    logging.user(request, "~SK~FR~BBDownloading NewsBlur.ipa...")
    return HttpResponse(manifest, content_type='application/octet-stream')
    