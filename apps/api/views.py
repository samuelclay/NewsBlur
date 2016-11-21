import os
import base64
import urlparse
import datetime
import lxml.html
from django import forms
from django.conf import settings
from django.http import HttpResponse
from django.shortcuts import render_to_response
from django.template import RequestContext
from django.contrib.auth import login as login_user
from django.contrib.auth import logout as logout_user
from apps.reader.forms import SignupForm, LoginForm
from apps.profile.models import Profile
from apps.social.models import MSocialProfile, MSharedStory, MSocialSubscription
from apps.rss_feeds.models import Feed
from apps.rss_feeds.text_importer import TextImporter
from apps.reader.models import UserSubscription, UserSubscriptionFolders, RUserStory
from utils import json_functions as json
from utils import log as logging
from utils.feed_functions import relative_timesince
from utils.view_functions import required_params


@json.json_view
def login(request):
    code = -1
    errors = None
    user_agent = request.environ.get('HTTP_USER_AGENT', '')
    ip = request.META.get('HTTP_X_FORWARDED_FOR', None) or request.META['REMOTE_ADDR']

    if not user_agent or user_agent.lower() in ['nativehost']:
        errors = dict(user_agent="You must set a user agent to login.")
        logging.user(request, "~FG~BB~SK~FRBlocked ~FGAPI Login~SN~FW: %s / %s" % (user_agent, ip))
    elif request.method == "POST":
        form = LoginForm(data=request.POST)
        if form.errors:
            errors = form.errors
        if form.is_valid():
            login_user(request, form.get_user())
            logging.user(request, "~FG~BB~SKAPI Login~SN~FW: %s / %s" % (user_agent, ip))
            code = 1
    else:
        errors = dict(method="Invalid method. Use POST. You used %s" % request.method)
        
    return dict(code=code, errors=errors)
    
@json.json_view
def signup(request):
    code = -1
    errors = None
    ip = request.META.get('HTTP_X_FORWARDED_FOR', None) or request.META['REMOTE_ADDR']

    if request.method == "POST":
        form = SignupForm(data=request.POST)
        if form.errors:
            errors = form.errors
        if form.is_valid():
            try:
                new_user = form.save()
                login_user(request, new_user)
                logging.user(request, "~FG~SB~BBAPI NEW SIGNUP: ~FW%s / %s" % (new_user.email, ip))
                code = 1
            except forms.ValidationError, e:
                errors = [e.args[0]]
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
    profile = None;
    user_profile = None;
    def image_base64(image_name, path='icons/circular/'):
        image_file = open(os.path.join(settings.MEDIA_ROOT, 'img/%s%s' % (path, image_name)))
        return base64.b64encode(image_file.read())
    
    accept_image     = image_base64('newuser_icn_setup.png')
    error_image      = image_base64('newuser_icn_sharewith_active.png')
    new_folder_image = image_base64('g_icn_arrow_right.png')
    add_image        = image_base64('g_icn_expand_hover.png')

    try:
        profiles = Profile.objects.filter(secret_token=token)
        if profiles:
            profile = profiles[0]
            usf = UserSubscriptionFolders.objects.get(
                user=profile.user
            )
            user_profile = MSocialProfile.get_user(user_id=profile.user.pk)
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
        'user_profile': user_profile and json.encode(user_profile.canonical()) or {},
        'accept_image': accept_image,
        'error_image': error_image,
        'add_image': add_image,
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
        
    logging.user(profile.user, "~FRAdding URL from site: ~SB%s (in %s)" % (url, folder),
                 request=request)
    
    return HttpResponse(callback + '(' + json.encode({
        'code':    code,
        'message': message,
        'usersub': us and us.feed_id,
    }) + ')', mimetype='text/plain')
    
def check_share_on_site(request, token):
    code       = 0
    story_url  = request.GET['story_url']
    rss_url    = request.GET.get('rss_url')
    callback   = request.GET['callback']
    other_stories = None
    same_stories = None
    usersub    = None
    message    = None
    user       = None
    
    if not story_url:
        code = -1
    else:
        try:
            user_profile = Profile.objects.get(secret_token=token)
            user = user_profile.user
        except Profile.DoesNotExist:
            code = -1
    
    logging.user(request.user, "~FBFinding feed (check_share_on_site): %s" % rss_url)
    feed = Feed.get_feed_from_url(rss_url, create=False, fetch=False)
    if not feed:
        logging.user(request.user, "~FBFinding feed (check_share_on_site): %s" % story_url)
        feed = Feed.get_feed_from_url(story_url, create=False, fetch=False)
    if not feed:
        parsed_url = urlparse.urlparse(story_url)
        base_url = "%s://%s%s" % (parsed_url.scheme, parsed_url.hostname, parsed_url.path)
        logging.user(request.user, "~FBFinding feed (check_share_on_site): %s" % base_url)
        feed = Feed.get_feed_from_url(base_url, create=False, fetch=False)
    if not feed:
        logging.user(request.user, "~FBFinding feed (check_share_on_site): %s" % (base_url + '/'))
        feed = Feed.get_feed_from_url(base_url+'/', create=False, fetch=False)
    
    if feed and user:
        try:
            usersub = UserSubscription.objects.filter(user=user, feed=feed)
        except UserSubscription.DoesNotExist:
            usersub = None
    feed_id = feed and feed.pk
    your_story, same_stories, other_stories = MSharedStory.get_shared_stories_from_site(feed_id,
                                              user_id=user_profile.user.pk, story_url=story_url)
    previous_stories = MSharedStory.objects.filter(user_id=user_profile.user.pk).order_by('-shared_date').limit(3)
    previous_stories = [{
        "user_id": story.user_id,
        "story_title": story.story_title,
        "comments": story.comments,
        "shared_date": story.shared_date,
        "relative_date": relative_timesince(story.shared_date),
        "blurblog_permalink": story.blurblog_permalink(),
    } for story in previous_stories]
    
    user_ids = set([user_profile.user.pk])
    for story in same_stories:
        user_ids.add(story['user_id'])
    for story in other_stories:
        user_ids.add(story['user_id'])
    
    users = {}
    profiles = MSocialProfile.profiles(user_ids)
    for profile in profiles:
        users[profile.user_id] = {
            "username": profile.username,
            "photo_url": profile.photo_url,
        }
        
    logging.user(user_profile.user, "~BM~FCChecking share from site: ~SB%s" % (story_url),
                 request=request)
    
    response = HttpResponse(callback + '(' + json.encode({
        'code'              : code,
        'message'           : message,
        'feed'              : feed,
        'subscribed'        : bool(usersub),
        'your_story'        : your_story,
        'same_stories'      : same_stories,
        'other_stories'     : other_stories,
        'previous_stories'  : previous_stories,
        'users'             : users,
    }) + ')', mimetype='text/plain')
    response['Access-Control-Allow-Origin'] = '*'
    response['Access-Control-Allow-Methods'] = 'GET'
    
    return response

@required_params('story_url', 'comments', 'title')
def share_story(request, token=None):
    code      = 0
    story_url = request.REQUEST['story_url']
    comments  = request.REQUEST['comments']
    title     = request.REQUEST['title']
    content   = request.REQUEST.get('content', None)
    rss_url   = request.REQUEST.get('rss_url', None)
    feed_id   = request.REQUEST.get('feed_id', None) or 0
    feed      = None
    message   = None
    profile   = None
    
    if request.user.is_authenticated():
        profile = request.user.profile
    else:
        try:
            profile = Profile.objects.get(secret_token=token)
        except Profile.DoesNotExist:
            code = -1
            if token:
                message = "Not authenticated, couldn't find user by token."
            else:
                message = "Not authenticated, no token supplied and not authenticated."

    
    if not profile:
        return HttpResponse(json.encode({
            'code':     code,
            'message':  message,
            'story':    None,
        }), mimetype='text/plain')
    
    if feed_id:
        feed = Feed.get_by_id(feed_id)
    else:
        if rss_url:
            logging.user(request.user, "~FBFinding feed (share_story): %s" % rss_url)
            feed = Feed.get_feed_from_url(rss_url, create=True, fetch=True)
        if not feed:
            logging.user(request.user, "~FBFinding feed (share_story): %s" % story_url)
            feed = Feed.get_feed_from_url(story_url, create=True, fetch=True)
        if feed:
            feed_id = feed.pk
    
    if content:
        content = lxml.html.fromstring(content)
        content.make_links_absolute(story_url)
        content = lxml.html.tostring(content)
    else:
        importer = TextImporter(story=None, story_url=story_url, request=request, debug=settings.DEBUG)
        document = importer.fetch(skip_save=True, return_document=True)
        content = document['content']
        if not title:
            title = document['title']
    
    shared_story = MSharedStory.objects.filter(user_id=profile.user.pk,
                                               story_feed_id=feed_id, 
                                               story_guid=story_url).limit(1).first()
    if not shared_story:
        story_db = {
            "story_guid": story_url,
            "story_permalink": story_url,
            "story_title": title,
            "story_feed_id": feed_id,
            "story_content": content,
            "story_date": datetime.datetime.now(),
            
            "user_id": profile.user.pk,
            "comments": comments,
            "has_comments": bool(comments),
        }
        shared_story = MSharedStory.objects.create(**story_db)
        socialsubs = MSocialSubscription.objects.filter(subscription_user_id=profile.user.pk)
        for socialsub in socialsubs:
            socialsub.needs_unread_recalc = True
            socialsub.save()
        logging.user(profile.user, "~BM~FYSharing story from site: ~SB%s: %s" % (story_url, comments))
        message = "Sharing story from site: %s: %s" % (story_url, comments)
    else:
        shared_story.story_content = content
        shared_story.story_title = title
        shared_story.comments = comments
        shared_story.story_permalink = story_url
        shared_story.story_guid = story_url
        shared_story.has_comments = bool(comments)
        shared_story.story_feed_id = feed_id
        shared_story.save()
        logging.user(profile.user, "~BM~FY~SBUpdating~SN shared story from site: ~SB%s: %s" % (story_url, comments))
        message = "Updating shared story from site: %s: %s" % (story_url, comments)
    try:
        socialsub = MSocialSubscription.objects.get(user_id=profile.user.pk, 
                                                    subscription_user_id=profile.user.pk)
    except MSocialSubscription.DoesNotExist:
        socialsub = None
    
    if socialsub:
        socialsub.mark_story_ids_as_read([shared_story.story_hash], 
                                          shared_story.story_feed_id, 
                                          request=request)
    else:
        RUserStory.mark_read(profile.user.pk, shared_story.story_feed_id, shared_story.story_hash)


    shared_story.publish_update_to_subscribers()
    
    response = HttpResponse(json.encode({
        'code':     code,
        'message':  message,
        'story':    shared_story,
    }), mimetype='text/plain')
    response['Access-Control-Allow-Origin'] = '*'
    response['Access-Control-Allow-Methods'] = 'POST'
    
    return response
