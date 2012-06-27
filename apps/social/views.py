import time
import datetime
import zlib
from django.shortcuts import get_object_or_404
from django.core.urlresolvers import reverse
from django.contrib.auth.models import User
from django.template.loader import render_to_string
from django.http import HttpResponse, HttpResponseRedirect, Http404
from django.conf import settings
from apps.rss_feeds.models import MStory, Feed, MStarredStory
from apps.social.models import MSharedStory, MSocialServices, MSocialProfile, MSocialSubscription, MCommentReply
from apps.social.models import MRequestInvite, MInteraction, MActivity
from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds, apply_classifier_authors, apply_classifier_tags
from apps.analyzer.models import get_classifiers_for_user, sort_classifiers_by_feed
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
def request_invite(request):
    if not request.POST.get('username'):
        return {}
        
    MRequestInvite.objects.create(username=request.POST['username'])
    logging.user(request, " ---> ~BG~FB~SBInvite requested: %s" % request.POST['username'])
    return {}
    
@json.json_view
def load_social_stories(request, user_id, username=None):
    start = time.time()
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
    unsub_feeds = [feed.canonical(include_favicon=False) for feed in unsub_feeds]
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
        
        if not socialsub:
            story['read_status'] = 1
        elif story['id'] in userstories:
            story['read_status'] = 1
        elif story['shared_date'] < date_delta:
            story['read_status'] = 1
        elif not usersubs_map.get(story_feed_id):
            story['read_status'] = 0
        elif not story.get('read_status') and story['story_date'] < usersubs_map[story_feed_id].mark_read_date:
            story['read_status'] = 1
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
            shared_date = localtime_for_timezone(shared_stories[story['id']]['shared_date'],
                                                 user.profile.timezone)
            story['shared_date'] = format_story_link_date__long(shared_date, now)
            story['shared_comments'] = shared_stories[story['id']]['comments']

        story['intelligence'] = {
            'feed': apply_classifier_feeds(classifier_feeds, story['story_feed_id'],
                                           social_user_id=social_user_id),
            'author': apply_classifier_authors(classifier_authors, story),
            'tags': apply_classifier_tags(classifier_tags, story),
            'title': apply_classifier_titles(classifier_titles, story),
        }
    
    
    classifiers = sort_classifiers_by_feed(user=user, feed_ids=story_feed_ids,
                                           classifier_feeds=classifier_feeds,
                                           classifier_authors=classifier_authors,
                                           classifier_titles=classifier_titles,
                                           classifier_tags=classifier_tags)
                                           
    if socialsub:
        socialsub.feed_opens += 1
        socialsub.save()
    
    end = time.time()
    logging.user(request, "~FCLoading shared stories: ~SB%s stories ~SN(%.2f sec)" % (len(stories), end-start))
    
    return {
        "stories": stories, 
        "user_profiles": user_profiles, 
        "feeds": unsub_feeds, 
        "classifiers": classifiers,
    }

@render_to('social/social_page.xhtml')
def load_social_page(request, user_id, username=None):
    user = get_user(request)
    social_user_id = int(user_id)
    social_user = get_object_or_404(User, pk=social_user_id)
    offset = int(request.REQUEST.get('offset', 0))
    limit = int(request.REQUEST.get('limit', 12))
    page = request.REQUEST.get('page')
    if page: offset = limit * (int(page) - 1)
    
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
    
    shared_stories = MSharedStory.objects.filter(story_feed_id=feed_id, 
                                                 story_guid=story_id, 
                                                 has_comments=True)
    comments = [s.comments_with_author() for s in shared_stories]

    profile_user_ids = set([c['user_id'] for c in comments])
    profile_user_ids = profile_user_ids.union([r['user_id'] for c in comments for r in c['replies']])
    profiles = MSocialProfile.objects.filter(user_id__in=list(profile_user_ids))
    profiles = [profile.to_json(compact=True) for profile in profiles]
    
    return {'comments': comments, 'user_profiles': profiles}

@ajax_login_required
@json.json_view
def mark_story_as_shared(request):
    code     = 1
    feed_id  = int(request.POST['feed_id'])
    story_id = request.POST['story_id']
    comments = request.POST.get('comments', '')
    source_user_id = request.POST.get('source_user_id')
    
    story = MStory.objects(story_feed_id=feed_id, story_guid=story_id).limit(1).first()
    if not story:
        return {
            'code': -1, 
            'message': 'The original story is gone. This would be a nice bug to fix. Speak up.'
        }
    
    shared_story = MSharedStory.objects.filter(user_id=request.user.pk, 
                                               story_feed_id=feed_id, 
                                               story_guid=story_id)
    if not shared_story:
        story_db = dict([(k, v) for k, v in story._data.items() 
                                if k is not None and v is not None])
        story_values = dict(user_id=request.user.pk, comments=comments, 
                            has_comments=bool(comments), **story_db)
        shared_story = MSharedStory.objects.create(**story_values)
        if source_user_id:
            shared_story.set_source_user_id(int(source_user_id))
        socialsubs = MSocialSubscription.objects.filter(subscription_user_id=request.user.pk)
        for socialsub in socialsubs:
            socialsub.needs_unread_recalc = True
            socialsub.save()
        logging.user(request, "~FCSharing ~FM%s: ~SB~FB%s" % (story.story_title[:20], comments[:30]))
    else:
        shared_story = shared_story[0]
        shared_story.comments = comments
        shared_story.has_comments = bool(comments)
        shared_story.save()
        logging.user(request, "~FCUpdating shared story ~FM%s: ~SB~FB%s" % (
                     story.story_title[:20], comments[:30]))
    
    story.count_comments()
    shared_story.publish_update_to_subscribers()
    
    story = Feed.format_story(story)
    stories, profiles = MSharedStory.stories_with_comments_and_profiles([story], request.user)
    story = stories[0]
    story['shared_comments'] = shared_story['comments'] or ""
    
    return {'code': code, 'story': story, 'user_profiles': profiles}

@ajax_login_required
@json.json_view
def mark_story_as_unshared(request):
    feed_id  = int(request.POST['feed_id'])
    story_id = request.POST['story_id']
    
    story = MStory.objects(story_feed_id=feed_id, story_guid=story_id).limit(1).first()
    if not story:
        return {'code': -1, 'message': 'Story not found. Reload this site.'}
        
    try:
        shared_story = MSharedStory.objects.get(user_id=request.user.pk, 
                                                   story_feed_id=feed_id, 
                                                   story_guid=story_id)
    except MSharedStory.DoesNotExist:
        return {'code': -1, 'message': 'Shared story not found.'}
    
    socialsubs = MSocialSubscription.objects.filter(subscription_user_id=request.user.pk)
    for socialsub in socialsubs:
        socialsub.needs_unread_recalc = True
        socialsub.save()
    logging.user(request, "~FC~SKUn-sharing ~FM%s: ~SB~FB%s" % (shared_story.story_title[:20],
                                                                shared_story.comments[:30]))
    shared_story.delete()
    
    story.count_comments()
    
    story = Feed.format_story(story)
    stories, profiles = MSharedStory.stories_with_comments_and_profiles([story], 
                                                                        request.user, 
                                                                        check_all=True)
    story = stories[0]
    
    return {'code': 1, 'message': "Story unshared.", 'story': story, 'user_profiles': profiles}
    
@ajax_login_required
@json.json_view
def save_comment_reply(request):
    code     = 1
    feed_id  = int(request.POST['story_feed_id'])
    story_id = request.POST['story_id']
    comment_user_id = request.POST['comment_user_id']
    reply_comments = request.POST.get('reply_comments')
    original_message = request.POST.get('original_message')
    
    if not reply_comments:
        return {'code': -1, 'message': 'Reply comments cannot be empty.'}
        
    shared_story = MSharedStory.objects.get(user_id=comment_user_id, 
                                            story_feed_id=feed_id, 
                                            story_guid=story_id)
    reply = MCommentReply()
    reply.user_id = request.user.pk
    reply.publish_date = datetime.datetime.now()
    reply.comments = reply_comments
    
    if original_message:
        replies = []
        for story_reply in shared_story.replies:
            if (story_reply.user_id == reply.user_id and 
                story_reply.comments == original_message):
                reply.publish_date = story_reply.publish_date
                replies.append(reply)
            else:
                replies.append(story_reply)
        shared_story.replies = replies
        logging.user(request, "~FCUpdating comment reply in ~FM%s: ~SB~FB%s~FM" % (
                 shared_story.story_title[:20], reply_comments[:30]))
    else:
        logging.user(request, "~FCReplying to comment in: ~FM%s: ~SB~FB%s~FM" % (
                     shared_story.story_title[:20], reply_comments[:30]))
        shared_story.replies.append(reply)
    shared_story.save()
    
    
    comment = shared_story.comments_with_author()
    profile_user_ids = set([comment['user_id']])
    reply_user_ids = [reply['user_id'] for reply in comment['replies']]
    profile_user_ids = profile_user_ids.union(reply_user_ids)
    profiles = MSocialProfile.objects.filter(user_id__in=list(profile_user_ids))
    profiles = [profile.to_json(compact=True) for profile in profiles]
    
    # Interaction for every other replier and original commenter
    MActivity.new_comment_reply(user_id=request.user.pk,
                                comment_user_id=comment['user_id'],
                                reply_content=reply_comments,
                                original_message=original_message,
                                story_feed_id=feed_id,
                                story_id=story_id)
    if comment['user_id'] != request.user.pk:
        MInteraction.new_comment_reply(user_id=comment['user_id'], 
                                       reply_user_id=request.user.pk, 
                                       reply_content=reply_comments,
                                       original_message=original_message,
                                       social_feed_id=comment_user_id,
                                       story_id=story_id)
    
    for user_id in set(reply_user_ids).difference([comment['user_id']]):
        if request.user.pk != user_id:
            MInteraction.new_reply_reply(user_id=user_id, 
                                         reply_user_id=request.user.pk, 
                                         reply_content=reply_comments,
                                         original_message=original_message,
                                         social_feed_id=comment_user_id,
                                         story_id=story_id)
    
    return {'code': code, 'comment': comment, 'user_profiles': profiles}
    
def shared_stories_public(request, username):
    try:
        user = User.objects.get(username=username)
    except User.DoesNotExist:
        raise Http404

    shared_stories = MSharedStory.objects.filter(user_id=user.pk)
        
    return HttpResponse("There are %s stories shared by %s." % (shared_stories.count(), username))
    
@json.json_view
def profile(request):
    user = get_user(request.user)
    user_id = request.GET.get('user_id', user.pk)
    user_profile = MSocialProfile.objects.get(user_id=user_id)
    user_profile = user_profile.to_json(full=True, common_follows_with_user=user.pk)
    profile_ids = set(user_profile['followers_youknow'] + user_profile['followers_everybody'] + 
                      user_profile['following_youknow'] + user_profile['following_everybody'])
    profiles = MSocialProfile.profiles(profile_ids)
    activities = MActivity.user(user_id, page=1, public=True)
    activities_html = render_to_string('reader/activities_module.xhtml', {
        'activities': activities,
        'username': user_profile['username'],
        'public': True,
    })
    logging.user(request, "~BB~FRLoading social profile: %s" % user_profile['username'])
        
    payload = {
        'user_profile': user_profile,
        # XXX TODO: Remove following 4 vestigial params.
        'followers_youknow': user_profile['followers_youknow'],
        'followers_everybody': user_profile['followers_everybody'],
        'following_youknow': user_profile['following_youknow'],
        'following_everybody': user_profile['following_everybody'],
        'profiles': dict([(p.user_id, p.to_json(compact=True)) for p in profiles]),
        'activities': activities,
        'activities_html': activities_html,
    }
    return payload

@ajax_login_required
@json.json_view
def load_user_profile(request):
    social_profile, _ = MSocialProfile.objects.get_or_create(user_id=request.user.pk)
    social_services, _ = MSocialServices.objects.get_or_create(user_id=request.user.pk)
    
    return {
        'services': social_services,
        'user_profile': social_profile.to_json(full=True),
    }
    
@ajax_login_required
@json.json_view
def save_user_profile(request):
    data = request.POST

    profile, _ = MSocialProfile.objects.get_or_create(user_id=request.user.pk)
    profile.location = data['location']
    profile.bio = data['bio']
    profile.website = data['website']
    profile.save()

    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    profile = social_services.set_photo(data['photo_service'])
    
    logging.user(request, "~BB~FRSaving social profile")
    
    return dict(code=1, user_profile=profile.to_json(full=True))

@json.json_view
def load_user_friends(request):
    user = get_user(request.user)
    social_profile, _ = MSocialProfile.objects.get_or_create(user_id=user.pk)
    social_services, _ = MSocialServices.objects.get_or_create(user_id=user.pk)
    following_profiles = MSocialProfile.profiles(social_profile.following_user_ids)
    follower_profiles = MSocialProfile.profiles(social_profile.follower_user_ids)
    recommended_users = social_profile.recommended_users()

    return {
        'services': social_services,
        'autofollow': social_services.autofollow,
        'user_profile': social_profile.to_json(full=True),
        'following_profiles': following_profiles,
        'follower_profiles': follower_profiles,
        'recommended_users': recommended_users,
    }

@ajax_login_required
@json.json_view
def follow(request):
    profile, _ = MSocialProfile.objects.get_or_create(user_id=request.user.pk)
    user_id = request.POST['user_id']
    try:
        follow_user_id = int(user_id)
    except ValueError:
        try:
            follow_user_id = int(user_id.replace('social:', ''))
            follow_profile = MSocialProfile.objects.get(user_id=follow_user_id)
        except (ValueError, MSocialProfile.DoesNotExist):
            follow_username = user_id.replace('social:', '')
            try:
                follow_profile = MSocialProfile.objects.get(username=follow_username)
            except MSocialProfile.DoesNotExist:
                raise Http404
            follow_user_id = follow_profile.user_id

    profile.follow_user(follow_user_id)
    follow_profile = MSocialProfile.objects.get(user_id=follow_user_id)
    
    social_params = {
        'user_id': request.user.pk,
        'subscription_user_id': follow_user_id,
        'include_favicon': True,
        'update_counts': True,
    }
    follow_subscription = MSocialSubscription.feeds(calculate_scores=True, **social_params)
    
    logging.user(request, "~BB~FRFollowing: %s" % follow_profile.username)
    
    return {
        "user_profile": profile.to_json(full=True), 
        "follow_profile": follow_profile.to_json(common_follows_with_user=request.user.pk),
        "follow_subscription": follow_subscription,
    }
    
@ajax_login_required
@json.json_view
def unfollow(request):
    profile = MSocialProfile.objects.get(user_id=request.user.pk)
    user_id = request.POST['user_id']
    try:
        unfollow_user_id = int(user_id)
    except ValueError:
        try:
            unfollow_user_id = int(user_id.replace('social:', ''))
            unfollow_profile = MSocialProfile.objects.get(user_id=unfollow_user_id)
        except (ValueError, MSocialProfile.DoesNotExist):
            unfollow_username = user_id.replace('social:', '')
            try:
                unfollow_profile = MSocialProfile.objects.get(username=unfollow_username)
            except MSocialProfile.DoesNotExist:
                raise Http404
            unfollow_user_id = unfollow_profile.user_id
        
    profile.unfollow_user(unfollow_user_id)
    unfollow_profile = MSocialProfile.objects.get(user_id=unfollow_user_id)
    
    logging.user(request, "~BB~FRUnfollowing: %s" % unfollow_profile.username)
    
    return {
        'user_profile': profile.to_json(full=True),
        'unfollow_profile': unfollow_profile.to_json(common_follows_with_user=request.user.pk),
    }

@json.json_view
def find_friends(request):
    query = request.GET.get('query')
    profiles = MSocialProfile.objects.filter(username__icontains=query)[:3]
    if not profiles:
        profiles = MSocialProfile.objects.filter(email__icontains=query)[:3]
    if not profiles:
        profiles = MSocialProfile.objects.filter(blog_title__icontains=query)[:3]
    
    return dict(profiles=profiles)
    
def shared_stories_rss_feed(request, user_id, username):
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        raise Http404
    
    if user.username != username:
        profile = MSocialProfile.objects.get(user_id=user.pk)
        params = {'username': profile.username_slug, 'user_id': user.pk}
        return HttpResponseRedirect(reverse('shared-stories-rss-feed', kwargs=params))

    social_profile = MSocialProfile.objects.get(user_id=user_id)

    data = {}
    data['title'] = social_profile.title
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
    
    logging.user(user, "~FGLoading social trainer on ~SB%s: %s" % (
                 social_user.username, social_profile.title))
    
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
    
    logging.user(request, "~FBStatistics social: ~SB%s ~FG(%s subs)" % (
                 social_profile.user_id, social_profile.follower_count))

    return stats

@json.json_view
def load_social_settings(request, social_user_id, username=None):
    social_profile = MSocialProfile.objects.get(user_id=social_user_id)
    
    return social_profile.to_json()

@render_to('reader/interactions_module.xhtml')
def load_interactions(request):
    user = get_user(request)
    page = max(1, int(request.REQUEST.get('page', 1)))
    interactions = MInteraction.user(user.pk, page=page)

    return {
        'interactions': interactions,
        'page': page,
    }
