import os
import base64
from vendor import yaml
from django.conf import settings
from django.http import HttpResponse
from django.shortcuts import render_to_response
from django.template import RequestContext
from apps.profile.models import Profile
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from utils import json_functions as json
from utils import log as logging

def index(request):
    return render_to_response('mobile/mobile_workspace.xhtml', {}, 
                              context_instance=RequestContext(request))
