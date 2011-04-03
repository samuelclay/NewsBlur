import os
import base64
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
    return render_to_response('static/api.xhtml', {}, 
                              context_instance=RequestContext(request))
                              
def press(request):
    return render_to_response('static/press.xhtml', {}, 
                              context_instance=RequestContext(request))
                              
def publishers(request):
    return render_to_response('static/publishers.xhtml', {}, 
                              context_instance=RequestContext(request))
