import datetime
import zlib
from django.shortcuts import get_object_or_404
from django.core.urlresolvers import reverse
from django.contrib.auth.models import User
from django.http import HttpResponse, HttpResponseRedirect, Http404
from django.conf import settings
from apps.rss_feeds.models import MStory, Feed, MStarredStory
from apps.social.models import MSharedStory, MSocialServices, MSocialProfile, MSocialSubscription, MCommentReply
from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds, apply_classifier_authors, apply_classifier_tags
from apps.analyzer.models import get_classifiers_for_user
from apps.reader.models import MUserStory, UserSubscription
from utils import json_functions as json
from utils import log as logging
from utils import PyRSS2Gen as RSS
from utils.user_functions import get_user, ajax_login_required
from utils.view_functions import render_to
from utils.story_functions import format_story_link_date__short
from utils.story_functions import format_story_link_date__long
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
    UNREAD_CUTOFF = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)

    mstories = MSharedStory.objects(user_id=social_user.pk).order_by('-shared_date')[offset:offset+limit]
    stories = Feed.format_stories(mstories)
    
    if not stories:
        return dict(stories=[])
        
    stories, user_profiles = MSharedStory.stories_with_comments_and_profiles(stories, user, check_all=True)

    story_feed_ids = list(set(s['story_feed_id'] for s in stories))
    try:
        socialsub = MSocialSubscription.objects.get(user_id=user.pk, subscription_user_id=social_user_id)
    except MSocialSubscription.DoesNotExist:
        socialsub = None
    usersubs = UserSubscription.objects.filter(user__pk=user.pk, feed__pk__in=story_feed_ids)
    usersubs_map = dict((sub.feed_id, sub) for sub in usersubs)
    unsub_feed_ids = list(set(story_feed_ids).difference(set(usersubs_map.keys())))
    unsub_feeds = Feed.objects.filter(pk__in=unsub_feed_ids)
    unsub_feeds = dict((feed.pk, feed.canonical(include_favicon=False)) for feed in unsub_feeds)
    date_delta = UNREAD_CUTOFF
    if socialsub and date_delta < socialsub.mark_read_date:
        date_delta = socialsub.mark_read_date
    
    # Get intelligence classifier for user
    classifier_feeds   = list(MClassifierFeed.objects(user_id=user.pk, social_user_id=social_user_id))
    classifier_authors = list(MClassifierAuthor.objects(user_id=user.pk, social_user_id=social_user_id))
    classifier_titles  = list(MClassifierTitle.objects(user_id=user.pk, social_user_id=social_user_id))
    classifier_tags    = list(MClassifierTag.objects(user_id=user.pk, social_user_id=social_user_id))
    # Merge with feed specific classifiers
    classifier_feeds   = classifier_feeds + list(MClassifierFeed.objects(user_id=user.pk, feed_id__in=story_feed_ids))
    classifier_authors = classifier_authors + list(MClassifierAuthor.objects(user_id=user.pk, feed_id__in=story_feed_ids))
    classifier_titles  = classifier_titles + list(MClassifierTitle.objects(user_id=user.pk, feed_id__in=story_feed_ids))
    classifier_tags    = classifier_tags + list(MClassifierTag.objects(user_id=user.pk, feed_id__in=story_feed_ids))

    story_ids = [story['id'] for story in stories]
    userstories_db = MUserStory.objects(user_id=user.pk,
                                        feed_id__in=story_feed_ids,
                                        story_id__in=story_ids).only('story_id')
    userstories = set(us.story_id for us in userstories_db)

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
    
    for story in stories:
        story['social_user_id'] = social_user_id
        story_feed_id = story['story_feed_id']
        # story_date = localtime_for_timezone(story['story_date'], user.profile.timezone)
        shared_date = localtime_for_timezone(story['shared_date'], user.profile.timezone)
        story['short_parsed_date'] = format_story_link_date__short(shared_date, now)
        story['long_parsed_date'] = format_story_link_date__long(shared_date, now)
        
        if story['id'] in userstories:
            story['read_status'] = 1
        elif story['shared_date'] < date_delta:
            story['read_status'] = 1
        elif not usersubs_map.get(story_feed_id):
            story['read_status'] = 0
        # elif not story.get('read_status') and story['shared_date'] < usersubs_map[story_feed_id].mark_read_date:
        elif not story.get('read_status') and story['shared_date'] < date_delta:
            story['read_status'] = 1
        # elif not story.get('read_status') and socialsub and story['shared_date'] > socialsub.last_read_date:
        #     story['read_status'] = 0
        else:
            story['read_status'] = 0

        # print story['read_status'], story['shared_date'], date_delta

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
            'feed': apply_classifier_feeds(classifier_feeds, story['story_feed_id'], social_user_id=social_user_id),
            'author': apply_classifier_authors(classifier_authors, story),
            'tags': apply_classifier_tags(classifier_tags, story),
            'title': apply_classifier_titles(classifier_titles, story),
        }

    logging.user(request, "~FCLoading shared stories: ~SB%s stories" % (len(stories)))
    
    return dict(stories=stories, user_profiles=user_profiles, feeds=unsub_feeds)

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
        if story['story_feed_id'] in feeds:
            # Feed could have been deleted.
            story['feed'] = feeds[story['story_feed_id']]
        shared_date = localtime_for_timezone(story['shared_date'], social_user.profile.timezone)
        story['shared_date'] = shared_date
    
    stories, profiles = MSharedStory.stories_with_comments_and_profiles(stories, user, check_all=True)
    social_profile = MSocialProfile.objects.get(user_id=social_user_id)

    params = {
        'user': user,
        'social_user': social_user,
        'stories': stories,
        'social_profile': social_profile.page(),
        'feeds': feeds,
    }
    
    return params
    
@json.json_view
def story_comments(request):
    feed_id  = int(request.REQUEST['feed_id'])
    story_id = request.REQUEST['story_id']
    
    shared_stories = MSharedStory.objects.filter(story_feed_id=feed_id, story_guid=story_id, has_comments=True)
    comments = [s.comments_with_author() for s in shared_stories]

    profile_user_ids = [c['user_id'] for c in comments]
    profiles = MSocialProfile.objects.filter(user_id__in=list(profile_user_ids))
    profiles = [profile.to_json(compact=True) for profile in profiles]
    
    return {'comments': comments, 'profiles': profiles}

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
    stories, profiles = MSharedStory.stories_with_comments_and_profiles([story], request.user)
    story = stories[0]
    
    return {'code': code, 'story': story, 'user_profiles': profiles}

@ajax_login_required
@json.json_view
def save_comment_reply(request):
    code     = 1
    feed_id  = int(request.POST['story_feed_id'])
    story_id = request.POST['story_id']
    comment_user_id = request.POST['comment_user_id']
    reply_comments = request.POST.get('reply_comments')
    
    if not reply_comments:
        return {'code': -1, 'message': 'Reply comments cannot be empty.'}
        
    story = MStory.objects(story_feed_id=feed_id, story_guid=story_id).limit(1).first()
    if not story:
        return {'code': -1, 'message': 'Story not found.'}
    
    shared_story = MSharedStory.objects.get(user_id=comment_user_id, story_feed_id=feed_id, story_guid=story_id)
    reply = MCommentReply()
    reply.user_id = request.user.pk
    reply.publish_date = datetime.datetime.now()
    reply.comments = reply_comments
    shared_story.replies.append(reply)
    shared_story.save()
    logging.user(request, "~FCReplying to comment in: ~SB~FM%s (~FB%s~FM)" % (story.story_title[:50], reply_comments[:100]))
    
    story = Feed.format_story(story)
    stories, profiles = MSharedStory.stories_with_comments_and_profiles([story], request.user)
    story = stories[0]
    
    return {'code': code, 'story': story, 'user_profiles': profiles}
    
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
    social_profile, _ = MSocialProfile.objects.get_or_create(user_id=user.pk)
    social_services, _ = MSocialServices.objects.get_or_create(user_id=user.pk)
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

    user_id = request.GET.get('user_id', request.user.pk)
    user_profile = MSocialProfile.objects.get(user_id=user_id)
    current_profile, _ = MSocialProfile.objects.get_or_create(user_id=request.user.pk)
    followers_youknow, followers_everybody = current_profile.common_follows(user_id, direction='followers')
    following_youknow, following_everybody = current_profile.common_follows(user_id, direction='following')
    profile_ids = set(followers_youknow + followers_everybody + following_youknow + following_everybody)
    profiles = MSocialProfile.profiles(profile_ids)
    logging.user(request, "~BB~FRLoading social profile: %s" % user_profile.username)
    
    payload = {
        'user_profile': user_profile.to_json(full=True),
        'followers_youknow': followers_youknow,
        'followers_everybody': followers_everybody,
        'following_youknow': following_youknow,
        'following_everybody': following_everybody,
        'profiles': dict([(p.user_id, p.to_json(compact=True)) for p in profiles]),
    }
    return payload
    
def save_profile(request):
    data = request.POST

    profile, _ = MSocialProfile.objects.get_or_create(user_id=request.user.pk)
    profile.location = data['location']
    profile.bio = data['bio']
    profile.website = data['website']
    profile.save()

    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    social_services.set_photo(data['photo_service'])
    
    logging.user(request, "~BB~FRSaving social profile")
    
    return dict(code=1, user_profile=profile.to_json(full=True))

@ajax_login_required
@json.json_view
def follow(request):
    profile, _ = MSocialProfile.objects.get_or_create(user_id=request.user.pk)
    try:
        follow_user_id = int(request.POST['user_id'])
    except ValueError:
        follow_username = request.POST['user_id'].replace('social:', '')
        follow_profile = MSocialProfile.objects.get(username=follow_username)
        follow_user_id = follow_profile.user_id

    profile.follow_user(follow_user_id)
    follow_profile = MSocialProfile.objects.get(user_id=follow_user_id)
    
    social_params = {
        'user_id': request.user.pk,
        'subscription_user_id': follow_user_id,
        'include_favicon': True,
        'update_counts': True,
    }
    follow_subscription = MSocialSubscription.feeds(**social_params)
    
    logging.user(request, "~BB~FRFollowing: %s" % follow_profile.username)
    
    return {
        "user_profile": profile.to_json(full=True), 
        "follow_profile": follow_profile,
        "follow_subscription": follow_subscription,
    }
    
@ajax_login_required
@json.json_view
def unfollow(request):
    profile = MSocialProfile.objects.get(user_id=request.user.pk)
    try:
        unfollow_user_id = int(request.POST['user_id'])
    except ValueError:
        unfollow_username = request.POST['user_id'].replace('social:', '')
        unfollow_profile = MSocialProfile.objects.get(username=unfollow_username)
        unfollow_user_id = unfollow_profile.user_id
        
    profile.unfollow_user(unfollow_user_id)
    unfollow_profile = MSocialProfile.objects.get(user_id=unfollow_user_id)
    
    logging.user(request, "~BB~FRUnfollowing: %s" % unfollow_profile.username)
    
    return dict(user_profile=profile.to_json(full=True), unfollow_profile=unfollow_profile)

@json.json_view
def find_friends(request):
    query = request.GET.get('query')
    profiles = MSocialProfile.objects.filter(username__icontains=query)
    if not profiles:
        profiles = MSocialProfile.objects.filter(email__icontains=query)
    if not profiles:
        profiles = MSocialProfile.objects.filter(blog_title__icontains=query)
    
    return dict(profiles=profiles)
    
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

@json.json_view
def social_feed_trainer(request):
    social_user_id = request.REQUEST.get('user_id')
    social_profile = MSocialProfile.objects.get(user_id=social_user_id)
    social_user = get_object_or_404(User, pk=social_user_id)
    user = get_user(request)
    
    social_profile.count_stories()
    classifier = social_profile.to_json()
    classifier['classifiers'] = get_classifiers_for_user(user, social_user_id=classifier['id'])
    classifier['num_subscribers'] = social_profile.follower_count
    classifier['feed_tags'] = []
    classifier['feed_authors'] = []
    
    logging.user(user, "~FGLoading social trainer on ~SB%s: %s" % (social_user.username, social_profile.title))
    
    return [classifier]
    

@json.json_view
def load_social_statistics(request, social_user_id, username=None):
    stats = dict()
    social_profile = MSocialProfile.objects.get(user_id=social_user_id)
    social_profile.save_feed_story_history_statistics()
    social_profile.save_classifier_counts()
    
    # Stories per month - average and month-by-month breakout
    stats['average_stories_per_month'] = social_profile.average_stories_per_month
    stats['story_count_history'] = social_profile.story_count_history
    
    # Subscribers
    stats['subscriber_count'] = social_profile.follower_count
    stats['num_subscribers'] = social_profile.follower_count
    
    # Classifier counts
    stats['classifier_counts'] = social_profile.feed_classifier_counts
    
    logging.user(request, "~FBStatistics social: ~SB%s ~FG(%s subs)" % (social_profile.user_id, social_profile.follower_count))

    return stats

@json.json_view
def load_social_settings(request, social_user_id, username=None):
    social_profile = MSocialProfile.objects.get(user_id=social_user_id)
    
    return social_profile.to_json()
