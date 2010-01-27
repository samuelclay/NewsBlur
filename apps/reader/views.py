from django.shortcuts import render_to_response, get_list_or_404, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.template import RequestContext
from django.db import IntegrityError
try:
    from apps.rss_feeds.models import Feed, Story, Tag, StoryAuthor
except:
    pass
from django.core.cache import cache
from django.views.decorators.cache import never_cache
from django.db.models.aggregates import Count
from apps.reader.models import UserSubscription, UserSubscriptionFolders, UserStory
from utils import json
from utils.user_functions import get_user
from django.core.urlresolvers import reverse
from django.contrib.auth.models import User
from django.contrib.auth.forms import AuthenticationForm
from django.contrib.auth import authenticate, login
from django.http import HttpResponse, HttpRequest, HttpResponseRedirect
from django.core import serializers 
from django.utils.safestring import mark_safe
from djangologging.decorators import suppress_logging_output
from apps.analyzer.models import ClassifierFeed, ClassifierAuthor, ClassifierTag, ClassifierTitle
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds, apply_classifier_authors, apply_classifier_tags
import logging
import datetime
import threading
import random

SINGLE_DAY = 60*60*24

@never_cache
def index(request):
    print "User: %s" % request.user
    form = AuthenticationForm(request.POST)
    return render_to_response('reader/feeds.xhtml', {'form': form},
                              context_instance=RequestContext(request))

@never_cache
def login(request):
    if request.method == "POST":
        form = AuthenticationForm(data=request.POST)
        if form.is_valid():
            from django.contrib.auth import login
            login(request, form.get_user())
            return HttpResponseRedirect(reverse('index'))

    return index(request)
        
@never_cache
def logout(request):
    print "Logout: %s" % request.user
    from django.contrib.auth import logout
    logout(request)
    
    return HttpResponseRedirect(reverse('index'))
    
def load_feeds(request):
    user = get_user(request)

    feeds = cache.get('usersub:%s' % user.id)
    if feeds is None:
        us =    UserSubscriptionFolders.objects.select_related('feed', 'user_sub').filter(
                    user=user
                )
        # logging.info('UserSubs: %s' % us)
        feeds = []
        folders = []
        for sub in us:
            try:
                sub.feed.unread_count_positive = sub.user_sub.unread_count_positive
                sub.feed.unread_count_neutral = sub.user_sub.unread_count_neutral
                sub.feed.unread_count_negative = sub.user_sub.unread_count_negative
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
                f.page_data = None

        cache.set('usersub:%s' % user, feeds, 600)

    data = json.encode(feeds)
    return HttpResponse(data, mimetype='application/json')

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
    
    # Get intelligence classifier for user
    classifier_feeds = ClassifierFeed.objects.filter(user=user, feed=feed)
    classifier_authors = ClassifierAuthor.objects.filter(user=user, feed=feed)
    classifier_titles = ClassifierTitle.objects.filter(user=user, feed=feed)
    classifier_tags = ClassifierTag.objects.filter(user=user, feed=feed)
    
    usersub = UserSubscription.objects.get(user=user, feed=feed)
            
    # print "Feed: %s %s" % (feed, usersub)
    logging.debug("Feed: " + feed.feed_title)
    userstory = UserStory.objects.filter(
        user=user, 
        feed=feed.id,
        read_date__gt=usersub.mark_read_date
    ).values()
    for story in stories:
        for o in userstory:
            if o['story_id'] == story.get('id'):
                story['opinion'] = o['opinion']
                story['read_status'] = (o['read_date'] is not None)
                break
        if not story.get('read_status') and story['story_date'] < usersub.mark_read_date:
            story['read_status'] = 1
        elif not story.get('read_status') and story['story_date'] > usersub.last_read_date:
            story['read_status'] = 0
        story['intelligence'] = {
            'feed': apply_classifier_feeds(classifier_feeds, feed),
            'author': apply_classifier_authors(classifier_authors, story),
            'tags': apply_classifier_tags(classifier_tags, story),
            'title': apply_classifier_titles(classifier_titles, story),
        }
        # logging.debug("Story: %s" % story)
    
    # Intelligence
    
    all_tags = Tag.objects.filter(feed=feed)\
                          .annotate(stories_count=Count('story'))\
                          .order_by('-stories_count')[:20]
    feed_tags = [(tag.name, tag.stories_count) for tag in all_tags if tag.stories_count > 1]
    
    all_authors = StoryAuthor.objects.filter(feed=feed)\
                          .annotate(stories_count=Count('story'))\
                          .order_by('-stories_count')[:20]
    feed_authors = [(author.author_name, author.stories_count) for author in all_authors\
                                                               if author.stories_count > 1]
    
    context = dict(stories=stories, feed_tags=feed_tags, feed_authors=feed_authors)
    data = json.encode(context)
    return HttpResponse(data, mimetype='application/json')

@suppress_logging_output
def load_feed_page(request):
    feed = Feed.objects.get(id=request.REQUEST.get('feed_id'))
    if feed.page_data:
        data = feed.page_data
    else:
        data = "Give it 10 minutes..."
    
    return HttpResponse(data, mimetype='text/html')
    
@login_required
def mark_story_as_read(request):
    story_id = int(request.REQUEST['story_id'])
    feed_id = int(request.REQUEST['feed_id'])
    
    logging.debug("Marked Read: %s (%s)" % (story_id, feed_id))
    m = UserStory(story_id=story_id, user=request.user, feed_id=feed_id)
    data = json.encode(dict(code=0))
    try:
        m.save()
    except IntegrityError, e:
        data = json.encode(dict(code=2))
    return HttpResponse(data)
    
@login_required
def mark_feed_as_read(request):
    feed_id = int(request.REQUEST['feed_id'])
    feed = Feed.objects.get(id=feed_id)
    code = 0
    
    us = UserSubscription.objects.get(feed=feed, user=request.user)
    try:
        us.mark_feed_read()
    except IntegrityError, e:
        code = -1
    else:
        code = 1
        
    data = json.encode(dict(code=code))

    # UserStory.objects.filter(user=request.user, feed=feed_id).delete()
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
    
    previous_opinion = UserStory.objects.get(story=story, 
                                                 user=request.user, 
                                                 feed=story.story_feed)
    if previous_opinion and previous_opinion.opinion != opinion:
        previous_opinion.opinion = opinion
        data = json.encode(dict(code=0))
        previous_opinion.save()
        logging.debug("Changed Opinion: " + str(previous_opinion.opinion) + ' ' + str(opinion))
    else:
        logging.debug("Marked Opinion: " + str(story_id) + ' ' + str(opinion))
        m = UserStory(story=story, user=request.user, feed=story.story_feed, opinion=opinion)
        data = json.encode(dict(code=0))
        try:
            m.save()
        except:
            data = json.encode(dict(code=2))
    return HttpResponse(data)
    
@login_required
def get_read_feed_items(request, username):
    feeds = get_list_or_404(Feed)
    
def _parse_user_info(user):
    return {
        'user_info': {
            'is_anonymous': json.encode(user.is_anonymous()),
            'is_authenticated': json.encode(user.is_authenticated()),
            'username': json.encode(user.username if user.is_authenticated() else 'Anonymous')
        }
    }
