import time
import datetime
import zlib
import random
from bson.objectid import ObjectId
from django.shortcuts import get_object_or_404, render_to_response
from django.core.urlresolvers import reverse
from django.contrib.auth.models import User
from django.template.loader import render_to_string
from django.http import HttpResponse, HttpResponseRedirect, Http404
from django.conf import settings
from django.template import RequestContext
from apps.rss_feeds.models import MStory, Feed, MStarredStory
from apps.social.models import MSharedStory, MSocialServices, MSocialProfile, MSocialSubscription, MCommentReply
from apps.social.models import MInteraction, MActivity
from apps.social.tasks import PostToService, EmailCommentReplies, EmailStoryReshares
from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds, apply_classifier_authors, apply_classifier_tags
from apps.analyzer.models import get_classifiers_for_user, sort_classifiers_by_feed
from apps.reader.models import MUserStory, UserSubscription
from apps.profile.models import Profile
from utils import json_functions as json
from utils import log as logging
from utils import PyRSS2Gen as RSS
from utils.user_functions import get_user, ajax_login_required
from utils.view_functions import render_to
from utils.story_functions import format_story_link_date__short
from utils.story_functions import format_story_link_date__long
from utils.story_functions import strip_tags
from utils import jennyholzer
from vendor.timezones.utilities import localtime_for_timezone

    
@json.json_view
def load_social_stories(request, user_id, username=None):
    start          = time.time()
    user           = get_user(request)
    social_user_id = int(user_id)
    social_user    = get_object_or_404(User, pk=social_user_id)
    offset         = int(request.REQUEST.get('offset', 0))
    limit          = int(request.REQUEST.get('limit', 6))
    page           = request.REQUEST.get('page')
    order          = request.REQUEST.get('order', 'newest')
    read_filter    = request.REQUEST.get('read_filter', 'all')
    stories        = []
    
    if page: offset = limit * (int(page) - 1)
    now = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)
    UNREAD_CUTOFF = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
    
    social_profile = MSocialProfile.get_user(social_user.pk)
    try:
        socialsub = MSocialSubscription.objects.get(user_id=user.pk, subscription_user_id=social_user_id)
    except MSocialSubscription.DoesNotExist:
        socialsub = None
    mstories = MSharedStory.objects(user_id=social_user.pk).order_by('-shared_date')[offset:offset+limit]
    stories = Feed.format_stories(mstories)
    
    if socialsub and (read_filter == 'unread' or order == 'oldest'):
        story_ids = socialsub.get_stories(order=order, read_filter=read_filter, offset=offset, limit=limit)
        story_date_order = "%sshared_date" % ('' if order == 'oldest' else '-')
        if story_ids:
            mstories = MSharedStory.objects(user_id=social_user.pk,
                                            story_db_id__in=story_ids).order_by(story_date_order)
            stories = Feed.format_stories(mstories)
    else:
        mstories = MSharedStory.objects(user_id=social_user.pk).order_by('-shared_date')[offset:offset+limit]
        stories = Feed.format_stories(mstories)

    if not stories:
        return dict(stories=[])
    
    checkpoint1 = time.time()
    
    stories, user_profiles = MSharedStory.stories_with_comments_and_profiles(stories, user.pk, check_all=True)

    story_feed_ids = list(set(s['story_feed_id'] for s in stories))
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

    checkpoint2 = time.time()
    
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

        if story['id'] in starred_stories:
            story['starred'] = True
            starred_date = localtime_for_timezone(starred_stories[story['id']], user.profile.timezone)
            story['starred_date'] = format_story_link_date__long(starred_date, now)
        if story['id'] in shared_stories:
            story['shared'] = True
            shared_date = localtime_for_timezone(shared_stories[story['id']]['shared_date'],
                                                 user.profile.timezone)
            story['shared_date'] = format_story_link_date__long(shared_date, now)
            story['shared_comments'] = strip_tags(shared_stories[story['id']]['comments'])

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
    
    diff1 = checkpoint1-start
    diff2 = checkpoint2-start
    logging.user(request, "~FYLoading ~FMshared stories~FY: ~SB%s%s ~SN(~SB%.4ss/%.4ss~SN)" % (
    social_profile.title[:22], ('~SN/p%s' % page) if page > 1 else '', diff1, diff2))

    return {
        "stories": stories, 
        "user_profiles": user_profiles, 
        "feeds": unsub_feeds, 
        "classifiers": classifiers,
    }
    
@json.json_view
def load_river_blurblog(request):
    limit             = 10
    start             = time.time()
    user              = get_user(request)
    social_user_ids   = [int(uid) for uid in request.REQUEST.getlist('social_user_ids') if uid]
    original_user_ids = list(social_user_ids)
    page              = int(request.REQUEST.get('page', 1))
    order             = request.REQUEST.get('order', 'newest')
    read_filter       = request.REQUEST.get('read_filter', 'unread')
    relative_user_id  = request.REQUEST.get('relative_user_id', None)
    now               = localtime_for_timezone(datetime.datetime.now(), user.profile.timezone)
    UNREAD_CUTOFF     = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)

    if not relative_user_id:
        relative_user_id = get_user(request).pk

    if not social_user_ids:
        socialsubs = MSocialSubscription.objects.filter(user_id=user.pk) 
        social_user_ids = [s.subscription_user_id for s in socialsubs]
        
    offset = (page-1) * limit
    limit = page * limit - 1
    
    story_ids, story_dates = MSocialSubscription.feed_stories(user.pk, social_user_ids, 
                                                 offset=offset, limit=limit,
                                                 order=order, read_filter=read_filter)
    mstories = MStory.objects(id__in=story_ids)
    stories = Feed.format_stories(mstories)
    for s, story in enumerate(stories):
        story['story_date'] = datetime.datetime.fromtimestamp(story_dates[s])
    stories, user_profiles = MSharedStory.stories_with_comments_and_profiles(stories, relative_user_id, 
                                                                             check_all=True)

    story_feed_ids = list(set(s['story_feed_id'] for s in stories))
    usersubs = UserSubscription.objects.filter(user__pk=user.pk, feed__pk__in=story_feed_ids)
    usersubs_map = dict((sub.feed_id, sub) for sub in usersubs)
    unsub_feed_ids = list(set(story_feed_ids).difference(set(usersubs_map.keys())))
    unsub_feeds = Feed.objects.filter(pk__in=unsub_feed_ids)
    unsub_feeds = [feed.canonical(include_favicon=False) for feed in unsub_feeds]
    date_delta = UNREAD_CUTOFF
    
    # Find starred stories
    if story_feed_ids:
        starred_stories = MStarredStory.objects(
            user_id=user.pk,
            story_feed_id__in=story_feed_ids
        ).only('story_guid', 'starred_date')
        starred_stories = dict([(story.story_guid, story.starred_date) 
                                for story in starred_stories])
        story_ids = [story['id'] for story in stories]
        userstories_db = MUserStory.objects(user_id=user.pk,
                                            feed_id__in=story_feed_ids,
                                            story_id__in=story_ids).only('story_id')
        userstories = set(us.story_id for us in userstories_db)
    else:
        starred_stories = {}
        userstories = []
    
    # Intelligence classifiers for all feeds involved
    if story_feed_ids:
        classifier_feeds = list(MClassifierFeed.objects(user_id=user.pk,
                                                   feed_id__in=story_feed_ids))
        classifier_authors = list(MClassifierAuthor.objects(user_id=user.pk, 
                                                       feed_id__in=story_feed_ids))
        classifier_titles = list(MClassifierTitle.objects(user_id=user.pk, 
                                                     feed_id__in=story_feed_ids))
        classifier_tags = list(MClassifierTag.objects(user_id=user.pk, 
                                                 feed_id__in=story_feed_ids))
    else:
        classifier_feeds = []
        classifier_authors = []
        classifier_titles = []
        classifier_tags = []
    classifiers = sort_classifiers_by_feed(user=user, feed_ids=story_feed_ids,
                                           classifier_feeds=classifier_feeds,
                                           classifier_authors=classifier_authors,
                                           classifier_titles=classifier_titles,
                                           classifier_tags=classifier_tags)
    
    # Just need to format stories
    for story in stories:
        if story['id'] in userstories:
            story['read_status'] = 1
        else:
            story['read_status'] = 0
        story_date = localtime_for_timezone(story['story_date'], user.profile.timezone)
        story['short_parsed_date'] = format_story_link_date__short(story_date, now)
        story['long_parsed_date']  = format_story_link_date__long(story_date, now)
        if story['id'] in starred_stories:
            story['starred'] = True
            starred_date = localtime_for_timezone(starred_stories[story['id']], user.profile.timezone)
            story['starred_date'] = format_story_link_date__long(starred_date, now)
        story['intelligence'] = {
            'feed':   apply_classifier_feeds(classifier_feeds, story['story_feed_id']),
            'author': apply_classifier_authors(classifier_authors, story),
            'tags':   apply_classifier_tags(classifier_tags, story),
            'title':  apply_classifier_titles(classifier_titles, story),
        }

    diff = time.time() - start
    timediff = round(float(diff), 2)
    logging.user(request, "~FYLoading ~FCriver blurblogs stories~FY: ~SBp%s~SN (%s/%s "
                               "stories, ~SN%s/%s/%s feeds)" % 
                               (page, len(stories), len(mstories), len(story_feed_ids), 
                               len(social_user_ids), len(original_user_ids)))
    
    
    return {
        "stories": stories, 
        "user_profiles": user_profiles, 
        "feeds": unsub_feeds, 
        "classifiers": classifiers,
        "elapsed_time": timediff,
    }
    
def load_social_page(request, user_id, username=None, **kwargs):
    start = time.time()
    user = request.user
    social_user_id = int(user_id)
    social_user = get_object_or_404(User, pk=social_user_id)
    offset = int(request.REQUEST.get('offset', 0))
    limit = int(request.REQUEST.get('limit', 6))
    page = request.REQUEST.get('page')
    format = request.REQUEST.get('format', None)
    has_next_page = False
    feed_id = kwargs.get('feed_id') or request.REQUEST.get('feed_id')
    if page: offset = limit * (int(page) - 1)

    user_social_profile = None
    if user.is_authenticated():
        user_social_profile = MSocialProfile.get_user(user.pk)
    social_profile = MSocialProfile.get_user(social_user_id)
    params = dict(user_id=social_user.pk)
    if feed_id:
        params['story_feed_id'] = feed_id
    mstories = MSharedStory.objects(**params).order_by('-shared_date')[offset:offset+limit+1]
    stories = Feed.format_stories(mstories)
    if len(stories) > limit:
        has_next_page = True
        stories = stories[:-1]

    checkpoint1 = time.time()

    if not stories:
        params = {
            "user": user,
            "stories": [],
            "feeds": {},
            "social_user": social_user,
            "social_profile": social_profile,
            'user_social_profile' : json.encode(user_social_profile and user_social_profile.page()),
        }
        template = 'social/social_page.xhtml'
        return render_to_response(template, params, context_instance=RequestContext(request))

    story_feed_ids = list(set(s['story_feed_id'] for s in stories))
    feeds = Feed.objects.filter(pk__in=story_feed_ids)
    feeds = dict((feed.pk, feed.canonical(include_favicon=False)) for feed in feeds)
    for story in stories:
        if story['story_feed_id'] in feeds:
            # Feed could have been deleted.
            story['feed'] = feeds[story['story_feed_id']]
        shared_date = localtime_for_timezone(story['shared_date'], social_user.profile.timezone)
        story['shared_date'] = shared_date
    
    stories, profiles = MSharedStory.stories_with_comments_and_profiles(stories, social_user.pk, 
                                                                        check_all=True)

    checkpoint2 = time.time()
    
    if user.is_authenticated():
        for story in stories:
            if user.pk in story['shared_by_friends'] or user.pk in story['shared_by_public']:
                story['shared_by_user'] = True
                shared_story = MSharedStory.objects.get(user_id=user.pk, 
                                                        story_feed_id=story['story_feed_id'],
                                                        story_guid=story['id'])
                story['user_comments'] = shared_story.comments

    stories = MSharedStory.attach_users_to_stories(stories, profiles)

    params = {
        'social_user'   : social_user,
        'stories'       : stories,
        'user_social_profile' : user_social_profile,
        'user_social_profile_page' : json.encode(user_social_profile and user_social_profile.page()),
        'social_profile': social_profile,
        'feeds'         : feeds,
        'user_profile'  : hasattr(user, 'profile') and user.profile,
        'has_next_page' : has_next_page,
        'holzer_truism' : random.choice(jennyholzer.TRUISMS) #if not has_next_page else None
    }

    diff1 = checkpoint1-start
    diff2 = checkpoint2-start
    timediff = time.time()-start
    logging.user(request, "~FYLoading ~FMsocial page~FY: ~SB%s%s ~SN(%.4s seconds, ~SB%.4s/%.4s~SN)" % (
        social_profile.title[:22], ('~SN/p%s' % page) if page > 1 else '', timediff,
        diff1, diff2))
    if format == 'html':
        template = 'social/social_stories.xhtml'
    else:
        template = 'social/social_page.xhtml'
        
    return render_to_response(template, params, context_instance=RequestContext(request))
    
def story_public_comments(request):
    format           = request.REQUEST.get('format', 'json')
    relative_user_id = request.REQUEST.get('user_id', None)
    feed_id          = int(request.REQUEST['feed_id'])
    story_id         = request.REQUEST['story_id']
  
    if not relative_user_id:
        relative_user_id = get_user(request).pk
    
    stories = MSharedStory.objects.filter(story_feed_id=feed_id, story_guid=story_id).limit(1)
    stories = Feed.format_stories(stories)
    stories, profiles = MSharedStory.stories_with_comments_and_profiles(stories, relative_user_id, 
                                                                        check_all=True,
                                                                        public=True)

    if format == 'html':
        stories = MSharedStory.attach_users_to_stories(stories, profiles)
        return render_to_response('social/story_comments.xhtml', {
            'story': stories[0],
        }, context_instance=RequestContext(request))
    else:
        return json.json_response(request, {
            'comments': stories[0]['public_comments'], 
            'user_profiles': profiles,
        })

@ajax_login_required
def mark_story_as_shared(request):
    code     = 1
    feed_id  = int(request.POST['feed_id'])
    story_id = request.POST['story_id']
    comments = request.POST.get('comments', '')
    source_user_id = request.POST.get('source_user_id')
    relative_user_id = request.POST.get('relative_user_id') or request.user.pk
    post_to_services = request.POST.getlist('post_to_services')
    format = request.REQUEST.get('format', 'json')
    
    MSocialProfile.get_user(request.user.pk)
    
    story, original_story_found = MStory.find_story(feed_id, story_id)

    if not story:
        return json.json_response(request, {
            'code': -1, 
            'message': 'Could not find the original story and no copies could be found.'
        })
    
    shared_story = MSharedStory.objects.filter(user_id=request.user.pk, 
                                               story_feed_id=feed_id, 
                                               story_guid=story_id).limit(1).first()
    if not shared_story:
        story_db = dict([(k, v) for k, v in story._data.items() 
                                if k is not None and v is not None])
        story_values = dict(user_id=request.user.pk, comments=comments, 
                            has_comments=bool(comments), story_db_id=story.id)
        story_db.update(story_values)
        shared_story = MSharedStory.objects.create(**story_db)
        if source_user_id:
            shared_story.set_source_user_id(int(source_user_id))
        socialsubs = MSocialSubscription.objects.filter(subscription_user_id=request.user.pk)
        for socialsub in socialsubs:
            socialsub.needs_unread_recalc = True
            socialsub.save()
        logging.user(request, "~FCSharing ~FM%s: ~SB~FB%s" % (story.story_title[:20], comments[:30]))
    else:
        shared_story.comments = comments
        shared_story.has_comments = bool(comments)
        shared_story.save()
        logging.user(request, "~FCUpdating shared story ~FM%s: ~SB~FB%s" % (
                     story.story_title[:20], comments[:30]))
    
    if original_story_found:
        story.count_comments()
    shared_story.publish_update_to_subscribers()
    
    story = Feed.format_story(story)
    check_all = not original_story_found
    stories, profiles = MSharedStory.stories_with_comments_and_profiles([story], relative_user_id,
                                                                        check_all=check_all)
    story = stories[0]
    story['shared_comments'] = strip_tags(shared_story['comments'] or "")
    story['shared_by_user'] = True
    
    if post_to_services:
        for service in post_to_services:
            if service not in shared_story.posted_to_services:
                PostToService.delay(shared_story_id=shared_story.id, service=service)
    
    if shared_story.source_user_id and shared_story.comments:
        EmailStoryReshares.apply_async(kwargs=dict(shared_story_id=shared_story.id),
                                       countdown=settings.SECONDS_TO_DELAY_CELERY_EMAILS)
    
    if format == 'html':
        stories = MSharedStory.attach_users_to_stories(stories, profiles)
        return render_to_response('social/social_story.xhtml', {
            'story': story,
        }, context_instance=RequestContext(request))
    else:
        return json.json_response(request, {
            'code': code, 
            'story': story, 
            'user_profiles': profiles,
        })

@ajax_login_required
def mark_story_as_unshared(request):
    feed_id  = int(request.POST['feed_id'])
    story_id = request.POST['story_id']
    relative_user_id = request.POST.get('relative_user_id') or request.user.pk
    format = request.REQUEST.get('format', 'json')
    original_story_found = True
    
    story = MStory.objects(story_feed_id=feed_id, story_guid=story_id).limit(1).first()
    if not story:
        original_story_found = False
        
    shared_story = MSharedStory.objects(user_id=request.user.pk, 
                                        story_feed_id=feed_id, 
                                        story_guid=story_id).limit(1).first()
    if not shared_story:
        return json.json_response(request, {'code': -1, 'message': 'Shared story not found.'})
    
    socialsubs = MSocialSubscription.objects.filter(subscription_user_id=request.user.pk)
    for socialsub in socialsubs:
        socialsub.needs_unread_recalc = True
        socialsub.save()
    logging.user(request, "~FC~SKUn-sharing ~FM%s: ~SB~FB%s" % (shared_story.story_title[:20],
                                                                shared_story.comments[:30]))
    shared_story.delete()
    
    if original_story_found:
        story.count_comments()
    else:
        story = shared_story
    
    story = Feed.format_story(story)
    stories, profiles = MSharedStory.stories_with_comments_and_profiles([story], 
                                                                        relative_user_id, 
                                                                        check_all=True)

    if format == 'html':
        stories = MSharedStory.attach_users_to_stories(stories, profiles)
        return render_to_response('social/social_story.xhtml', {
            'story': stories[0],
        }, context_instance=RequestContext(request))
    else:
        return json.json_response(request, {
            'code': 1, 
            'message': "Story unshared.", 
            'story': stories[0], 
            'user_profiles': profiles,
        })
    
@ajax_login_required
def save_comment_reply(request):
    code     = 1
    feed_id  = int(request.POST['story_feed_id'])
    story_id = request.POST['story_id']
    comment_user_id = request.POST['comment_user_id']
    reply_comments = request.POST.get('reply_comments')
    reply_id = request.POST.get('reply_id')
    format = request.REQUEST.get('format', 'json')
    original_message = None
    
    if not reply_comments:
        return json.json_response(request, {'code': -1, 'message': 'Reply comments cannot be empty.'})
        
    shared_story = MSharedStory.objects.get(user_id=comment_user_id, 
                                            story_feed_id=feed_id, 
                                            story_guid=story_id)
    reply = MCommentReply()
    reply.user_id = request.user.pk
    reply.publish_date = datetime.datetime.now()
    reply.comments = reply_comments
    
    if reply_id:
        replies = []
        for story_reply in shared_story.replies:
            if (story_reply.user_id == reply.user_id and 
                story_reply.reply_id == ObjectId(reply_id)):
                reply.publish_date = story_reply.publish_date
                reply.reply_id = story_reply.reply_id
                original_message = story_reply.comments
                replies.append(reply)
            else:
                replies.append(story_reply)
        shared_story.replies = replies
        logging.user(request, "~FCUpdating comment reply in ~FM%s: ~SB~FB%s~FM" % (
                 shared_story.story_title[:20], reply_comments[:30]))
    else:
        reply.reply_id = ObjectId()
        logging.user(request, "~FCReplying to comment in: ~FM%s: ~SB~FB%s~FM" % (
                     shared_story.story_title[:20], reply_comments[:30]))
        shared_story.replies.append(reply)
    shared_story.save()
    
    comment, profiles = shared_story.comment_with_author_and_profiles()
    
    # Interaction for every other replier and original commenter
    MActivity.new_comment_reply(user_id=request.user.pk,
                                comment_user_id=comment['user_id'],
                                reply_content=reply_comments,
                                original_message=original_message,
                                story_id=story_id,
                                story_feed_id=feed_id,
                                story_title=shared_story.story_title)
    if comment['user_id'] != request.user.pk:
        MInteraction.new_comment_reply(user_id=comment['user_id'], 
                                       reply_user_id=request.user.pk, 
                                       reply_content=reply_comments,
                                       original_message=original_message,
                                       story_id=story_id,
                                       story_feed_id=feed_id,
                                       story_title=shared_story.story_title)

    reply_user_ids = list(r['user_id'] for r in comment['replies'])
    for user_id in set(reply_user_ids).difference([comment['user_id']]):
        if request.user.pk != user_id:
            MInteraction.new_reply_reply(user_id=user_id, 
                                         comment_user_id=comment['user_id'],
                                         reply_user_id=request.user.pk, 
                                         reply_content=reply_comments,
                                         original_message=original_message,
                                         story_id=story_id,
                                         story_feed_id=feed_id,
                                         story_title=shared_story.story_title)

    EmailCommentReplies.apply_async(kwargs=dict(shared_story_id=shared_story.id,
                                                reply_id=reply.reply_id), 
                                                countdown=settings.SECONDS_TO_DELAY_CELERY_EMAILS)
    
    if format == 'html':
        comment = MSharedStory.attach_users_to_comment(comment, profiles)
        return render_to_response('social/story_comment.xhtml', {
            'comment': comment,
        }, context_instance=RequestContext(request))
    else:
        return json.json_response(request, {
            'code': code, 
            'comment': comment, 
            'reply_id': reply.reply_id,
            'user_profiles': profiles
        })

@ajax_login_required
def remove_comment_reply(request):
    code     = 1
    feed_id  = int(request.POST['story_feed_id'])
    story_id = request.POST['story_id']
    comment_user_id = request.POST['comment_user_id']
    reply_id = request.POST.get('reply_id')
    format = request.REQUEST.get('format', 'json')
    original_message = None
    
    shared_story = MSharedStory.objects.get(user_id=comment_user_id, 
                                            story_feed_id=feed_id, 
                                            story_guid=story_id)
    replies = []
    for story_reply in shared_story.replies:
        if ((story_reply.user_id == request.user.pk or request.user.is_staff) and 
            story_reply.reply_id == ObjectId(reply_id)):
            original_message = story_reply.comments
            # Skip reply
        else:
            replies.append(story_reply)
    shared_story.replies = replies
    shared_story.save()

    logging.user(request, "~FCRemoving comment reply in ~FM%s: ~SB~FB%s~FM" % (
             shared_story.story_title[:20], original_message and original_message[:30]))
    
    comment, profiles = shared_story.comment_with_author_and_profiles()

    # Interaction for every other replier and original commenter
    MActivity.remove_comment_reply(user_id=request.user.pk,
                                   comment_user_id=comment['user_id'],
                                   reply_content=original_message,
                                   story_id=story_id,
                                   story_feed_id=feed_id)
    MInteraction.remove_comment_reply(user_id=comment['user_id'], 
                                      reply_user_id=request.user.pk, 
                                      reply_content=original_message,
                                      story_id=story_id,
                                      story_feed_id=feed_id)
    
    reply_user_ids = [reply['user_id'] for reply in comment['replies']]
    for user_id in set(reply_user_ids).difference([comment['user_id']]):
        if request.user.pk != user_id:
            MInteraction.remove_reply_reply(user_id=user_id, 
                                            comment_user_id=comment['user_id'],
                                            reply_user_id=request.user.pk, 
                                            reply_content=original_message,
                                            story_id=story_id,
                                            story_feed_id=feed_id)
    
    if format == 'html':
        comment = MSharedStory.attach_users_to_comment(comment, profiles)
        return render_to_response('social/story_comment.xhtml', {
            'comment': comment,
        }, context_instance=RequestContext(request))
    else:
        return json.json_response(request, {
            'code': code, 
            'comment': comment, 
            'user_profiles': profiles
        })
        
@render_to('social/mute_story.xhtml')
def mute_story(request, secret_token, shared_story_id):
    user_profile = Profile.objects.get(secret_token=secret_token)
    shared_story = MSharedStory.objects.get(id=shared_story_id)
    shared_story.mute_for_user(user_profile.user_id)
    
    return {}
    
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
    include_activities_html = request.REQUEST.get('include_activities_html', None)

    user_profile = MSocialProfile.get_user(user_id)
    user_profile.count_follows()
    user_profile = user_profile.to_json(include_follows=True, common_follows_with_user=user.pk)
    profile_ids = set(user_profile['followers_youknow'] + user_profile['followers_everybody'] + 
                      user_profile['following_youknow'] + user_profile['following_everybody'])
    profiles = MSocialProfile.profiles(profile_ids)
    activities, _ = MActivity.user(user_id, page=1, public=True)
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
    }
    
    if include_activities_html:
        payload['activities_html'] = render_to_string('reader/activities_module.xhtml', {
            'activities': activities,
            'username': user_profile['username'],
            'public': True,
        })
    
    return payload

@ajax_login_required
@json.json_view
def load_user_profile(request):
    social_profile = MSocialProfile.get_user(request.user.pk)
    social_services, _ = MSocialServices.objects.get_or_create(user_id=request.user.pk)
    
    logging.user(request, "~BB~FRLoading social profile and blurblog settings")
    
    return {
        'services': social_services,
        'user_profile': social_profile.to_json(include_follows=True, include_settings=True),
    }
    
@ajax_login_required
@json.json_view
def save_user_profile(request):
    data = request.POST
    website = data['website']
    
    if website and not website.startswith('http'):
        website = 'http://' + website
    
    profile = MSocialProfile.get_user(request.user.pk)
    profile.location = data['location']
    profile.bio = data['bio']
    profile.website = website
    profile.save()

    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    profile = social_services.set_photo(data['photo_service'])
    
    logging.user(request, "~BB~FRSaving social profile")
    
    return dict(code=1, user_profile=profile.to_json(include_follows=True))

    
@ajax_login_required
@json.json_view
def save_blurblog_settings(request):
    data = request.POST

    profile = MSocialProfile.get_user(request.user.pk)
    profile.custom_css = data.get('custom_css', None)
    profile.custom_bgcolor = data.get('custom_bgcolor', None)
    profile.blurblog_title = data.get('blurblog_title', None)
    profile.save()

    logging.user(request, "~BB~FRSaving blurblog settings")
    
    return dict(code=1, user_profile=profile.to_json(include_follows=True, include_settings=True))

@json.json_view
def load_user_friends(request):
    user = get_user(request.user)
    social_profile, _  = MSocialProfile.objects.get_or_create(user_id=user.pk)
    social_services, _ = MSocialServices.objects.get_or_create(user_id=user.pk)
    following_profiles = MSocialProfile.profiles(social_profile.following_user_ids)
    follower_profiles  = MSocialProfile.profiles(social_profile.follower_user_ids)
    recommended_users  = social_profile.recommended_users()
    
    following_profiles = [p.to_json(include_following_user=user.pk) for p in following_profiles]
    follower_profiles  = [p.to_json(include_following_user=user.pk) for p in follower_profiles]
    
    logging.user(request, "~BB~FRLoading Friends (%s following, %s followers)" % (
        social_profile.following_count,
        social_profile.follower_count,
    ))

    return {
        'services': social_services,
        'autofollow': social_services.autofollow,
        'user_profile': social_profile.to_json(include_follows=True),
        'following_profiles': following_profiles,
        'follower_profiles': follower_profiles,
        'recommended_users': recommended_users,
    }

@ajax_login_required
@json.json_view
def follow(request):
    profile = MSocialProfile.get_user(request.user.pk)
    user_id = request.POST['user_id']
    try:
        follow_user_id = int(user_id)
    except ValueError:
        try:
            follow_user_id = int(user_id.replace('social:', ''))
            follow_profile = MSocialProfile.get_user(follow_user_id)
        except (ValueError, MSocialProfile.DoesNotExist):
            follow_username = user_id.replace('social:', '')
            try:
                follow_profile = MSocialProfile.objects.get(username=follow_username)
            except MSocialProfile.DoesNotExist:
                raise Http404
            follow_user_id = follow_profile.user_id

    profile.follow_user(follow_user_id)
    follow_profile = MSocialProfile.get_user(follow_user_id)
    
    social_params = {
        'user_id': request.user.pk,
        'subscription_user_id': follow_user_id,
        'include_favicon': True,
        'update_counts': True,
    }
    follow_subscription = MSocialSubscription.feeds(calculate_all_scores=True, **social_params)
    
    logging.user(request, "~BB~FRFollowing: %s" % follow_profile.username)
    
    return {
        "user_profile": profile.to_json(include_follows=True), 
        "follow_profile": follow_profile.to_json(common_follows_with_user=request.user.pk),
        "follow_subscription": follow_subscription,
    }
    
@ajax_login_required
@json.json_view
def unfollow(request):
    profile = MSocialProfile.get_user(request.user.pk)
    user_id = request.POST['user_id']
    try:
        unfollow_user_id = int(user_id)
    except ValueError:
        try:
            unfollow_user_id = int(user_id.replace('social:', ''))
            unfollow_profile = MSocialProfile.get_user(unfollow_user_id)
        except (ValueError, MSocialProfile.DoesNotExist):
            unfollow_username = user_id.replace('social:', '')
            try:
                unfollow_profile = MSocialProfile.objects.get(username=unfollow_username)
            except MSocialProfile.DoesNotExist:
                raise Http404
            unfollow_user_id = unfollow_profile.user_id
        
    profile.unfollow_user(unfollow_user_id)
    unfollow_profile = MSocialProfile.get_user(unfollow_user_id)
    
    logging.user(request, "~BB~FRUnfollowing: %s" % unfollow_profile.username)
    
    return {
        'user_profile': profile.to_json(include_follows=True),
        'unfollow_profile': unfollow_profile.to_json(common_follows_with_user=request.user.pk),
    }

@json.json_view
def find_friends(request):
    query = request.GET.get('query')
    limit = int(request.GET.get('limit', 3))
    profiles = MSocialProfile.objects.filter(username__icontains=query)[:limit]
    if not profiles:
        profiles = MSocialProfile.objects.filter(email__icontains=query)[:limit]
    if not profiles:
        profiles = MSocialProfile.objects.filter(blurblog_title__icontains=query)[:limit]
    
    profiles = [p.to_json(include_following_user=request.user.pk) for p in profiles]
    profiles = sorted(profiles, key=lambda p: -1 * p['shared_stories_count'])

    return dict(profiles=profiles)

@ajax_login_required
def like_comment(request):
    code     = 1
    feed_id  = int(request.POST['story_feed_id'])
    story_id = request.POST['story_id']
    comment_user_id = request.POST['comment_user_id']
    format = request.REQUEST.get('format', 'json')
    
    if comment_user_id == request.user.pk:
        return json.json_response(request, {'code': -1, 'message': 'You cannot favorite your own shared story comment.'})
        
    shared_story = MSharedStory.objects.get(user_id=comment_user_id, 
                                            story_feed_id=feed_id, 
                                            story_guid=story_id)
    shared_story.add_liking_user(request.user.pk)
    comment, profiles = shared_story.comment_with_author_and_profiles()

    comment_user = User.objects.get(pk=shared_story.user_id)
    logging.user(request, "~BB~FMLiking comment by ~SB%s~SN: %s" % (
        comment_user.username, 
        shared_story.comments[:30],
    ))

    MActivity.new_comment_like(liking_user_id=request.user.pk,
                               comment_user_id=comment['user_id'],
                               story_id=story_id,
                               story_title=shared_story.story_title,
                               comments=shared_story.comments)
    MInteraction.new_comment_like(liking_user_id=request.user.pk, 
                                  comment_user_id=comment['user_id'],
                                  story_id=story_id,
                                  story_title=shared_story.story_title,
                                  comments=shared_story.comments)
                                       
    if format == 'html':
        comment = MSharedStory.attach_users_to_comment(comment, profiles)
        return render_to_response('social/story_comment.xhtml', {
            'comment': comment,
        }, context_instance=RequestContext(request))
    else:
        return json.json_response(request, {
            'code': code, 
            'comment': comment, 
            'user_profiles': profiles,
        })
        
@ajax_login_required
def remove_like_comment(request):
    code     = 1
    feed_id  = int(request.POST['story_feed_id'])
    story_id = request.POST['story_id']
    comment_user_id = request.POST['comment_user_id']
    format = request.REQUEST.get('format', 'json')
    
    shared_story = MSharedStory.objects.get(user_id=comment_user_id, 
                                            story_feed_id=feed_id, 
                                            story_guid=story_id)
    shared_story.remove_liking_user(request.user.pk)
    comment, profiles = shared_story.comment_with_author_and_profiles()
    
    comment_user = User.objects.get(pk=shared_story.user_id)
    logging.user(request, "~BB~FMRemoving like on comment by ~SB%s~SN: %s" % (
        comment_user.username, 
        shared_story.comments[:30],
    ))
    
    if format == 'html':
        comment = MSharedStory.attach_users_to_comment(comment, profiles)
        return render_to_response('social/story_comment.xhtml', {
            'comment': comment,
        }, context_instance=RequestContext(request))
    else:
        return json.json_response(request, {
            'code': code, 
            'comment': comment, 
            'user_profiles': profiles,
        })
        
def shared_stories_rss_feed(request, user_id, username):
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        raise Http404
    
    username = username and username.lower()
    profile = MSocialProfile.get_user(user.pk)
    if not username or profile.username_slug.lower() != username:
        params = {'username': profile.username_slug, 'user_id': user.pk}
        return HttpResponseRedirect(reverse('shared-stories-rss-feed', kwargs=params))

    social_profile = MSocialProfile.get_user(user_id)

    data = {}
    data['title'] = social_profile.title
    data['link'] = social_profile.blurblog_url
    data['description'] = "Stories shared by %s on NewsBlur." % user.username
    data['lastBuildDate'] = datetime.datetime.utcnow()
    data['items'] = []
    data['generator'] = 'NewsBlur'
    data['docs'] = None

    shared_stories = MSharedStory.objects.filter(user_id=user.pk).order_by('-shared_date')[:25]
    for shared_story in shared_stories:
        story_data = {
            'title': shared_story.story_title,
            'link': shared_story.story_permalink,
            'description': shared_story.story_content_z and zlib.decompress(shared_story.story_content_z),
            'author': shared_story.story_author_name,
            'categories': shared_story.story_tags,
            'guid': shared_story.story_guid,
            'pubDate': shared_story.shared_date,
        }
        data['items'].append(RSS.RSSItem(**story_data))
        
    rss = RSS.RSS2(**data)
    
    return HttpResponse(rss.to_xml())

@json.json_view
def social_feed_trainer(request):
    social_user_id = request.REQUEST.get('user_id')
    social_profile = MSocialProfile.get_user(social_user_id)
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
    social_profile = MSocialProfile.get_user(social_user_id)
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
    social_profile = MSocialProfile.get_user(social_user_id)
    
    return social_profile.to_json()

@ajax_login_required
def load_interactions(request):
    user_id = request.REQUEST.get('user_id', None)
    if not user_id:
        user_id = get_user(request).pk
    page = max(1, int(request.REQUEST.get('page', 1)))
    limit = request.REQUEST.get('limit')
    interactions, has_next_page = MInteraction.user(user_id, page=page, limit=limit)
    format = request.REQUEST.get('format', None)
    
    data = {
        'interactions': interactions,
        'page': page,
        'has_next_page': has_next_page
    }
    
    if format == 'html':
        return render_to_response('reader/interactions_module.xhtml', data,
                                  context_instance=RequestContext(request))
    else:
        return json.json_response(request, data)

@ajax_login_required
def load_activities(request):
    user_id = request.REQUEST.get('user_id', None)
    if user_id:
        user_id = int(user_id)
        user = User.objects.get(pk=user_id)
    else:
        user = get_user(request)
        user_id = user.pk
        
    public = user_id != request.user.pk
    page = max(1, int(request.REQUEST.get('page', 1)))
    limit = request.REQUEST.get('limit', 4)
    activities, has_next_page = MActivity.user(user_id, page=page, limit=limit, public=public)
    format = request.REQUEST.get('format', None)
    
    data = {
        'activities': activities,
        'page': page,
        'has_next_page': has_next_page,
        'username': (user.username if public else 'You'),
    }
    
    if format == 'html':
        return render_to_response('reader/activities_module.xhtml', data,
                                  context_instance=RequestContext(request))
    else:
        return json.json_response(request, data)

@json.json_view
def comment(request, comment_id):
    try:
        shared_story = MSharedStory.objects.get(id=comment_id)
    except MSharedStory.DoesNotExist:
        raise Http404
    
    return shared_story.comments_with_author()