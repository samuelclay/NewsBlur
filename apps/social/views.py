import datetime
import zlib
import urllib
import urlparse
from django.shortcuts import get_object_or_404
from django.contrib.auth.decorators import login_required
from django.core.urlresolvers import reverse
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.http import HttpResponse, HttpResponseRedirect, Http404
from django.conf import settings
from apps.rss_feeds.models import MStory, Feed, MStarredStory
from apps.social.models import MSharedStory, MSocialServices, MSocialProfile, MSocialSubscription
from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds, apply_classifier_authors, apply_classifier_tags
from apps.reader.models import MUserStory, UserSubscription
from utils import json_functions as json
from utils import log as logging
from utils import PyRSS2Gen as RSS
from utils.user_functions import get_user, ajax_login_required
from utils.view_functions import render_to
from utils.story_functions import format_story_link_date__short
from utils.story_functions import format_story_link_date__long
from vendor import facebook
from vendor import tweepy
from vendor.timezones.utilities import localtime_for_timezone

@json.json_view
def load_social_stories(request, user_id, username=None):
    user = get_user(request)
    social_user_id = int(user_id)
    social_user = get_object_or_404(User, pk=social_user_id)
    offset = int(request.REQUEST.get('offset', 0))
    limit = int(request.REQUEST.get('limit', 6))
    page = request.REQUEST.get('page')
    if page: offset = limit * (int(page) - 1)
    now = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)

    mstories = MSharedStory.objects(user_id=social_user.pk).order_by('-shared_date')[offset:offset+limit]
    stories = Feed.format_stories(mstories)
    
    if not stories:
        return dict(stories=[])
        
    stories = MSharedStory.stories_with_comments(stories, user, check_all=True)

    story_feed_ids = list(set(s['story_feed_id'] for s in stories))
    socialsub = MSocialSubscription.objects.get(user_id=user.pk, subscription_user_id=social_user_id)
    usersubs = UserSubscription.objects.filter(user__pk=user.pk, feed__pk__in=story_feed_ids)
    usersubs_map = dict((sub.feed_id, sub) for sub in usersubs)
    unsub_feed_ids = list(set(story_feed_ids).difference(set(usersubs_map.keys())))
    unsub_feeds = Feed.objects.filter(pk__in=unsub_feed_ids)
    unsub_feeds = dict((feed.pk, feed.canonical(include_favicon=False)) for feed in unsub_feeds)
    
    # Get intelligence classifier for user
    # XXX TODO: Change all analyzers to use social feed ids instead of overlapping with feed ids. Ugh.
    classifier_feeds   = list(MClassifierFeed.objects(user_id=user.pk, feed_id=social_user_id))
    classifier_authors = list(MClassifierAuthor.objects(user_id=user.pk, feed_id=social_user_id))
    classifier_titles  = list(MClassifierTitle.objects(user_id=user.pk, feed_id=social_user_id))
    classifier_tags    = list(MClassifierTag.objects(user_id=user.pk, feed_id=social_user_id))
    
    story_ids = [story['id'] for story in stories]
    userstories_db = MUserStory.objects(user_id=user.pk,
                                        feed_id__in=story_feed_ids,
                                        story_id__in=story_ids).only('story_id')
    starred_stories = MStarredStory.objects(user_id=user.pk, 
                                            story_feed_id__in=story_feed_ids, 
                                            story_guid__in=story_ids).only('story_guid', 'starred_date')
    shared_stories = MSharedStory.objects(user_id=user.pk, 
                                          story_feed_id__in=story_feed_ids, 
                                          story_guid__in=story_ids)\
                                 .only('story_guid', 'shared_date', 'comments')
    starred_stories = dict([(story.story_guid, story.starred_date) for story in starred_stories])
    shared_stories = dict([(story.story_guid, dict(shared_date=story.shared_date, comments=story.comments))
                           for story in shared_stories])
    userstories = set(us.story_id for us in userstories_db)
    
    for story in stories:
        story['social_user_id'] = social_user_id
        story_feed_id = story['story_feed_id']
        story_date = localtime_for_timezone(story['story_date'], user.profile.timezone)
        story['short_parsed_date'] = format_story_link_date__short(story_date, now)
        story['long_parsed_date'] = format_story_link_date__long(story_date, now)
        shared_date = localtime_for_timezone(story['shared_date'], user.profile.timezone)
        story['shared_date'] = format_story_link_date__long(shared_date, now)
        if story['id'] in userstories:
            story['read_status'] = 1
        elif not usersubs_map.get(story_feed_id):
            story['read_status'] = 0
        elif not story.get('read_status') and story['story_date'] < usersubs_map[story_feed_id].mark_read_date:
            story['read_status'] = 1
        elif not story.get('read_status') and story['story_date'] > usersubs_map[story_feed_id].last_read_date:
            story['read_status'] = 0
        if story['id'] in starred_stories:
            story['starred'] = True
            starred_date = localtime_for_timezone(starred_stories[story['id']], user.profile.timezone)
            story['starred_date'] = format_story_link_date__long(starred_date, now)
        if story['id'] in shared_stories:
            story['shared'] = True
            shared_date = localtime_for_timezone(shared_stories[story['id']]['shared_date'], user.profile.timezone)
            story['shared_date'] = format_story_link_date__long(shared_date, now)
            story['shared_comments'] = shared_stories[story['id']]['comments']

        story['intelligence'] = {
            'feed': apply_classifier_feeds(classifier_feeds, social_user_id),
            'author': apply_classifier_authors(classifier_authors, story),
            'tags': apply_classifier_tags(classifier_tags, story),
            'title': apply_classifier_titles(classifier_titles, story),
        }
    
    logging.user(request, "~FCLoading shared stories: ~SB%s stories" % (len(stories)))
    
    return dict(stories=stories, feeds=unsub_feeds)

@render_to('social/social_page.xhtml')
def load_social_page(request, user_id, username=None):
    user = get_user(request)
    social_user_id = int(user_id)
    social_user = get_object_or_404(User, pk=social_user_id)
    offset = int(request.REQUEST.get('offset', 0))
    limit = int(request.REQUEST.get('limit', 12))
    page = request.REQUEST.get('page')
    if page: offset = limit * (int(page) - 1)
    now = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)
    
    mstories = MSharedStory.objects(user_id=social_user.pk).order_by('-shared_date')[offset:offset+limit]
    stories = Feed.format_stories(mstories)
    
    if not stories:
        return dict(stories=[])

    story_feed_ids = list(set(s['story_feed_id'] for s in stories))
    feeds = Feed.objects.filter(pk__in=story_feed_ids)
    feeds = dict((feed.pk, feed.canonical(include_favicon=False)) for feed in feeds)
    for story in stories:
        story['feed'] = feeds[story['story_feed_id']]
        shared_date = localtime_for_timezone(story['shared_date'], social_user.profile.timezone)
        story['shared_date'] = format_story_link_date__long(shared_date, now)
    
    stories = MSharedStory.stories_with_comments(stories, user, check_all=True)
    social_profile = MSocialProfile.objects.get(user_id=social_user_id)

    params = {
        'social_user': social_user,
        'stories': stories,
        'social_profile': social_profile.page(),
        'feeds': feeds,
    }
    
    return params
    
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
        story_values = dict(user_id=request.user.pk, comments=comments, 
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
    
    story = Feed.format_story(story)
    story = MSharedStory.stories_with_comments([story], request.user)[0]
    
    return {'code': code, 'story': story}
    
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
    
    social_params = {
        'user_id': request.user.pk,
        'subscription_user_id': follow_user_id,
        'include_favicon': True,
        'update_counts': True,
    }
    follow_subscription = MSocialSubscription.feeds(**social_params)
    
    return {
        "user_profile": profile.to_json(full=True), 
        "follow_profile": follow_profile,
        "follow_subscription": follow_subscription,
    }
    
@ajax_login_required
@json.json_view
def unfollow(request):
    unfollow_user_id = int(request.POST['user_id'])
    profile = MSocialProfile.objects.get(user_id=request.user.pk)
    profile.unfollow_user(unfollow_user_id)
    
    unfollow_profile = MSocialProfile.objects.get(user_id=unfollow_user_id)
    
    return dict(user_profile=profile.to_json(full=True), unfollow_profile=unfollow_profile)
    
def shared_stories_rss_feed(request, user_id, username):
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        raise Http404
    
    if user.username != username:
        params = {'username': user.username, 'user_id': user.pk}
        return HttpResponseRedirect(reverse('shared-stories-rss-feed', kwargs=params))

    social_profile = MSocialProfile.objects.get(user_id=user_id)

    data = {}
    data['title'] = social_profile.blog_title
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