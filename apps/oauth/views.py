import urllib
import urlparse
import datetime
import lxml.html
import tweepy
from django.contrib.auth.decorators import login_required
from django.core.urlresolvers import reverse
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.http import HttpResponseForbidden, HttpResponseRedirect
from django.conf import settings
from mongoengine.queryset import NotUniqueError
from mongoengine.queryset import OperationError
from apps.social.models import MSocialServices, MSocialSubscription, MSharedStory
from apps.social.tasks import SyncTwitterFriends, SyncFacebookFriends, SyncAppdotnetFriends
from apps.reader.models import UserSubscription, UserSubscriptionFolders, RUserStory
from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
from apps.analyzer.models import compute_story_score
from apps.rss_feeds.models import Feed, MStory, MStarredStoryCounts, MStarredStory
from apps.rss_feeds.text_importer import TextImporter
from utils import log as logging
from utils.user_functions import ajax_login_required, oauth_login_required
from utils.view_functions import render_to
from utils import urlnorm
from utils import json_functions as json
from vendor import facebook
from vendor import appdotnet

@login_required
@render_to('social/social_connect.xhtml')
def twitter_connect(request):
    twitter_consumer_key = settings.TWITTER_CONSUMER_KEY
    twitter_consumer_secret = settings.TWITTER_CONSUMER_SECRET
    
    oauth_token = request.REQUEST.get('oauth_token')
    oauth_verifier = request.REQUEST.get('oauth_verifier')
    denied = request.REQUEST.get('denied')
    if denied:
        logging.user(request, "~BB~FRDenied Twitter connect")
        return {'error': 'Denied! Try connecting again.'}
    elif oauth_token and oauth_verifier:
        try:
            auth = tweepy.OAuthHandler(twitter_consumer_key, twitter_consumer_secret)
            auth.request_token = request.session['twitter_request_token']
            # auth.set_request_token(oauth_token, oauth_verifier)
            auth.get_access_token(oauth_verifier)
            api = tweepy.API(auth)
            twitter_user = api.me()
        except (tweepy.TweepError, IOError), e:
            logging.user(request, "~BB~FRFailed Twitter connect: %s" % e)
            return dict(error="Twitter has returned an error. Try connecting again.")

        # Be sure that two people aren't using the same Twitter account.
        existing_user = MSocialServices.objects.filter(twitter_uid=unicode(twitter_user.id))
        if existing_user and existing_user[0].user_id != request.user.pk:
            try:
                user = User.objects.get(pk=existing_user[0].user_id)
                logging.user(request, "~BB~FRFailed Twitter connect, another user: %s" % user.username)
                return dict(error=("Another user (%s, %s) has "
                                   "already connected with those Twitter credentials."
                                   % (user.username, user.email or "no email")))
            except User.DoesNotExist:
                existing_user.delete()

        social_services = MSocialServices.get_user(request.user.pk)
        social_services.twitter_uid = unicode(twitter_user.id)
        social_services.twitter_access_key = auth.access_token
        social_services.twitter_access_secret = auth.access_token_secret
        social_services.syncing_twitter = True
        social_services.save()

        SyncTwitterFriends.delay(user_id=request.user.pk)
        
        logging.user(request, "~BB~FRFinishing Twitter connect")
        return {}
    else:
        # Start the OAuth process
        auth = tweepy.OAuthHandler(twitter_consumer_key, twitter_consumer_secret)
        auth_url = auth.get_authorization_url()
        request.session['twitter_request_token'] = auth.request_token
        logging.user(request, "~BB~FRStarting Twitter connect: %s" % auth.request_token)
        return {'next': auth_url}


@login_required
@render_to('social/social_connect.xhtml')
def facebook_connect(request):
    facebook_app_id = settings.FACEBOOK_APP_ID
    facebook_secret = settings.FACEBOOK_SECRET
    
    args = {
        "client_id": facebook_app_id,
        "redirect_uri": "http://" + Site.objects.get_current().domain + reverse('facebook-connect'),
        "scope": "user_website,user_friends,publish_actions",
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
            logging.user(request, "~BB~FRFailed Facebook connect")
            return dict(error="Facebook has returned an error. Try connecting again.")

        access_token = response["access_token"][-1]

        # Get the user's profile.
        graph = facebook.GraphAPI(access_token)
        profile = graph.get_object("me")
        uid = profile["id"]

        # Be sure that two people aren't using the same Facebook account.
        existing_user = MSocialServices.objects.filter(facebook_uid=uid)
        if existing_user and existing_user[0].user_id != request.user.pk:
            try:
                user = User.objects.get(pk=existing_user[0].user_id)
                logging.user(request, "~BB~FRFailed FB connect, another user: %s" % user.username)
                return dict(error=("Another user (%s, %s) has "
                                   "already connected with those Facebook credentials."
                                   % (user.username, user.email or "no email")))
            except User.DoesNotExist:
                existing_user.delete()

        social_services = MSocialServices.get_user(request.user.pk)
        social_services.facebook_uid = uid
        social_services.facebook_access_token = access_token
        social_services.syncing_facebook = True
        social_services.save()
        
        SyncFacebookFriends.delay(user_id=request.user.pk)
        
        logging.user(request, "~BB~FRFinishing Facebook connect")
        return {}
    elif request.REQUEST.get('error'):
        logging.user(request, "~BB~FRFailed Facebook connect")
        return {'error': '%s... Try connecting again.' % request.REQUEST.get('error')}
    else:
        # Start the OAuth process
        logging.user(request, "~BB~FRStarting Facebook connect")
        url = "https://www.facebook.com/dialog/oauth?" + urllib.urlencode(args)
        return {'next': url}

@login_required
@render_to('social/social_connect.xhtml')
def appdotnet_connect(request):
    domain = Site.objects.get_current().domain
    args = {
        "client_id": settings.APPDOTNET_CLIENTID,
        "client_secret": settings.APPDOTNET_SECRET,
        "redirect_uri": "http://" + domain +
                                    reverse('appdotnet-connect'),
        "scope": ["email", "write_post", "follow"],
    }

    oauth_code = request.REQUEST.get('code')
    denied = request.REQUEST.get('denied')
    if denied:
        logging.user(request, "~BB~FRDenied App.net connect")
        return {'error': 'Denied! Try connecting again.'}
    elif oauth_code:
        try:
            adn_auth = appdotnet.Appdotnet(**args)
            response = adn_auth.getAuthResponse(oauth_code)
            adn_resp = json.decode(response)
            access_token = adn_resp['access_token']
            adn_userid = adn_resp['user_id']
        except (IOError):
            logging.user(request, "~BB~FRFailed App.net connect")
            return dict(error="App.net has returned an error. Try connecting again.")

        # Be sure that two people aren't using the same Twitter account.
        existing_user = MSocialServices.objects.filter(appdotnet_uid=unicode(adn_userid))
        if existing_user and existing_user[0].user_id != request.user.pk:
            try:
                user = User.objects.get(pk=existing_user[0].user_id)
                logging.user(request, "~BB~FRFailed App.net connect, another user: %s" % user.username)
                return dict(error=("Another user (%s, %s) has "
                                   "already connected with those App.net credentials."
                                   % (user.username, user.email or "no email")))
            except User.DoesNotExist:
                existing_user.delete()
        
        social_services = MSocialServices.get_user(request.user.pk)
        social_services.appdotnet_uid = unicode(adn_userid)
        social_services.appdotnet_access_token = access_token
        social_services.syncing_appdotnet = True
        social_services.save()
        
        SyncAppdotnetFriends.delay(user_id=request.user.pk)
        
        logging.user(request, "~BB~FRFinishing App.net connect")
        return {}
    else:
        # Start the OAuth process
        adn_auth = appdotnet.Appdotnet(**args)
        auth_url = adn_auth.generateAuthUrl()
        logging.user(request, "~BB~FRStarting App.net connect")
        return {'next': auth_url}

@ajax_login_required
def twitter_disconnect(request):
    logging.user(request, "~BB~FRDisconnecting Twitter")
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    social_services.disconnect_twitter()
    
    return HttpResponseRedirect(reverse('load-user-friends'))

@ajax_login_required
def facebook_disconnect(request):
    logging.user(request, "~BB~FRDisconnecting Facebook")
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    social_services.disconnect_facebook()
    
    return HttpResponseRedirect(reverse('load-user-friends'))
    
@ajax_login_required
def appdotnet_disconnect(request):
    logging.user(request, "~BB~FRDisconnecting App.net")
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    social_services.disconnect_appdotnet()
    
    return HttpResponseRedirect(reverse('load-user-friends'))
    
@ajax_login_required
@json.json_view
def follow_twitter_account(request):
    username = request.POST['username']
    code = 1
    message = "OK"
    
    logging.user(request, "~BB~FR~SKFollowing Twitter: %s" % username)
    
    if username not in ['samuelclay', 'newsblur']:
        return HttpResponseForbidden()
    
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    try:
        api = social_services.twitter_api()
        api.create_friendship(username)
    except tweepy.TweepError, e:
        code = -1
        message = e
        
    return {'code': code, 'message': message}
    
@ajax_login_required
@json.json_view
def unfollow_twitter_account(request):
    username = request.POST['username']
    code = 1
    message = "OK"
    
    logging.user(request, "~BB~FRUnfollowing Twitter: %s" % username)
        
    if username not in ['samuelclay', 'newsblur']:
        return HttpResponseForbidden()
    
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    try:
        api = social_services.twitter_api()
        api.destroy_friendship(username)
    except tweepy.TweepError, e:
        code = -1
        message = e
    
    return {'code': code, 'message': message}

@oauth_login_required
def api_user_info(request):
    user = request.user
    
    return json.json_response(request, {"data": {
        "name": user.username,
        "id": user.pk,
    }})
    
@oauth_login_required
@json.json_view
def api_feed_list(request, trigger_slug=None):
    user = request.user
    usf = UserSubscriptionFolders.objects.get(user=user)
    flat_folders = usf.flatten_folders()
    titles = [dict(label=" - Folder: All Site Stories", value="all")]
    feeds = {}
    
    user_subs = UserSubscription.objects.select_related('feed').filter(user=user, active=True)    
    
    for sub in user_subs:
        feeds[sub.feed_id] = sub.canonical()
    
    for folder_title in sorted(flat_folders.keys()):
        if folder_title and folder_title != " ":
            titles.append(dict(label=" - Folder: %s" % folder_title, value=folder_title, optgroup=True))
        else:
            titles.append(dict(label=" - Folder: Top Level", value="Top Level", optgroup=True))
        folder_contents = []
        for feed_id in flat_folders[folder_title]:
            if feed_id not in feeds: continue
            feed = feeds[feed_id]
            folder_contents.append(dict(label=feed['feed_title'], value=str(feed['id'])))
        folder_contents = sorted(folder_contents, key=lambda f: f['label'].lower())
        titles.extend(folder_contents)
        
    return {"data": titles}
    
@oauth_login_required
@json.json_view
def api_folder_list(request, trigger_slug=None):
    user = request.user
    usf = UserSubscriptionFolders.objects.get(user=user)
    flat_folders = usf.flatten_folders()
    if 'add-new-subscription' in request.path:
        titles = []
    else:
        titles = [dict(label="All Site Stories", value="all")]
    
    for folder_title in sorted(flat_folders.keys()):
        if folder_title and folder_title != " ":
            titles.append(dict(label=folder_title, value=folder_title))
        else:
            titles.append(dict(label="Top Level", value="Top Level"))
        
    return {"data": titles}

@oauth_login_required
@json.json_view
def api_saved_tag_list(request):
    user = request.user
    starred_counts, starred_count = MStarredStoryCounts.user_counts(user.pk, include_total=True)
    tags = []
    
    for tag in starred_counts:
        if not tag['tag'] or tag['tag'] == "": continue
        tags.append(dict(label="%s (%s %s)" % (tag['tag'], tag['count'], 
                                               'story' if tag['count'] == 1 else 'stories'),
                         value=tag['tag']))
    tags = sorted(tags, key=lambda t: t['value'].lower())
    catchall = dict(label="All Saved Stories (%s %s)" % (starred_count,
                                                         'story' if starred_count == 1 else 'stories'),
                    value="all")
    tags.insert(0, catchall)
    
    return {"data": tags}

@oauth_login_required
@json.json_view
def api_shared_usernames(request):
    user = request.user
    social_feeds = MSocialSubscription.feeds(user_id=user.pk)
    blurblogs = []

    for social_feed in social_feeds:
        if not social_feed['shared_stories_count']: continue
        blurblogs.append(dict(label="%s (%s %s)" % (social_feed['username'],
                                                    social_feed['shared_stories_count'], 
                                                    'story' if social_feed['shared_stories_count'] == 1 else 'stories'),
                         value="%s" % social_feed['user_id']))
    blurblogs = sorted(blurblogs, key=lambda b: b['label'].lower())
    catchall = dict(label="All Shared Stories",
                    value="all")
    blurblogs.insert(0, catchall)
    
    return {"data": blurblogs}

@oauth_login_required
@json.json_view
def api_unread_story(request, trigger_slug=None):
    user = request.user
    body = request.body_json
    after = body.get('after', None)
    before = body.get('before', None)
    limit = body.get('limit', 50)
    fields = body.get('triggerFields')
    feed_or_folder = fields['feed_or_folder']
    entries = []

    if isinstance(feed_or_folder, int) or feed_or_folder.isdigit():
        feed_id = int(feed_or_folder)
        try:
            usersub = UserSubscription.objects.get(user=user, feed_id=feed_id)
        except UserSubscription.DoesNotExist:
            return dict(data=[])
        found_feed_ids = [feed_id]
        found_trained_feed_ids = [feed_id] if usersub.is_trained else []
        stories = usersub.get_stories(order="newest", read_filter="unread", 
                                      offset=0, limit=limit,
                                      default_cutoff_date=user.profile.unread_cutoff)
    else:
        folder_title = feed_or_folder
        if folder_title == "Top Level":
            folder_title = " "
        usf = UserSubscriptionFolders.objects.get(user=user)
        flat_folders = usf.flatten_folders()
        feed_ids = None
        if folder_title != "all":
            feed_ids = flat_folders.get(folder_title)
        usersubs = UserSubscription.subs_for_feeds(user.pk, feed_ids=feed_ids,
                                                   read_filter="unread")
        feed_ids = [sub.feed_id for sub in usersubs]
        params = {
            "user_id": user.pk, 
            "feed_ids": feed_ids,
            "offset": 0,
            "limit": limit,
            "order": "newest",
            "read_filter": "unread",
            "usersubs": usersubs,
            "cutoff_date": user.profile.unread_cutoff,
        }
        story_hashes, unread_feed_story_hashes = UserSubscription.feed_stories(**params)
        mstories = MStory.objects(story_hash__in=story_hashes).order_by('-story_date')
        stories = Feed.format_stories(mstories)
        found_feed_ids = list(set([story['story_feed_id'] for story in stories]))
        trained_feed_ids = [sub.feed_id for sub in usersubs if sub.is_trained]
        found_trained_feed_ids = list(set(trained_feed_ids) & set(found_feed_ids))
    
    if found_trained_feed_ids:
        classifier_feeds = list(MClassifierFeed.objects(user_id=user.pk,
                                                        feed_id__in=found_trained_feed_ids))
        classifier_authors = list(MClassifierAuthor.objects(user_id=user.pk, 
                                                            feed_id__in=found_trained_feed_ids))
        classifier_titles = list(MClassifierTitle.objects(user_id=user.pk, 
                                                          feed_id__in=found_trained_feed_ids))
        classifier_tags = list(MClassifierTag.objects(user_id=user.pk, 
                                                      feed_id__in=found_trained_feed_ids))
    feeds = dict([(f.pk, {
        "title": f.feed_title,
        "website": f.feed_link,
        "address": f.feed_address,
    }) for f in Feed.objects.filter(pk__in=found_feed_ids)])

    for story in stories:
        if before and int(story['story_date'].strftime("%s")) > before: continue
        if after and int(story['story_date'].strftime("%s")) < after: continue
        score = 0
        if found_trained_feed_ids and story['story_feed_id'] in found_trained_feed_ids:
            score = compute_story_score(story, classifier_titles=classifier_titles, 
                                        classifier_authors=classifier_authors, 
                                        classifier_tags=classifier_tags,
                                        classifier_feeds=classifier_feeds)
            if score < 0: continue
            if trigger_slug == "new-unread-focus-story" and score < 1: continue
        feed = feeds.get(story['story_feed_id'], None)
        entries.append({
            "StoryTitle": story['story_title'],
            "StoryContent": story['story_content'],
            "StoryURL": story['story_permalink'],
            "StoryAuthor": story['story_authors'],
            "PublishedAt": story['story_date'].strftime("%Y-%m-%dT%H:%M:%SZ"),
            "StoryScore": score,
            "Site": feed and feed['title'],
            "SiteURL": feed and feed['website'],
            "SiteRSS": feed and feed['address'],
            "meta": {
                "id": story['story_hash'],
                "timestamp": int(story['story_date'].strftime("%s"))
            },
        })
    
    if after:
        entries = sorted(entries, key=lambda s: s['meta']['timestamp'])
        
    logging.user(request, "~FYChecking unread%s stories with ~SB~FCIFTTT~SN~FY: ~SB%s~SN - ~SB%s~SN stories" % (" ~SBfocus~SN" if trigger_slug == "new-unread-focus-story" else "", feed_or_folder, len(entries)))
    
    return {"data": entries[:limit]}

@oauth_login_required
@json.json_view
def api_saved_story(request):
    user = request.user
    body = request.body_json
    after = body.get('after', None)
    before = body.get('before', None)
    limit = body.get('limit', 50)
    fields = body.get('triggerFields')
    story_tag = fields['story_tag']
    entries = []
    
    if story_tag == "all":
        story_tag = ""
    
    params = dict(user_id=user.pk)
    if story_tag:
        params.update(dict(user_tags__contains=story_tag))
    mstories = MStarredStory.objects(**params).order_by('-starred_date')[:limit]
    stories = Feed.format_stories(mstories)        
    
    found_feed_ids = list(set([story['story_feed_id'] for story in stories]))
    feeds = dict([(f.pk, {
        "title": f.feed_title,
        "website": f.feed_link,
        "address": f.feed_address,
    }) for f in Feed.objects.filter(pk__in=found_feed_ids)])

    for story in stories:
        if before and int(story['story_date'].strftime("%s")) > before: continue
        if after and int(story['story_date'].strftime("%s")) < after: continue
        feed = feeds.get(story['story_feed_id'], None)
        entries.append({
            "StoryTitle": story['story_title'],
            "StoryContent": story['story_content'],
            "StoryURL": story['story_permalink'],
            "StoryAuthor": story['story_authors'],
            "PublishedAt": story['story_date'].strftime("%Y-%m-%dT%H:%M:%SZ"),
            "SavedAt": story['starred_date'].strftime("%Y-%m-%dT%H:%M:%SZ"),
            "Tags": ', '.join(story['user_tags']),
            "Site": feed and feed['title'],
            "SiteURL": feed and feed['website'],
            "SiteRSS": feed and feed['address'],
            "meta": {
                "id": story['story_hash'],
                "timestamp": int(story['starred_date'].strftime("%s"))
            },
        })

    if after:
        entries = sorted(entries, key=lambda s: s['meta']['timestamp'])
        
    logging.user(request, "~FCChecking saved stories from ~SBIFTTT~SB: ~SB%s~SN - ~SB%s~SN stories" % (story_tag if story_tag else "[All stories]", len(entries)))
    
    return {"data": entries}
    
@oauth_login_required
@json.json_view
def api_shared_story(request):
    user = request.user
    body = request.body_json
    after = body.get('after', None)
    before = body.get('before', None)
    limit = body.get('limit', 50)
    fields = body.get('triggerFields')
    blurblog_user = fields['blurblog_user']
    entries = []
    
    if isinstance(blurblog_user, int) or blurblog_user.isdigit():
        social_user_ids = [int(blurblog_user)]
    elif blurblog_user == "all":
        socialsubs = MSocialSubscription.objects.filter(user_id=user.pk)
        social_user_ids = [ss.subscription_user_id for ss in socialsubs]

    mstories = MSharedStory.objects(
        user_id__in=social_user_ids
    ).order_by('-shared_date')[:limit]        
    stories = Feed.format_stories(mstories)
    
    found_feed_ids = list(set([story['story_feed_id'] for story in stories]))
    share_user_ids = list(set([story['user_id'] for story in stories]))
    users = dict([(u.pk, u.username) 
                 for u in User.objects.filter(pk__in=share_user_ids).only('pk', 'username')])
    feeds = dict([(f.pk, {
        "title": f.feed_title,
        "website": f.feed_link,
        "address": f.feed_address,
    }) for f in Feed.objects.filter(pk__in=found_feed_ids)])
    
    classifier_feeds   = list(MClassifierFeed.objects(user_id=user.pk, 
                                                      social_user_id__in=social_user_ids))
    classifier_authors = list(MClassifierAuthor.objects(user_id=user.pk,
                                                        social_user_id__in=social_user_ids))
    classifier_titles  = list(MClassifierTitle.objects(user_id=user.pk,
                                                       social_user_id__in=social_user_ids))
    classifier_tags    = list(MClassifierTag.objects(user_id=user.pk, 
                                                     social_user_id__in=social_user_ids))
    # Merge with feed specific classifiers
    classifier_feeds   = classifier_feeds + list(MClassifierFeed.objects(user_id=user.pk,
                                                                         feed_id__in=found_feed_ids))
    classifier_authors = classifier_authors + list(MClassifierAuthor.objects(user_id=user.pk,
                                                                             feed_id__in=found_feed_ids))
    classifier_titles  = classifier_titles + list(MClassifierTitle.objects(user_id=user.pk,
                                                                           feed_id__in=found_feed_ids))
    classifier_tags    = classifier_tags + list(MClassifierTag.objects(user_id=user.pk,
                                                                       feed_id__in=found_feed_ids))
        
    for story in stories:
        if before and int(story['shared_date'].strftime("%s")) > before: continue
        if after and int(story['shared_date'].strftime("%s")) < after: continue
        score = compute_story_score(story, classifier_titles=classifier_titles, 
                                    classifier_authors=classifier_authors, 
                                    classifier_tags=classifier_tags,
                                    classifier_feeds=classifier_feeds)
        if score < 0: continue
        feed = feeds.get(story['story_feed_id'], None)
        entries.append({
            "StoryTitle": story['story_title'],
            "StoryContent": story['story_content'],
            "StoryURL": story['story_permalink'],
            "StoryAuthor": story['story_authors'],
            "PublishedAt": story['story_date'].strftime("%Y-%m-%dT%H:%M:%SZ"),
            "StoryScore": score,
            "Comments": story['comments'],
            "Username": users.get(story['user_id']),
            "SharedAt": story['shared_date'].strftime("%Y-%m-%dT%H:%M:%SZ"),
            "Site": feed and feed['title'],
            "SiteURL": feed and feed['website'],
            "SiteRSS": feed and feed['address'],
            "meta": {
                "id": story['story_hash'],
                "timestamp": int(story['shared_date'].strftime("%s"))
            },
        })

    if after:
        entries = sorted(entries, key=lambda s: s['meta']['timestamp'])
        
    logging.user(request, "~FMChecking shared stories from ~SB~FCIFTTT~SN~FM: ~SB~FM%s~FM~SN - ~SB%s~SN stories" % (blurblog_user, len(entries)))

    return {"data": entries}

@json.json_view
def ifttt_status(request):
    logging.user(request, "~FCChecking ~SBIFTTT~SN status")

    return {"data": {
        "status": "OK",
        "time": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    }}

@oauth_login_required
@json.json_view
def api_share_new_story(request):
    user = request.user
    body = request.body_json
    fields = body.get('actionFields')
    story_url = urlnorm.normalize(fields['story_url'])
    story_content = fields.get('story_content', "")
    story_title = fields.get('story_title', "")
    story_author = fields.get('story_author', "")
    comments = fields.get('comments', None)
        
    logging.user(request.user, "~FBFinding feed (api_share_new_story): %s" % story_url)
    original_feed = Feed.get_feed_from_url(story_url, create=True, fetch=True)
    story_hash = MStory.guid_hash_unsaved(story_url)
    if not user.profile.is_premium and MSharedStory.feed_quota(user.pk, original_feed and original_feed.pk or 0, story_hash):
        return {"errors": [{
            'message': 'Only premium users can share multiple stories per day from the same site.'
        }]}
        
    if not story_content or not story_title:
        ti = TextImporter(feed=original_feed, story_url=story_url, request=request)
        original_story = ti.fetch(return_document=True)
        if original_story:
            story_url = original_story['url']
            if not story_content:
                story_content = original_story['content']
            if not story_title:
                story_title = original_story['title']
    
    if story_content:
        story_content = lxml.html.fromstring(story_content)
        story_content.make_links_absolute(story_url)
        story_content = lxml.html.tostring(story_content)
    
    shared_story = MSharedStory.objects.filter(user_id=user.pk,
                                               story_feed_id=original_feed and original_feed.pk or 0,
                                               story_guid=story_url).limit(1).first()
    if not shared_story:
        title_max = MSharedStory._fields['story_title'].max_length
        story_db = {
            "story_guid": story_url,
            "story_permalink": story_url,
            "story_title": story_title and story_title[:title_max] or "[Untitled]",
            "story_feed_id": original_feed and original_feed.pk or 0,
            "story_content": story_content,
            "story_author": story_author,
            "story_date": datetime.datetime.now(),
            "user_id": user.pk,
            "comments": comments,
            "has_comments": bool(comments),
        }
        try:
            shared_story = MSharedStory.objects.create(**story_db)
            socialsubs = MSocialSubscription.objects.filter(subscription_user_id=user.pk)
            for socialsub in socialsubs:
                socialsub.needs_unread_recalc = True
                socialsub.save()
            logging.user(request, "~BM~FYSharing story from ~SB~FCIFTTT~FY: ~SB%s: %s" % (story_url, comments))
        except NotUniqueError:
            logging.user(request, "~BM~FY~SBAlready~SN shared story from ~SB~FCIFTTT~FY: ~SB%s: %s" % (story_url, comments))
    else:
        logging.user(request, "~BM~FY~SBAlready~SN shared story from ~SB~FCIFTTT~FY: ~SB%s: %s" % (story_url, comments))
    
    try:
        socialsub = MSocialSubscription.objects.get(user_id=user.pk, 
                                                    subscription_user_id=user.pk)
    except MSocialSubscription.DoesNotExist:
        socialsub = None
    
    if socialsub and shared_story:
        socialsub.mark_story_ids_as_read([shared_story.story_hash], 
                                          shared_story.story_feed_id, 
                                          request=request)
    elif shared_story:
        RUserStory.mark_read(user.pk, shared_story.story_feed_id, shared_story.story_hash)
    
    if shared_story:
        shared_story.publish_update_to_subscribers()
    
    return {"data": [{
        "id": shared_story and shared_story.story_guid,
        "url": shared_story and shared_story.blurblog_permalink()
    }]}

@oauth_login_required
@json.json_view
def api_save_new_story(request):
    user = request.user
    body = request.body_json
    fields = body.get('actionFields')
    story_url = urlnorm.normalize(fields['story_url'])
    story_content = fields.get('story_content', "")
    story_title = fields.get('story_title', "")
    story_author = fields.get('story_author', "")
    user_tags = fields.get('user_tags', "")
    story = None
    
    logging.user(request.user, "~FBFinding feed (api_save_new_story): %s" % story_url)
    original_feed = Feed.get_feed_from_url(story_url)
    if not story_content or not story_title:
        ti = TextImporter(feed=original_feed, story_url=story_url, request=request)
        original_story = ti.fetch(return_document=True)
        if original_story:
            story_url = original_story['url']
            if not story_content:
                story_content = original_story['content']
            if not story_title:
                story_title = original_story['title']
    try:
        story_db = {
            "user_id": user.pk,
            "starred_date": datetime.datetime.now(),
            "story_date": datetime.datetime.now(),
            "story_title": story_title or '[Untitled]',
            "story_permalink": story_url,
            "story_guid": story_url,
            "story_content": story_content,
            "story_author_name": story_author,
            "story_feed_id": original_feed and original_feed.pk or 0,
            "user_tags": [tag for tag in user_tags.split(',')]
        }
        story = MStarredStory.objects.create(**story_db)
        logging.user(request, "~FCStarring by ~SBIFTTT~SN: ~SB%s~SN in ~SB%s" % (story_db['story_title'][:50], original_feed and original_feed))
        MStarredStoryCounts.count_for_user(user.pk)
    except OperationError:
        logging.user(request, "~FCAlready starred by ~SBIFTTT~SN: ~SB%s" % (story_db['story_title'][:50]))
        pass
    
    return {"data": [{
        "id": story and story.id,
        "url": story and story.story_permalink
    }]}

@oauth_login_required
@json.json_view
def api_save_new_subscription(request):
    user = request.user
    body = request.body_json
    fields = body.get('actionFields')
    url = urlnorm.normalize(fields['url'])
    folder = fields['folder']
    
    if folder == "Top Level":
        folder = " "
    
    code, message, us = UserSubscription.add_subscription(
        user=user, 
        feed_address=url,
        folder=folder,
        bookmarklet=True
    )
    
    logging.user(request, "~FRAdding URL from ~FC~SBIFTTT~SN~FR: ~SB%s (in %s)" % (url, folder))

    if us and us.feed:
        url = us.feed.feed_address

    return {"data": [{
        "id": us and us.feed_id,
        "url": url,
    }]}
