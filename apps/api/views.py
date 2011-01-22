import os
import base64
from django.conf import settings
from django.shortcuts import render_to_response
from django.template import RequestContext
from apps.profile.models import Profile
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from utils import json_functions as json

def add_site_load_script(request, token):
    code = 0
    folder_image_path = os.path.join(settings.MEDIA_ROOT, 'img/icons/silk/folder.png')
    folder_image = open(folder_image_path)
    folder_image = base64.b64encode(folder_image.read())
    try:
        profile = Profile.objects.get(secret_token=token)
        usf = UserSubscriptionFolders.objects.get(
            user=profile.user
        )
    except Profile.DoesNotExist:
        code = -1
    except UserSubscriptionFolders.DoesNotExist:
        code = -1
    
    return render_to_response('api/bookmarklet_subscribe.js', {
        'code': code,
        'token': token,
        'folders': usf.folders,
        'folder_image': folder_image,
    }, context_instance=RequestContext(request))

@json.json_view
def add_site(request, token):
    code = 0
    
    try:
        profile = Profile.objects.get(secret_token=token)
        code, message, us = UserSubscription.add_subscription(
            user=profile.user, 
            feed_address=request.REQUEST['url']
        )
    except Profile.DoesNotExist:
        code = -1
    
    return {
        'code':    code,
        'message': message,
        'usersub': us,
    }