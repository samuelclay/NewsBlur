"""OAuth views: authentication flows for connecting to social media platforms."""

import datetime
import urllib.error
import urllib.parse
import urllib.request

import lxml.html
import tweepy
from django.conf import settings
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.http import HttpResponseForbidden, HttpResponseRedirect
from django.urls import reverse
from django.utils.http import url_has_allowed_host_and_scheme
from mongoengine.queryset import NotUniqueError, OperationError
from oauth2_provider.views import AuthorizationView as BaseAuthorizationView

from apps.analyzer.models import (
    MClassifierAuthor,
    MClassifierFeed,
    MClassifierTag,
    MClassifierText,
    MClassifierTitle,
    MClassifierUrl,
    compute_story_score,
)
from apps.reader.models import RUserStory, UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.models import Feed, MStarredStory, MStarredStoryCounts, MStory
from apps.rss_feeds.text_importer import TextImporter
from apps.social.models import MSharedStory, MSocialServices, MSocialSubscription
from apps.social.tasks import SyncFacebookFriends, SyncTwitterFriends
from utils import json_functions as json
from utils import log as logging
from utils import urlnorm
from utils.user_functions import ajax_login_required, oauth_login_required
from utils.view_functions import render_to
from vendor import facebook


@login_required
@render_to("social/social_connect.xhtml")
def twitter_connect(request):
    twitter_consumer_key = settings.TWITTER_CONSUMER_KEY
    twitter_consumer_secret = settings.TWITTER_CONSUMER_SECRET

    oauth_token = request.GET.get("oauth_token")
    oauth_verifier = request.GET.get("oauth_verifier")
    denied = request.GET.get("denied")
    if denied:
        logging.user(request, "~BB~FRDenied Twitter connect")
        return {"error": "Denied! Try connecting again."}
    elif oauth_token and oauth_verifier:
        try:
            auth = tweepy.OAuthHandler(twitter_consumer_key, twitter_consumer_secret)
            auth.request_token = request.session["twitter_request_token"]
            # auth.set_request_token(oauth_token, oauth_verifier)
            auth.get_access_token(oauth_verifier)
            api = tweepy.API(auth)
            twitter_user = api.me()
        except (tweepy.TweepError, IOError) as e:
            logging.user(request, "~BB~FRFailed Twitter connect: %s" % e)
            return dict(error="Twitter has returned an error. Try connecting again.")

        # Be sure that two people aren't using the same Twitter account.
        existing_user = MSocialServices.objects.filter(twitter_uid=str(twitter_user.id))
        if existing_user and existing_user[0].user_id != request.user.pk:
            try:
                user = User.objects.get(pk=existing_user[0].user_id)
                logging.user(request, "~BB~FRFailed Twitter connect, another user: %s" % user.username)
                return dict(
                    error=(
                        "Another user (%s, %s) has "
                        "already connected with those Twitter credentials."
                        % (user.username, user.email or "no email")
                    )
                )
            except User.DoesNotExist:
                existing_user.delete()

        social_services = MSocialServices.get_user(request.user.pk)
        social_services.twitter_uid = str(twitter_user.id)
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
        request.session["twitter_request_token"] = auth.request_token
        logging.user(request, "~BB~FRStarting Twitter connect: %s" % auth.request_token)
        return {"next": auth_url}


@login_required
@render_to("social/social_connect.xhtml")
def facebook_connect(request):
    facebook_app_id = settings.FACEBOOK_APP_ID
    facebook_secret = settings.FACEBOOK_SECRET

    args = {
        "client_id": facebook_app_id,
        "redirect_uri": "https://" + Site.objects.get_current().domain + "/oauth/facebook_connect",
        "scope": "user_friends",
        "display": "popup",
    }

    verification_code = request.GET.get("code")
    if verification_code:
        args["client_secret"] = facebook_secret
        args["code"] = verification_code
        uri = "https://graph.facebook.com/oauth/access_token?" + urllib.parse.urlencode(args)
        response_text = urllib.request.urlopen(uri).read()
        response = json.decode(response_text)

        if "access_token" not in response:
            logging.user(
                request, "~BB~FRFailed Facebook connect, no access_token. (%s): %s" % (args, response)
            )
            return dict(error="Facebook has returned an error. Try connecting again.")

        access_token = response["access_token"]

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
                return dict(
                    error=(
                        "Another user (%s, %s) has "
                        "already connected with those Facebook credentials."
                        % (user.username, user.email or "no email")
                    )
                )
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
    elif request.GET.get("error"):
        logging.user(request, "~BB~FRFailed Facebook connect, error: %s" % request.GET.get("error"))
        return {"error": "%s... Try connecting again." % request.GET.get("error")}
    else:
        # Start the OAuth process
        logging.user(request, "~BB~FRStarting Facebook connect")
        url = "https://www.facebook.com/dialog/oauth?" + urllib.parse.urlencode(args)
        return {"next": url}


@ajax_login_required
def twitter_disconnect(request):
    logging.user(request, "~BB~FRDisconnecting Twitter")
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    social_services.disconnect_twitter()

    return HttpResponseRedirect(reverse("load-user-friends"))


@ajax_login_required
def facebook_disconnect(request):
    logging.user(request, "~BB~FRDisconnecting Facebook")
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    social_services.disconnect_facebook()

    return HttpResponseRedirect(reverse("load-user-friends"))


@ajax_login_required
@json.json_view
def follow_twitter_account(request):
    username = request.POST["username"]
    code = 1
    message = "OK"

    logging.user(request, "~BB~FR~SKFollowing Twitter: %s" % username)

    if username not in ["samuelclay", "newsblur"]:
        return HttpResponseForbidden()

    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    try:
        api = social_services.twitter_api()
        api.create_friendship(username)
    except tweepy.TweepError as e:
        code = -1
        message = e

    return {"code": code, "message": message}


@ajax_login_required
@json.json_view
def unfollow_twitter_account(request):
    username = request.POST["username"]
    code = 1
    message = "OK"

    logging.user(request, "~BB~FRUnfollowing Twitter: %s" % username)

    if username not in ["samuelclay", "newsblur"]:
        return HttpResponseForbidden()

    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    try:
        api = social_services.twitter_api()
        api.destroy_friendship(username)
    except tweepy.TweepError as e:
        code = -1
        message = e

    return {"code": code, "message": message}


@oauth_login_required
def api_user_info(request):
    user = request.user

    return json.json_response(
        request,
        {
            "data": {
                "name": user.username,
                "id": user.pk,
                "email": user.email,
            }
        },
    )


@oauth_login_required
@json.json_view
def api_feed_list(request, trigger_slug=None):
    user = request.user
    try:
        usf = UserSubscriptionFolders.objects.get(user=user)
    except UserSubscriptionFolders.DoesNotExist:
        return {"errors": [{"message": "Could not find feeds for user."}]}
    flat_folders = usf.flatten_folders()
    titles = [dict(label=" - Folder: All Site Stories", value="all")]
    feeds = {}

    user_subs = UserSubscription.objects.select_related("feed").filter(user=user, active=True)

    for sub in user_subs:
        feeds[sub.feed_id] = sub.canonical()

    for folder_title in sorted(flat_folders.keys()):
        if folder_title and folder_title != " ":
            titles.append(dict(label=" - Folder: %s" % folder_title, value=folder_title, optgroup=True))
        else:
            titles.append(dict(label=" - Folder: Top Level", value="Top Level", optgroup=True))
        folder_contents = []
        for feed_id in flat_folders[folder_title]:
            if feed_id not in feeds:
                continue
            feed = feeds[feed_id]
            folder_contents.append(dict(label=feed["feed_title"], value=str(feed["id"])))
        folder_contents = sorted(folder_contents, key=lambda f: f["label"].lower())
        titles.extend(folder_contents)

    return {"data": titles}


@oauth_login_required
@json.json_view
def api_folder_list(request, trigger_slug=None):
    user = request.user
    usf = UserSubscriptionFolders.objects.get(user=user)
    flat_folders = usf.flatten_folders()
    if "add-new-subscription" in request.path:
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
        if not tag["tag"] or tag["tag"] == "":
            continue
        tags.append(
            dict(
                label="%s (%s %s)" % (tag["tag"], tag["count"], "story" if tag["count"] == 1 else "stories"),
                value=tag["tag"],
            )
        )
    tags = sorted(tags, key=lambda t: t["value"].lower())
    catchall = dict(
        label="All Saved Stories (%s %s)" % (starred_count, "story" if starred_count == 1 else "stories"),
        value="all",
    )
    tags.insert(0, catchall)

    return {"data": tags}


@oauth_login_required
@json.json_view
def api_shared_usernames(request):
    user = request.user
    social_feeds = MSocialSubscription.feeds(user_id=user.pk)
    blurblogs = []

    for social_feed in social_feeds:
        if not social_feed["shared_stories_count"]:
            continue
        blurblogs.append(
            dict(
                label="%s (%s %s)"
                % (
                    social_feed["username"],
                    social_feed["shared_stories_count"],
                    "story" if social_feed["shared_stories_count"] == 1 else "stories",
                ),
                value="%s" % social_feed["user_id"],
            )
        )
    blurblogs = sorted(blurblogs, key=lambda b: b["label"].lower())
    catchall = dict(label="All Shared Stories", value="all")
    blurblogs.insert(0, catchall)

    return {"data": blurblogs}


@oauth_login_required
@json.json_view
def api_unread_story(request, trigger_slug=None):
    user = request.user
    body = request.body_json
    after = body.get("after", None)
    before = body.get("before", None)
    limit = body.get("limit", 50)
    fields = body.get("triggerFields")
    feed_or_folder = fields["feed_or_folder"]
    entries = []

    if isinstance(feed_or_folder, int) or feed_or_folder.isdigit():
        feed_id = int(feed_or_folder)
        try:
            usersub = UserSubscription.objects.get(user=user, feed_id=feed_id)
        except UserSubscription.DoesNotExist:
            return dict(data=[])
        found_feed_ids = [feed_id]
        found_trained_feed_ids = [feed_id] if usersub.is_trained else []
        stories = usersub.get_stories(order="newest", read_filter="unread", offset=0, limit=limit)
    else:
        folder_title = feed_or_folder
        if folder_title == "Top Level":
            folder_title = " "
        usf = UserSubscriptionFolders.objects.get(user=user)
        flat_folders = usf.flatten_folders()
        feed_ids = None
        if folder_title != "all":
            feed_ids = flat_folders.get(folder_title)
        usersubs = UserSubscription.subs_for_feeds(user.pk, feed_ids=feed_ids, read_filter="unread")
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
        mstories = MStory.objects(story_hash__in=story_hashes).order_by("-story_date")
        stories = Feed.format_stories(mstories)
        found_feed_ids = list(set([story["story_feed_id"] for story in stories]))
        trained_feed_ids = [sub.feed_id for sub in usersubs if sub.is_trained]
        found_trained_feed_ids = list(set(trained_feed_ids) & set(found_feed_ids))

    if found_trained_feed_ids:
        classifier_feeds = list(MClassifierFeed.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids))
        classifier_authors = list(
            MClassifierAuthor.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids)
        )
        classifier_titles = list(
            MClassifierTitle.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids)
        )
        classifier_tags = list(MClassifierTag.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids))
        if user.profile.premium_available_text_classifiers:
            classifier_texts = list(
                MClassifierText.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids)
            )
        else:
            classifier_texts = []
        classifier_urls = list(MClassifierUrl.objects(user_id=user.pk, feed_id__in=found_trained_feed_ids))
    feeds = dict(
        [
            (
                f.pk,
                {
                    "title": f.feed_title,
                    "website": f.feed_link,
                    "address": f.feed_address,
                },
            )
            for f in Feed.objects.filter(pk__in=found_feed_ids)
        ]
    )

    for story in stories:
        if before and int(story["story_date"].strftime("%s")) > before:
            continue
        if after and int(story["story_date"].strftime("%s")) < after:
            continue
        score = 0
        if found_trained_feed_ids and story["story_feed_id"] in found_trained_feed_ids:
            score = compute_story_score(
                story,
                classifier_titles=classifier_titles,
                classifier_authors=classifier_authors,
                classifier_tags=classifier_tags,
                classifier_texts=classifier_texts,
                classifier_feeds=classifier_feeds,
                classifier_urls=classifier_urls,
            )
            if score < 0:
                continue
            if trigger_slug == "new-unread-focus-story" and score < 1:
                continue
        feed = feeds.get(story["story_feed_id"], None)
        entries.append(
            {
                "StoryTitle": story["story_title"],
                "StoryContent": story["story_content"],
                "StoryURL": story["story_permalink"],
                "StoryAuthor": story["story_authors"],
                "PublishedAt": story["story_date"].strftime("%Y-%m-%dT%H:%M:%SZ"),
                "StoryScore": score,
                "Site": feed and feed["title"],
                "SiteURL": feed and feed["website"],
                "SiteRSS": feed and feed["address"],
                "meta": {"id": story["story_hash"], "timestamp": int(story["story_date"].strftime("%s"))},
            }
        )

    if after:
        entries = sorted(entries, key=lambda s: s["meta"]["timestamp"])

    logging.user(
        request,
        "~FYChecking unread%s stories with ~SB~FCIFTTT~SN~FY: ~SB%s~SN - ~SB%s~SN stories"
        % (" ~SBfocus~SN" if trigger_slug == "new-unread-focus-story" else "", feed_or_folder, len(entries)),
    )

    return {"data": entries[:limit]}


@oauth_login_required
@json.json_view
def api_saved_story(request):
    user = request.user
    body = request.body_json
    after = body.get("after", None)
    before = body.get("before", None)
    limit = body.get("limit", 50)
    fields = body.get("triggerFields")
    story_tag = fields["story_tag"]
    entries = []

    if story_tag == "all":
        story_tag = ""

    params = dict(user_id=user.pk)
    if story_tag:
        params.update(dict(user_tags__contains=story_tag))
    mstories = MStarredStory.objects(**params).order_by("-starred_date")[:limit]
    stories = Feed.format_stories(mstories)

    found_feed_ids = list(set([story["story_feed_id"] for story in stories]))
    feeds = dict(
        [
            (
                f.pk,
                {
                    "title": f.feed_title,
                    "website": f.feed_link,
                    "address": f.feed_address,
                },
            )
            for f in Feed.objects.filter(pk__in=found_feed_ids)
        ]
    )

    for story in stories:
        if before and int(story["story_date"].strftime("%s")) > before:
            continue
        if after and int(story["story_date"].strftime("%s")) < after:
            continue
        feed = feeds.get(story["story_feed_id"], None)
        entries.append(
            {
                "StoryTitle": story["story_title"],
                "StoryContent": story["story_content"],
                "StoryURL": story["story_permalink"],
                "StoryAuthor": story["story_authors"],
                "PublishedAt": story["story_date"].strftime("%Y-%m-%dT%H:%M:%SZ"),
                "SavedAt": story["starred_date"].strftime("%Y-%m-%dT%H:%M:%SZ"),
                "Tags": ", ".join(story["user_tags"]),
                "Site": feed and feed["title"],
                "SiteURL": feed and feed["website"],
                "SiteRSS": feed and feed["address"],
                "meta": {"id": story["story_hash"], "timestamp": int(story["starred_date"].strftime("%s"))},
            }
        )

    if after:
        entries = sorted(entries, key=lambda s: s["meta"]["timestamp"])

    logging.user(
        request,
        "~FCChecking saved stories from ~SBIFTTT~SB: ~SB%s~SN - ~SB%s~SN stories"
        % (story_tag if story_tag else "[All stories]", len(entries)),
    )

    return {"data": entries}


@oauth_login_required
@json.json_view
def api_shared_story(request):
    user = request.user
    body = request.body_json
    after = body.get("after", None)
    before = body.get("before", None)
    limit = body.get("limit", 50)
    fields = body.get("triggerFields")
    blurblog_user = fields["blurblog_user"]
    entries = []

    if isinstance(blurblog_user, int) or blurblog_user.isdigit():
        social_user_ids = [int(blurblog_user)]
    elif blurblog_user == "all":
        socialsubs = MSocialSubscription.objects.filter(user_id=user.pk)
        social_user_ids = [ss.subscription_user_id for ss in socialsubs]

    mstories = MSharedStory.objects(user_id__in=social_user_ids).order_by("-shared_date")[:limit]
    stories = Feed.format_stories(mstories)

    found_feed_ids = list(set([story["story_feed_id"] for story in stories]))
    share_user_ids = list(set([story["user_id"] for story in stories]))
    users = dict(
        [(u.pk, u.username) for u in User.objects.filter(pk__in=share_user_ids).only("pk", "username")]
    )
    feeds = dict(
        [
            (
                f.pk,
                {
                    "title": f.feed_title,
                    "website": f.feed_link,
                    "address": f.feed_address,
                },
            )
            for f in Feed.objects.filter(pk__in=found_feed_ids)
        ]
    )

    classifier_feeds = list(MClassifierFeed.objects(user_id=user.pk, social_user_id__in=social_user_ids))
    classifier_authors = list(MClassifierAuthor.objects(user_id=user.pk, social_user_id__in=social_user_ids))
    classifier_titles = list(MClassifierTitle.objects(user_id=user.pk, social_user_id__in=social_user_ids))
    classifier_tags = list(MClassifierTag.objects(user_id=user.pk, social_user_id__in=social_user_ids))
    if user.profile.premium_available_text_classifiers:
        classifier_texts = list(MClassifierText.objects(user_id=user.pk, social_user_id__in=social_user_ids))
    else:
        classifier_texts = []
    classifier_urls = list(MClassifierUrl.objects(user_id=user.pk, social_user_id__in=social_user_ids))
    # Merge with feed specific classifiers
    classifier_feeds = classifier_feeds + list(
        MClassifierFeed.objects(user_id=user.pk, feed_id__in=found_feed_ids)
    )
    classifier_authors = classifier_authors + list(
        MClassifierAuthor.objects(user_id=user.pk, feed_id__in=found_feed_ids)
    )
    classifier_titles = classifier_titles + list(
        MClassifierTitle.objects(user_id=user.pk, feed_id__in=found_feed_ids)
    )
    classifier_tags = classifier_tags + list(
        MClassifierTag.objects(user_id=user.pk, feed_id__in=found_feed_ids)
    )
    if user.profile.premium_available_text_classifiers:
        classifier_texts = classifier_texts + list(
            MClassifierText.objects(user_id=user.pk, feed_id__in=found_feed_ids)
        )
    else:
        classifier_texts = []
    classifier_urls = classifier_urls + list(
        MClassifierUrl.objects(user_id=user.pk, feed_id__in=found_feed_ids)
    )

    for story in stories:
        if before and int(story["shared_date"].strftime("%s")) > before:
            continue
        if after and int(story["shared_date"].strftime("%s")) < after:
            continue
        score = compute_story_score(
            story,
            classifier_titles=classifier_titles,
            classifier_authors=classifier_authors,
            classifier_tags=classifier_tags,
            classifier_texts=classifier_texts,
            classifier_feeds=classifier_feeds,
            classifier_urls=classifier_urls,
        )
        if score < 0:
            continue
        feed = feeds.get(story["story_feed_id"], None)
        entries.append(
            {
                "StoryTitle": story["story_title"],
                "StoryContent": story["story_content"],
                "StoryURL": story["story_permalink"],
                "StoryAuthor": story["story_authors"],
                "PublishedAt": story["story_date"].strftime("%Y-%m-%dT%H:%M:%SZ"),
                "StoryScore": score,
                "Comments": story["comments"],
                "Username": users.get(story["user_id"]),
                "SharedAt": story["shared_date"].strftime("%Y-%m-%dT%H:%M:%SZ"),
                "Site": feed and feed["title"],
                "SiteURL": feed and feed["website"],
                "SiteRSS": feed and feed["address"],
                "meta": {"id": story["story_hash"], "timestamp": int(story["shared_date"].strftime("%s"))},
            }
        )

    if after:
        entries = sorted(entries, key=lambda s: s["meta"]["timestamp"])

    logging.user(
        request,
        "~FMChecking shared stories from ~SB~FCIFTTT~SN~FM: ~SB~FM%s~FM~SN - ~SB%s~SN stories"
        % (blurblog_user, len(entries)),
    )

    return {"data": entries}


@json.json_view
def ifttt_status(request):
    logging.user(request, "~FCChecking ~SBIFTTT~SN status")

    return {
        "data": {
            "status": "OK",
            "time": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        }
    }


@oauth_login_required
@json.json_view
def api_share_new_story(request):
    user = request.user
    body = request.body_json
    fields = body.get("actionFields")
    story_url = urlnorm.normalize(fields["story_url"])
    story_content = fields.get("story_content", "")
    story_title = fields.get("story_title", "")
    story_author = fields.get("story_author", "")
    comments = fields.get("comments", None)

    if not story_url:
        return {"errors": [{"message": "Invalid story URL"}]}

    logging.user(request.user, "~FBFinding feed (api_share_new_story): %s" % story_url)
    original_feed = Feed.get_feed_from_url(story_url, create=True, fetch=True)
    story_hash = MStory.guid_hash_unsaved(story_url)
    feed_id = original_feed and original_feed.pk or 0
    if not user.profile.is_premium and MSharedStory.feed_quota(user.pk, story_hash, feed_id=feed_id):
        return {
            "errors": [
                {"message": "Only premium users can share multiple stories per day from the same site."}
            ]
        }

    quota = 3
    if MSharedStory.feed_quota(user.pk, story_hash, quota=quota):
        logging.user(
            request,
            "~BM~FRNOT ~FYSharing story from ~SB~FCIFTTT~FY, over quota: ~SB%s: %s" % (story_url, comments),
        )
        return {"errors": [{"message": "You can only share %s stories per day." % quota}]}

    if not story_content or not story_title:
        ti = TextImporter(feed=original_feed, story_url=story_url, request=request)
        original_story = ti.fetch(return_document=True)
        if original_story:
            story_url = original_story["url"]
            if not story_content:
                story_content = original_story["content"]
            if not story_title:
                story_title = original_story["title"]

    if story_content:
        story_content = lxml.html.fromstring(story_content)
        story_content.make_links_absolute(story_url)
        story_content = lxml.html.tostring(story_content)

    shared_story = (
        MSharedStory.objects.filter(
            user_id=user.pk, story_feed_id=original_feed and original_feed.pk or 0, story_guid=story_url
        )
        .limit(1)
        .first()
    )
    if not shared_story:
        title_max = MSharedStory._fields["story_title"].max_length
        story_db = {
            "story_guid": story_url,
            "story_permalink": story_url,
            "story_title": story_title and story_title[:title_max] or "[Untitled]",
            "story_feed_id": original_feed and original_feed.pk or 0,
            "story_content": story_content,
            "story_author_name": story_author,
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
            logging.user(
                request, "~BM~FYSharing story from ~SB~FCIFTTT~FY: ~SB%s: %s" % (story_url, comments)
            )
        except NotUniqueError:
            logging.user(
                request,
                "~BM~FY~SBAlready~SN shared story from ~SB~FCIFTTT~FY: ~SB%s: %s" % (story_url, comments),
            )
    else:
        logging.user(
            request, "~BM~FY~SBAlready~SN shared story from ~SB~FCIFTTT~FY: ~SB%s: %s" % (story_url, comments)
        )

    try:
        socialsub = MSocialSubscription.objects.get(user_id=user.pk, subscription_user_id=user.pk)
    except MSocialSubscription.DoesNotExist:
        socialsub = None

    if socialsub and shared_story:
        socialsub.mark_story_ids_as_read(
            [shared_story.story_hash], shared_story.story_feed_id, request=request
        )
    elif shared_story:
        RUserStory.mark_read(user.pk, shared_story.story_feed_id, shared_story.story_hash)

    if shared_story:
        shared_story.publish_update_to_subscribers()

    return {
        "data": [
            {
                "id": shared_story and shared_story.story_guid,
                "url": shared_story and shared_story.blurblog_permalink(),
            }
        ]
    }


@oauth_login_required
@json.json_view
def api_save_new_story(request):
    user = request.user
    body = request.body_json
    fields = body.get("actionFields")
    story_url = urlnorm.normalize(fields["story_url"])
    story_content = fields.get("story_content", "")
    story_title = fields.get("story_title", "")
    story_author = fields.get("story_author", "")
    user_tags = fields.get("user_tags", "")
    story = None

    if not story_url:
        return {"errors": [{"message": "Invalid story URL"}]}

    logging.user(request.user, "~FBFinding feed (api_save_new_story): %s" % story_url)
    original_feed = Feed.get_feed_from_url(story_url)
    if not story_content or not story_title:
        ti = TextImporter(feed=original_feed, story_url=story_url, request=request)
        original_story = ti.fetch(return_document=True)
        if original_story:
            story_url = original_story["url"]
            if not story_content:
                story_content = original_story["content"]
            if not story_title:
                story_title = original_story["title"]
    try:
        story_db = {
            "user_id": user.pk,
            "starred_date": datetime.datetime.now(),
            "story_date": datetime.datetime.now(),
            "story_title": story_title or "[Untitled]",
            "story_permalink": story_url,
            "story_guid": story_url,
            "story_content": story_content,
            "story_author_name": story_author,
            "story_feed_id": original_feed and original_feed.pk or 0,
            "user_tags": [tag for tag in user_tags.split(",")],
        }
        story = MStarredStory.objects.create(**story_db)
        logging.user(
            request,
            "~FCStarring by ~SBIFTTT~SN: ~SB%s~SN in ~SB%s"
            % (story_db["story_title"][:50], original_feed and original_feed),
        )
        MStarredStoryCounts.count_for_user(user.pk)
    except OperationError:
        logging.user(request, "~FCAlready starred by ~SBIFTTT~SN: ~SB%s" % (story_db["story_title"][:50]))
        pass

    return {"data": [{"id": story and story.id, "url": story and story.story_permalink}]}


@oauth_login_required
@json.json_view
def api_save_new_subscription(request):
    user = request.user
    body = request.body_json
    fields = body.get("actionFields")
    url = urlnorm.normalize(fields["url"])
    folder = fields["folder"]

    if not url:
        return {"errors": [{"message": "Invalid URL"}]}

    if folder == "Top Level":
        folder = " "

    code, message, us = UserSubscription.add_subscription(
        user=user, feed_address=url, folder=folder, bookmarklet=True
    )

    logging.user(request, "~FRAdding URL from ~FC~SBIFTTT~SN~FR: ~SB%s (in %s)" % (url, folder))

    if us and us.feed:
        url = us.feed.feed_address

    return {
        "data": [
            {
                "id": us and us.feed_id,
                "url": url,
            }
        ]
    }


class ExtensionAuthorizationView(BaseAuthorizationView):
    """
    Custom OAuth authorization view that allows redirects to chrome-extension:// URLs.
    This is needed for browser extension OAuth flows.
    """

    def get(self, request, *args, **kwargs):
        """Override get to add logging for debugging OAuth issues."""
        redirect_uri = request.GET.get("redirect_uri", "")
        client_id = request.GET.get("client_id", "")
        response_type = request.GET.get("response_type", "")

        logging.user(
            request,
            "~FBArchive OAuth authorize: client=%s, response_type=%s, redirect_uri=%s"
            % (client_id, response_type, redirect_uri),
        )

        return super().get(request, *args, **kwargs)

    def redirect(self, redirect_to, application):
        """Override redirect to allow chrome-extension:// and moz-extension:// schemes."""
        from django.http import HttpResponse

        # Log the redirect for debugging
        logging.info(
            "~FBArchive OAuth redirect: app=%s, redirect_to=%s"
            % (application.name if application else "none", redirect_to[:100])
        )

        # Check if this is a browser extension redirect
        if redirect_to.startswith("chrome-extension://") or redirect_to.startswith("moz-extension://"):
            # Use a plain HttpResponse with Location header to bypass OAuth2ResponseRedirect scheme check
            response = HttpResponse(status=302)
            response["Location"] = redirect_to
            return response

        # For normal redirects, use the parent implementation
        return super().redirect(redirect_to, application)


def extension_oauth_callback(request):
    """
    OAuth callback page for browser extensions.
    This page handles the token exchange client-side (to work with self-signed certs)
    and sends the token to the extension via postMessage.
    """
    from django.http import HttpResponse

    code = request.GET.get("code", "")
    error = request.GET.get("error", "")

    # Log the full request for debugging
    full_url = request.build_absolute_uri()
    query_string = request.META.get("QUERY_STRING", "")
    logging.user(
        request,
        "~FBArchive OAuth callback: URL=%s, query=%s, code=%s, error=%s"
        % (full_url, query_string, bool(code), error or "none"),
    )

    # If no code and no error, something went wrong in the OAuth flow
    if not code and not error:
        error = "no_code"
        logging.user(
            request,
            "~FRArchive OAuth callback: No authorization code received. "
            "This usually means a redirect stripped the query string. Check nginx/haproxy config.",
        )

    # Common styles for both success and error pages
    common_styles = """
        html, body {
            height: 100%;
            margin: 0;
            padding: 0;
        }
        body {
            font-family: 'Helvetica Neue', Helvetica, sans-serif;
            -webkit-font-smoothing: antialiased;
            background-color: #304332;
            background: linear-gradient(to bottom, #304332 0%, #172018 100%);
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .card {
            background: rgba(255, 255, 255, 0.06);
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            border-radius: 16px;
            padding: 48px 56px;
            text-align: center;
            max-width: 420px;
            box-shadow: 0 4px 24px rgba(0, 0, 0, 0.15);
        }
        .logo {
            margin-bottom: 28px;
        }
        .logo img {
            height: 36px;
            width: auto;
        }
        h1 {
            color: #fff;
            font-size: 26px;
            font-weight: bold;
            text-shadow: 0 1px 4px rgba(0,0,0,0.5);
            letter-spacing: -0.5px;
            margin: 0 0 12px 0;
        }
        .checkmark {
            display: inline-block;
            color: #8EC685;
            margin-right: 6px;
        }
        .error-icon {
            color: #C5826E;
            margin-right: 6px;
        }
        .description {
            color: rgba(255, 255, 255, 0.75);
            font-size: 15px;
            line-height: 22px;
            text-shadow: 0 1px 0 rgba(0,0,0,0.33);
        }
        .status {
            color: rgba(255, 255, 255, 0.5);
            font-size: 13px;
            margin-top: 16px;
        }
        .error-detail {
            color: #C5826E;
            font-size: 13px;
            font-family: monospace;
            margin: 16px 0;
        }
        .close-hint {
            color: rgba(255, 255, 255, 0.45);
            font-size: 13px;
        }
        a {
            color: #8EC685;
            text-decoration: none;
        }
        a:hover {
            color: #A8D8A0;
        }
        .spinner {
            display: inline-block;
            width: 16px;
            height: 16px;
            border: 2px solid rgba(255,255,255,0.3);
            border-top-color: #8EC685;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-right: 8px;
            vertical-align: middle;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        .hidden { display: none; }
    """

    if error:
        # Map error codes to user-friendly messages
        error_messages = {
            "no_code": (
                "No authorization code was received. This usually means:<br><br>"
                "1. A redirect (HTTP→HTTPS or www) stripped the query string<br>"
                "2. The OAuth redirect_uri doesn't match what's registered<br><br>"
                "Check your nginx/haproxy config and ensure NEWSBLUR_URL matches your domain.<br>"
                f"<br><small style='color: #888;'>Requested URL: {request.build_absolute_uri()}</small>"
            ),
            "access_denied": "You denied access to the Archive extension.",
            "invalid_request": "The authorization request was invalid.",
            "unauthorized_client": "The client is not authorized.",
            "unsupported_response_type": "The response type is not supported.",
            "invalid_scope": "The requested scope is invalid.",
            "server_error": "The server encountered an error.",
            "temporarily_unavailable": "The server is temporarily unavailable.",
        }
        error_description = error_messages.get(error, f"Error: {error}")

        html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Connection Failed - NewsBlur Archive</title>
    <style>{common_styles}</style>
</head>
<body>
    <div class="card">
        <div class="logo">
            <img src="/media/embed/logo_newsblur_blur.png" alt="NewsBlur">
        </div>
        <h1><span class="error-icon">&#10007;</span> Connection Failed</h1>
        <p class="description">
            We couldn't connect the Archive extension to your account.
        </p>
        <p class="error-detail">{error_description}</p>
        <p class="close-hint">
            <a href="javascript:window.close()">Close this tab and try again</a>
        </p>
    </div>
</body>
</html>"""
    else:
        # Build the current origin for the token exchange
        # The code is in the URL, we'll exchange it client-side
        html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Connecting - NewsBlur Archive</title>
    <style>{common_styles}</style>
</head>
<body>
    <div class="card">
        <div class="logo">
            <img src="/media/embed/logo_newsblur_blur.png" alt="NewsBlur">
        </div>
        <div id="connecting">
            <h1><span class="spinner"></span> Connecting...</h1>
            <p class="description">
                Completing the connection to your account.
            </p>
        </div>
        <div id="success" class="hidden">
            <h1><span class="checkmark">&#10003;</span> Connected</h1>
            <p class="description">
                The Archive extension is now linked to your account.<br>
                You can close this tab.
            </p>
        </div>
        <div id="error" class="hidden">
            <h1><span class="error-icon">&#10007;</span> Connection Failed</h1>
            <p class="description">
                We couldn't complete the connection.
            </p>
            <p class="error-detail" id="errorDetail"></p>
            <p class="close-hint">
                <a href="javascript:window.close()">Close this tab and try again</a>
            </p>
        </div>
    </div>
    <script>
        (async function() {{
            const code = '{code}';
            const redirectUri = window.location.origin + '/oauth/extension-callback/';
            const tokenUrl = window.location.origin + '/oauth/token/';

            try {{
                // Exchange the authorization code for a token
                const formData = new URLSearchParams();
                formData.append('grant_type', 'authorization_code');
                formData.append('code', code);
                formData.append('client_id', 'newsblur-archive-extension');
                formData.append('redirect_uri', redirectUri);

                const response = await fetch(tokenUrl, {{
                    method: 'POST',
                    headers: {{
                        'Content-Type': 'application/x-www-form-urlencoded',
                    }},
                    body: formData.toString()
                }});

                if (!response.ok) {{
                    const errorText = await response.text();
                    throw new Error('Token exchange failed: ' + errorText);
                }}

                const tokenData = await response.json();
                console.log('NewsBlur Archive: Token received');

                // Send the token to the extension via postMessage
                // The extension's content script will relay this to the service worker
                window.postMessage({{
                    type: 'NEWSBLUR_ARCHIVE_TOKEN',
                    accessToken: tokenData.access_token,
                    refreshToken: tokenData.refresh_token,
                    expiresIn: tokenData.expires_in
                }}, '*');

                // Show success
                document.getElementById('connecting').classList.add('hidden');
                document.getElementById('success').classList.remove('hidden');
                document.title = 'Connected - NewsBlur Archive';

            }} catch (error) {{
                console.error('NewsBlur Archive: Token exchange error:', error);

                // Parse the error message for better user feedback
                let errorMessage = error.message;
                if (errorMessage.includes('invalid_grant')) {{
                    errorMessage = 'This authorization code has already been used or expired. ' +
                        'If you just connected successfully, you can close this tab. ' +
                        'Otherwise, please try connecting again from the extension.';
                }}

                // Show error
                document.getElementById('connecting').classList.add('hidden');
                document.getElementById('error').classList.remove('hidden');
                document.getElementById('errorDetail').textContent = errorMessage;
                document.title = 'Connection Failed - NewsBlur Archive';
            }}
        }})();
    </script>
</body>
</html>"""

    return HttpResponse(html, content_type="text/html")
