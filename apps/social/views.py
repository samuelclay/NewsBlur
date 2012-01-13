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
from apps.social.models import MSharedStory, MSocialServices, MSocialProfile
from utils import json_functions as json
from utils.user_functions import get_user, ajax_login_required
from utils.view_functions import render_to
from utils import log as logging
from utils import PyRSS2Gen as RSS
from vendor import facebook
from vendor import tweepy

@json.json_view
def story_comments(request):
    feed_id  = int(request.POST['feed_id'])
    story_id = request.POST['story_id']
    full = request.POST.get('full', False)
    compact = request.POST.get('compact', False)
    
    shared_stories = MSharedStory.objects.filter(story_feed_id=feed_id, story_guid=story_id)
    comments = [s.comments_with_author(compact=compact, full=full) for s in shared_stories]
    
    return {'comments': comments}

@ajax_login_required
@json.json_view
def mark_story_as_shared(request):
    code     = 1
    feed_id  = int(request.POST['feed_id'])
    story_id = request.POST['story_id']
    comments = request.POST.get('comments', '')
    
    story = MStory.objects(story_feed_id=feed_id, story_guid=story_id).limit(1).first()
    if not story:
        return {'code': -1, 'message': 'Story not found.'}
    
    shared_story = MSharedStory.objects.filter(user_id=request.user.pk, story_feed_id=feed_id, story_guid=story_id)
    if not shared_story:
        story_db = dict([(k, v) for k, v in story._data.items() 
                                if k is not None and v is not None])
        now = datetime.datetime.now()
        story_values = dict(user_id=request.user.pk, shared_date=now, comments=comments, 
                            has_comments=bool(comments), **story_db)
        MSharedStory.objects.create(**story_values)
        logging.user(request, "~FCSharing: ~SB~FM%s (~FB%s~FM)" % (story.story_title[:50], comments[:100]))
    else:
        shared_story = shared_story[0]
        shared_story.comments = comments
        shared_story.has_comments = bool(comments)
        shared_story.save()
        logging.user(request, "~FCUpdating shared story: ~SB~FM%s (~FB%s~FM)" % (story.story_title[:50], comments[:100]))
    
    story.count_comments()
    
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

@json.json_view
def friends(request):
    user = get_user(request)
    social_services, _ = MSocialServices.objects.get_or_create(user_id=user.pk)
    social_profile, _ = MSocialProfile.objects.get_or_create(user_id=user.pk)
    following_profiles = MSocialProfile.profiles(social_profile.following_user_ids)
    follower_profiles = MSocialProfile.profiles(social_profile.follower_user_ids)
    
    return {
        'services': social_services,
        'autofollow': social_services.autofollow,
        'user_profile': social_profile.to_json(full=True),
        'following_profiles': following_profiles,
        'follower_profiles': follower_profiles,
    }
    
@ajax_login_required
@json.json_view
def profile(request):
    if request.method == 'POST':
        return save_profile(request)

    profile = MSocialProfile.objects.get(user_id=request.user.pk)
    return dict(code=1, user_profile=profile.to_json(full=True))
    
def save_profile(request):
    data = request.POST

    profile = MSocialProfile.objects.get(user_id=request.user.pk)
    profile.location = data['location']
    profile.bio = data['bio']
    profile.website = data['website']
    profile.save()

    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    social_services.set_photo(data['photo_service'])
    
    return dict(code=1, user_profile=profile.to_json(full=True))

@ajax_login_required
@json.json_view
def follow(request):
    follow_user_id = int(request.POST['user_id'])
    profile = MSocialProfile.objects.get(user_id=request.user.pk)
    profile.follow_user(follow_user_id)
    
    follow_profile = MSocialProfile.objects.get(user_id=follow_user_id)
    
    return dict(user_profile=profile.to_json(full=True), follow_profile=follow_profile)
    
@ajax_login_required
@json.json_view
def unfollow(request):
    unfollow_user_id = int(request.POST['user_id'])
    profile = MSocialProfile.objects.get(user_id=request.user.pk)
    profile.unfollow_user(unfollow_user_id)
    
    unfollow_profile = MSocialProfile.objects.get(user_id=unfollow_user_id)
    
    return dict(user_profile=profile.to_json(full=True), unfollow_profile=unfollow_profile)
    
@login_required
@render_to('social/social_connect.xhtml')
def twitter_connect(request):
    twitter_consumer_key = settings.TWITTER_CONSUMER_KEY
    twitter_consumer_secret = settings.TWITTER_CONSUMER_SECRET
    
    oauth_token = request.REQUEST.get('oauth_token')
    oauth_verifier = request.REQUEST.get('oauth_verifier')
    denied = request.REQUEST.get('denied')
    if denied:
        return {'error': 'Denied! Try connecting again.'}
    elif oauth_token and oauth_verifier:
        try:
            auth = tweepy.OAuthHandler(twitter_consumer_key, twitter_consumer_secret)
            auth.set_request_token(oauth_token, oauth_verifier)
            access_token = auth.get_access_token(oauth_verifier)
            api = tweepy.API(auth)
            twitter_user = api.me()
        except (tweepy.TweepError, IOError):
            return dict(error="Twitter has returned an error. Try connecting again.")

        # Be sure that two people aren't using the same Twitter account.
        existing_user = MSocialServices.objects.filter(twitter_uid=unicode(twitter_user.id))
        if existing_user and existing_user[0].user_id != request.user.pk:
            user = User.objects.get(pk=existing_user[0].user_id)
            return dict(error=("Another user (%s, %s) has "
                               "already connected with those Twitter credentials."
                               % (user.username, user.email_address)))

        social_services, _ = MSocialServices.objects.get_or_create(user_id=request.user.pk)
        social_services.twitter_uid = unicode(twitter_user.id)
        social_services.twitter_access_key = access_token.key
        social_services.twitter_access_secret = access_token.secret
        social_services.save()
        social_services.sync_twitter_friends()
        return {}
    else:
        # Start the OAuth process
        auth = tweepy.OAuthHandler(twitter_consumer_key, twitter_consumer_secret)
        auth_url = auth.get_authorization_url()
        return {'next': auth_url}

    
@login_required
@render_to('social/social_connect.xhtml')
def facebook_connect(request):
    facebook_app_id = settings.FACEBOOK_APP_ID
    facebook_secret = settings.FACEBOOK_SECRET
    
    args = {
        "client_id": facebook_app_id,
        "redirect_uri": "http://" + Site.objects.get_current().domain + reverse('facebook-connect'),
        "scope": "offline_access,user_website",
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
            return dict(error="Facebook has returned an error. Try connecting again.")

        access_token = response["access_token"][-1]

        # Get the user's profile.
        graph = facebook.GraphAPI(access_token)
        profile = graph.get_object("me")
        uid = profile["id"]

        # Be sure that two people aren't using the same Facebook account.
        existing_user = MSocialServices.objects.filter(facebook_uid=uid)
        if existing_user and existing_user[0].user_id != request.user.pk:
            user = User.objects.get(pk=existing_user[0].user_id)
            return dict(error=("Another user (%s, %s) has "
                               "already connected with those Facebook credentials."
                               % (user.username, user.email_address)))

        social_services, _ = MSocialServices.objects.get_or_create(user_id=request.user.pk)
        social_services.facebook_uid = uid
        social_services.facebook_access_token = access_token
        social_services.save()
        social_services.sync_facebook_friends()
        return {}
    elif request.REQUEST.get('error'):
        return {'error': '%s... Try connecting again.' % request.REQUEST.get('error')}
    else:
        # Start the OAuth process
        url = "https://www.facebook.com/dialog/oauth?" + urllib.urlencode(args)
        return {'next': url}
        
@ajax_login_required
def twitter_disconnect(request):
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    social_services.disconnect_twitter()
    return friends(request)

@ajax_login_required
def facebook_disconnect(request):
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    social_services.disconnect_facebook()
    return friends(request)