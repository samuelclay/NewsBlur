import datetime
import zlib
import urllib
import urlparse
from django.contrib.auth.decorators import login_required
from django.core.urlresolvers import reverse
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.http import HttpResponse, HttpResponseRedirect, Http404
from django.conf import settings
from apps.rss_feeds.models import MStory
from apps.social.models import MSharedStory, MSocialServices
from utils import json_functions as json
from utils.user_functions import ajax_login_required
from utils import log as logging
from utils import PyRSS2Gen as RSS
from vendor import facebook
from vendor import tweepy


@ajax_login_required
@json.json_view
def mark_story_as_shared(request):
    code     = 1
    feed_id  = int(request.POST['feed_id'])
    story_id = request.POST['story_id']
    comments = request.POST.get('comments', '')
    
    story = MStory.objects(story_feed_id=feed_id, story_guid=story_id).limit(1)
    if not story:
        return {'code': -1, 'message': 'Story not found.'}
    
    shared_story = MSharedStory.objects.filter(user_id=request.user.pk, story_feed_id=feed_id, story_guid=story_id)
    if not shared_story:
        story_db = dict([(k, v) for k, v in story[0]._data.items() 
                                if k is not None and v is not None])
        now = datetime.datetime.now()
        story_values = dict(user_id=request.user.pk, shared_date=now, comments=comments, 
                            has_comments=bool(comments), **story_db)
        MSharedStory.objects.create(**story_values)
        logging.user(request, "~FCSharing: ~SB~FM%s (~FB%s~FM)" % (story[0].story_title[:50], comments[:100]))
    else:
        shared_story = shared_story[0]
        shared_story.comments = comments
        shared_story.has_comments = bool(comments)
        shared_story.save()
        logging.user(request, "~FCUpdating shared story: ~SB~FM%s (~FB%s~FM)" % (story[0].story_title[:50], comments[:100]))
        
    
    return {'code': code}
    
def shared_story_feed(request, user_id, username):
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        raise Http404
    
    if user.username != username:
        return HttpResponseRedirect(reverse('shared-story-feed', kwargs={'username': user.username, 'user_id': user.pk}))

    data = {}
    data['title'] = "%s - Shared Stories" % user.username
    link = reverse('shared-stories-public', kwargs={'username': user.username})
    data['link'] = "http://www.newsblur.com/%s" % link
    data['description'] = "Stories shared by %s on NewsBlur." % user.username
    data['lastBuildDate'] = datetime.datetime.utcnow()
    data['items'] = []
    data['generator'] = 'NewsBlur'
    data['docs'] = None

    shared_stories = MSharedStory.objects.filter(user_id=user.pk)[:30]
    for shared_story in shared_stories:
        story_data = {
            'title': shared_story.story_title,
            'link': shared_story.story_permalink,
            'description': zlib.decompress(shared_story.story_content_z),
            'guid': shared_story.story_guid,
            'pubDate': shared_story.story_date,
        }
        data['items'].append(RSS.RSSItem(**story_data))
        
    rss = RSS.RSS2(**data)
    
    return HttpResponse(rss.to_xml())
    
def shared_stories_public(request, username):
    try:
        user = User.objects.get(username=username)
    except User.DoesNotExist:
        raise Http404

    shared_stories = MSharedStory.objects.filter(user_id=user.pk)
        
    return HttpResponse("There are %s stories shared by %s." % (shared_stories.count(), username))
    
@login_required
def twitter_connect(request):
    tweepy
    pass
    
@login_required
def facebook_connect(request):
    facebook_app_id = settings.FACEBOOK_APP_ID
    facebook_secret = settings.FACEBOOK_SECRET
    
    args = {
        "client_id": facebook_app_id,
        "redirect_uri": "http://" + Site.objects.get_current().domain + reverse('facebook-connect'),
        "scope": "offline_access",
        "display": "popup",
    }
    
    verification_code = request.REQUEST.get('code')
    if verification_code:
        args["client_secret"] = facebook_secret
        args["code"] = verification_code
        uri = "https://graph.facebook.com/oauth/access_token?" + \
                urllib.urlencode(args)
        response_text = urllib.urlopen(uri).read()
        response = urlparse.parse_qs(response_text)

        if "access_token" not in response:
            return json.json_response(request, dict(error="Facebook has returned an error. Try connecting again."))

        access_token = response["access_token"][-1]

        # Get the user's profile.
        graph = facebook.GraphAPI(access_token)
        profile = graph.get_object("me")
        uid = profile["id"]

        # Be sure that two people aren't using the same Facebook account.
        existing_user = MSocialServices.objects.filter(facebook_uid=uid)
        if existing_user and existing_user[0].user_id != request.user.pk:
            return json.json_response(request, dict(error=("Another user (%s, %s) has "
                               "already connected with those Facebook credentials."
                               % (existing_user[0].username, existing_user[0].email_address))))

        social_services, _ = MSocialServices.objects.get_or_create(user_id=request.user.pk)
        social_services.facebook_uid = uid
        social_services.facebook_access_token = access_token
        social_services.save()
        social_services.sync_facebook_friends()
        return json.json_response(request, dict(code=1))
    elif request.REQUEST.get('error'):
        pass
    else:
        # Start the OAuth process
        url = "https://www.facebook.com/dialog/oauth?" + urllib.urlencode(args)
        return HttpResponseRedirect(url)
