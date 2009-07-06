from django.shortcuts import render_to_response, get_list_or_404, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.template import RequestContext
from apps.rss_feeds.models import Feed, Story
from apps.reader.models import UserSubscription, ReadStories, UserSubscriptionFolders, StoryOpinions
from utils.json import json_encode
from utils.story_functions import format_story_link_date__short, format_story_link_date__long
from utils.user_functions import get_user
from django.contrib.auth.models import User
from django.http import HttpResponse, HttpRequest
from django.core import serializers 
from pprint import pprint
from django.utils.safestring import mark_safe
from utils.feedcache.threading_model import fetch_feeds
import datetime
import threading

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
    force_update = False # request.GET.get('force', False)
    feeds = Feed.objects.all()

    # t = threading.Thread(target=refresh_feeds,
                         args=[feeds])
    # t.setDaemon(True)
    # t.start()
    refresh_feeds(feeds)
    # feeds = fetch_feeds(force_update, feeds)
    
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

    feeds = fetch_feeds(force_update, feeds)
    
    context = {}
    
    user = request.user 
    user_info = _parse_user_info(user)
    context.update(user_info)
    
    return render_to_response('reader/feeds.xhtml', context,
                              context_instance=RequestContext(request))

def refresh_feeds(feeds):
    for f in feeds:
        f.update()
    return

def load_feeds(request):
    user = get_user(request)
        
    us =    UserSubscriptionFolders.objects.select_related().filter(
                user=user
            )
            
    feeds = []
    folders = []
    for sub in us:
        sub.feed.unread_count = sub.user_sub.count_unread()
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
    
    context = feeds
    
    data = json_encode(context)
    return HttpResponse(data, mimetype='application/json')

def load_single_feed(request):
    user = get_user(request)
    
    offset = int(request.REQUEST.get('offset', 0))
    limit = int(request.REQUEST.get('limit', 25))
    page = int(request.REQUEST.get('page', 0))
    if page:
        offset = limit * page
    feed_id = request.REQUEST['feed_id']
    stories=Story.objects.filter(story_feed=feed_id)[offset:offset+limit]
    feed = Feed.objects.get(id=feed_id)
    force_update = request.GET.get('force', False)
    
        
    if force_update:
        fetch_feeds(force_update, [feed])
    
    us = UserSubscription.objects.select_related("feed").filter(user=user)
    for sub in us:
        if sub.feed_id == feed.id:

            print "Feed: " + feed.feed_title
            user_readstories = ReadStories.objects.filter(
                user=user, 
                feed=feed
            )
            story_opinions = StoryOpinions.objects.filter(
                user=user,
                feed=feed
            )
            for story in stories:
                story.short_parsed_date = format_story_link_date__short(story.story_date)
                story.long_parsed_date = format_story_link_date__long(story.story_date)
                story.story_feed_title = feed.feed_title
                story.story_feed_link = mark_safe(feed.feed_link)
                story.story_permalink = mark_safe(story.story_permalink)
                if story in [o.story for o in story_opinions]:
                    for o in story_opinions:
                        if o.story == story:
                            story.opinion = o.opinion
                            break
                if story.story_date < sub.mark_read_date:
                    story.read_status = 1
                elif story.story_date > sub.last_read_date:
                    story.read_status = 0
                else:
                    if story.id in [u_rs.story_id for u_rs in user_readstories]:
                        print "READ: "
                        story.read_status = 1
                    else: 
                        story.read_status = 0
    
    context = stories
    data = json_encode(context)
    return HttpResponse(data, mimetype='text/plain')

    
@login_required
def mark_story_as_read(request):
    story_id = request.REQUEST['story_id']
    story = Story.objects.select_related("story_feed").get(id=story_id)
    
    read_story = ReadStories.objects.filter(story=story_id, user=request.user, feed=story.story_feed).count()
    
    print read_story
    if read_story:
        data = json_encode(dict(code=1))
    else:
        us = UserSubscription.objects.get(
            feed=story.story_feed,
            user=request.user
        )
        us.mark_read()
        print "Marked Read: " + str(story_id) + ' ' + str(story.id)    
        m = ReadStories(story=story, user=request.user, feed=story.story_feed)
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
    
    ReadStories.objects.filter(user=request.user, feed=feed_id).delete()
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
    
    previous_opinion = StoryOpinions.objects.get(story=story, user=request.user, feed=story.story_feed)
    if previous_opinion and previous_opinion.opinion != opinion:
        previous_opinion.opinion = opinion
        data = json_encode(dict(code=0))
        previous_opinion.save()
        print "Changed Opinion: " + str(previous_opinion.opinion) + ' ' + str(opinion)    
    else:
        print "Marked Opinion: " + str(story_id) + ' ' + str(opinion)    
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
