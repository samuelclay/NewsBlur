import os
import base64
from django.conf import settings
from django.http import HttpResponse
from django.shortcuts import render_to_response
from django.template import RequestContext
from django.contrib.auth import login as login_user
from django.contrib.auth import logout as logout_user
from apps.reader.forms import SignupForm, LoginForm
from apps.profile.models import Profile
from apps.social.models import MSocialProfile
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from utils import json_functions as json
from utils import log as logging

@json.json_view
def login(request):
    code = -1
    errors = None
    
    if request.method == "POST":
        form = LoginForm(data=request.POST)
        if form.errors:
            errors = form.errors
        if form.is_valid():
            login_user(request, form.get_user())
            logging.user(request, "~FG~BB~SKAPI Login~FW")
            code = 1
    else:
        errors = dict(method="Invalid method. Use POST. You used %s" % request.method)
        
    return dict(code=code, errors=errors)
    
@json.json_view
def signup(request):
    code = -1
    errors = None
    
    if request.method == "POST":
        form = SignupForm(data=request.POST)
        if form.errors:
            errors = form.errors
        if form.is_valid():
            new_user = form.save()
            login_user(request, new_user)
            logging.user(request, "~FG~SB~BBAPI NEW SIGNUP~FW")
            code = 1
    else:
        errors = dict(method="Invalid method. Use POST. You used %s" % request.method)
        

    return dict(code=code, errors=errors)
        
@json.json_view
def logout(request):
    code = 1
    logging.user(request, "~FG~BBAPI Logout~FW")
    logout_user(request)
    
    return dict(code=code)

def add_site_load_script(request, token):
    code = 0
    usf = None
    user_profile = None;
    def image_base64(image_name, path='icons/silk/'):
        image_file = open(os.path.join(settings.MEDIA_ROOT, 'img/%s%s' % (path, image_name)))
        return base64.b64encode(image_file.read())
    
    accept_image     = image_base64('accept.png')
    error_image      = image_base64('error.png')
    new_folder_image = image_base64('arrow_down_right.png')
    add_image        = image_base64('add.png')
    side_background  = image_base64('subtle-pattern-11.jpg', path='reader/')

    try:
        profiles = Profile.objects.filter(secret_token=token)
        if profiles:
            profile = profiles[0]
            usf = UserSubscriptionFolders.objects.get(
                user=profile.user
            )
            user_profile = MSocialProfile.objects.get(user_id=profile.user.pk)
        else:
            code = -1
    except Profile.DoesNotExist:
        code = -1
    except UserSubscriptionFolders.DoesNotExist:
        code = -1
    
    return render_to_response('api/share_bookmarklet.js', {
        'code': code,
        'token': token,
        'folders': (usf and usf.folders) or [],
        'user': profile and profile.user or {},
        'user_profile': user_profile and json.encode(user_profile.to_json()) or {},
        'accept_image': accept_image,
        'error_image': error_image,
        'add_image': add_image,
        'side_background': side_background,
        'new_folder_image': new_folder_image,
    }, 
    context_instance=RequestContext(request),
    mimetype='application/javascript')

def add_site(request, token):
    code       = 0
    url        = request.GET['url']
    folder     = request.GET['folder']
    new_folder = request.GET.get('new_folder')
    callback   = request.GET['callback']
    
    if not url:
        code = -1
    else:
        try:
            profile = Profile.objects.get(secret_token=token)
            if new_folder:
                usf, _ = UserSubscriptionFolders.objects.get_or_create(user=profile.user)
                usf.add_folder(folder, new_folder)
                folder = new_folder
            code, message, us = UserSubscription.add_subscription(
                user=profile.user, 
                feed_address=url,
                folder=folder,
                bookmarklet=True
            )
        except Profile.DoesNotExist:
            code = -1
    
    if code > 0:
        message = 'OK'
        
    logging.user(profile.user, "~FRAdding URL from site: ~SB%s (in %s)" % (url, folder))
    
    return HttpResponse(callback + '(' + json.encode({
        'code':    code,
        'message': message,
        'usersub': us and us.feed_id,
    }) + ')', mimetype='text/plain')