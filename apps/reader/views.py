from django.shortcuts import render_to_response, get_list_or_404, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.template import RequestContext
from apps.rss_feeds.models import Feed, Story
from django.core.cache import cache
from apps.reader.models import UserSubscription, UserSubscriptionFolders, UserStory
from utils.json import json_encode
from utils.user_functions import get_user
from django.contrib.auth.models import User
from django.http import HttpResponse, HttpRequest
from django.core import serializers 
from django.utils.safestring import mark_safe
from utils.feedcache.threading_model import fetch_feeds
from django.views.decorators.cache import cache_page
import logging
import datetime
import threading

SINGLE_DAY = 60*60*24
def index(request):
    # feeds = Feed.objects.filter(usersubscription__user=request.user)
    # for f in feeds:
    #     f.update()
        
    # context = feeds
    context = {}
    
    user = request.user
    user_info = _parse_user_info(user)
    context.update(user_info)
    return render_to_response('reader/feeds.xhtml', context,
                              context_instance=RequestContext(request))
    
def refresh_all_feeds(request):
    force_update = request.GET.get('force', False)
    feeds = Feed.objects.all()

    # t = threading.Thread(target=refresh_feeds,
    #                      args=[feeds, force_update])
    # t.setDaemon(True)
    # t.start()
    # t.join()
    
    refresh_feeds(feeds, force_update)
    context = {}
    
    user = request.user
    user_info = _parse_user_info(user)
    context.update(user_info)
    
    return render_to_response('reader/feeds.xhtml', context,
                              context_instance=RequestContext(request))

def refresh_feed(request):
    feed_id = request.REQUEST['feed_id']
    force_update = request.GET.get('force', False)
    feeds = Feed.objects.filter(id=feed_id)

    feeds = refresh_feeds(feeds, force_update)
    
    context = {}
    
    user = request.user 
    user_info = _parse_user_info(user)
    context.update(user_info)
    
    return render_to_response('reader/feeds.xhtml', context,
                              context_instance=RequestContext(request))

def refresh_feeds(feeds, force=False):
    for f in feeds:
        logging.debug('Feed Updating: %s' % f)
        f.update(force)
        usersubs = UserSubscription.objects.filter(
            feed=f.id
        )
        for us in usersubs:
            us.count_unread()
    return

def load_feeds(request):
    user = get_user(request)

    feeds = cache.get('usersub:%s' % user)
    if feeds is None:
        us =    UserSubscriptionFolders.objects.select_related('feed', 'user_sub').filter(
                    user=user
                )
        # logging.info('UserSubs: %s' % us)
        feeds = []
        folders = []
        for sub in us:
            # logging.info("UserSub: %s" % sub)
            try:
                sub.feed.unread_count = sub.user_sub.unread_count
            except:
                logging.warn("Subscription %s does not exist outside of Folder." % (sub.feed))
                sub.delete()
            else:
                if sub.folder not in folders:
                    folders.append(sub.folder)
                    feeds.append({'folder': sub.folder, 'feeds': []})
                for folder in feeds:
                    if folder['folder'] == sub.folder:
                        folder['feeds'].append(sub.feed)

        # Alphabetize folders, then feeds inside folders
        feeds.sort(lambda x, y: cmp(x['folder'].lower(), y['folder'].lower()))
        for feed in feeds:
            feed['feeds'].sort(lambda x, y: cmp(x.feed_title.lower(), y.feed_title.lower()))
            for f in feed['feeds']:
                f.feed_address = mark_safe(f.feed_address)

        cache.set('usersub:%s' % user, feeds, SINGLE_DAY)

    data = json_encode(feeds)
    return HttpResponse(data, mimetype='text/html')

def load_single_feed(request):
    user = get_user(request)
    
    offset = int(request.REQUEST.get('offset', 0))
    limit = int(request.REQUEST.get('limit', 50))
    page = int(request.REQUEST.get('page', 0))
    if page:
        offset = limit * page
    feed_id = request.REQUEST['feed_id']
    feed = Feed.objects.get(id=feed_id)
    force_update = request.GET.get('force_update', False)
    
    stories = feed.get_stories(offset, limit)
        
    if force_update:
        feed.update(force_update)
    
    usersub = UserSubscription.objects.get(user=user, feed=feed.id)
            
    # print "Feed: %s %s" % (feed, usersub)
    logging.debug("Feed: " + feed.feed_title)
    userstory = UserStory.objects.filter(
        user=user, 
        feed=feed.id
    ).values()
    for story in stories:
        for o in userstory:
            if o['story_id'] == story:
                story['opinion'] = o['opinion']
                story['read_status'] = (o['read_date'] is not None)
                break
        if story['story_date'] < usersub.mark_read_date:
            print 'Read by last mark %s %s' % (story['story_date'], usersub.mark_read_date)
            story['read_status'] = 1
        elif story['story_date'] > usersub.last_read_date:
            print 'Read by last_read_date %s %s' % (story['story_date'], usersub.last_read_date)
            story['read_status'] = 0
        # logging.debug("Story: %s" % story)
    
    context = stories
    data = json_encode(context)
    return HttpResponse(data, mimetype='text/html')

    
@login_required
def mark_story_as_read(request):
    story_id = request.REQUEST['story_id']
    story = Story.objects.select_related("story_feed").get(id=story_id)
    
    read_story = UserStory.objects.filter(story=story_id, user=request.user, feed=story.story_feed).count()
    
    logging.debug('Marking as read: %s' % read_story)
    if read_story:
        data = json_encode(dict(code=1))
    else:
        us = UserSubscription.objects.get(
            feed=story.story_feed,
            user=request.user
        )
        us.mark_read()
        logging.debug("Marked Read: " + str(story_id) + ' ' + str(story.id))
        m = UserStory(story=story, user=request.user, feed=story.story_feed)
        data = json_encode(dict(code=0))
        try:
            m.save()
        except:
            data = json_encode(dict(code=2))
    return HttpResponse(data)
    
@login_required
def mark_feed_as_read(request):
    feed_id = int(request.REQUEST['feed_id'])
    feed = Feed.objects.get(id=feed_id)
    
    us = UserSubscription.objects.get(feed=feed, user=request.user)
    us.mark_feed_read()
    
    UserStory.objects.filter(user=request.user, feed=feed_id).delete()
    data = json_encode(dict(code=0))
    try:
        m.save()
    except:
        data = json_encode(dict(code=1))
    return HttpResponse(data)
    
@login_required
def mark_story_as_like(request):
    return mark_story_with_opinion(request, 1)

@login_required
def mark_story_as_dislike(request):
    return mark_story_with_opinion(request, -1)

@login_required
def mark_story_with_opinion(request, opinion):
    story_id = request.REQUEST['story_id']
    story = Story.objects.select_related("story_feed").get(id=story_id)
    
    previous_opinion = StoryOpinions.objects.get(story=story, 
                                                 user=request.user, 
                                                 feed=story.story_feed)
    if previous_opinion and previous_opinion.opinion != opinion:
        previous_opinion.opinion = opinion
        data = json_encode(dict(code=0))
        previous_opinion.save()
        logging.debug("Changed Opinion: " + str(previous_opinion.opinion) + ' ' + str(opinion))
    else:
        logging.debug("Marked Opinion: " + str(story_id) + ' ' + str(opinion))
        m = StoryOpinions(story=story, user=request.user, feed=story.story_feed, opinion=opinion)
        data = json_encode(dict(code=0))
        try:
            m.save()
        except:
            data = json_encode(dict(code=2))
    return HttpResponse(data)
    
@login_required
def get_read_feed_items(request, username):
    feeds = get_list_or_404(Feed)

def _parse_user_info(user):
    return {
        'user_info': {
            'is_anonymous': json_encode(user.is_anonymous()),
            'is_authenticated': json_encode(user.is_authenticated()),
            'username': json_encode(user.username if user.is_authenticated() else 'Anonymous')
        }
    }
