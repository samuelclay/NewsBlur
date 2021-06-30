import os
import base64
from django.conf import settings
from django.http import HttpResponse
from django.shortcuts import render
from apps.profile.models import Profile
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from utils import json_functions as json
from utils import log as logging

def index(request):
    return render(request, 'mobile/mobile_workspace.xhtml', {})
