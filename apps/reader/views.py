import logging
import datetime
from django.shortcuts import render_to_response, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.template import RequestContext
from django.db import IntegrityError
from django.core.cache import cache
from django.views.decorators.cache import never_cache
from django.db.models import Q
from django.db.models.aggregates import Count
from django.core.urlresolvers import reverse
from django.contrib.auth import login as login_user
from django.http import HttpResponse, HttpResponseRedirect, HttpResponseForbidden
from apps.analyzer.models import ClassifierFeed, ClassifierAuthor, ClassifierTag, ClassifierTitle
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds, apply_classifier_authors, apply_classifier_tags
from apps.analyzer.models import get_classifiers_for_user
from apps.reader.models import UserSubscription, UserSubscriptionFolders, UserStory, Feature
from apps.reader.forms import SignupForm, LoginForm, FeatureForm
try:
    from apps.rss_feeds.models import Feed, Story, Tag, StoryAuthor, FeedPage
except:
    pass
from utils import json, feedfinder
from utils.user_functions import get_user

SINGLE_DAY = 60*60*24

@never_cache
def index(request):
    if request.method == "POST":
        if request.POST['submit'] == 'login':
            login_form = LoginForm(request.POST, prefix='login')
            signup_form = SignupForm(prefix='signup')
        else:
            login_form = LoginForm(prefix='login')
            signup_form = SignupForm(request.POST, prefix='signup')
    else:
        login_form = LoginForm(prefix='login')
        signup_form = SignupForm(prefix='signup')

    features = Feature.objects.all()
    feature_form = None
    if request.user.is_staff:
        feature_form = FeatureForm()
    
    return render_to_response('reader/feeds.xhtml', {
        'login_form': login_form,
        'signup_form': signup_form,
        'feature_form': feature_form,
        'features': features
    }, context_instance=RequestContext(request))

@never_cache
def login(request):
    if request.method == "POST":
        form = LoginForm(request.POST, prefix='login')
        if form.is_valid():
            login_user(request, form.get_user())
            return HttpResponseRedirect(reverse('index'))

    return index(request)
    
@never_cache
def signup(request):
    if request.method == "POST":
        form = SignupForm(prefix='signup', data=request.POST)
        if form.is_valid():
            new_user = form.save()
            login_user(request, new_user)
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
    feeds = {}
    
    try:
        folders = UserSubscriptionFolders.objects.get(user=user)
    except UserSubscriptionFolders.DoesNotExist:
        data = dict(feeds=[], folders=[])
        return HttpResponse(json.encode(data), mimetype='application/json')
        
    user_subs = UserSubscription.objects.select_related('feed').filter(user=user)

    for sub in user_subs:
        if sub.needs_unread_recalc:
            sub.calculate_feed_scores()
        feeds[sub.feed.pk] = {
            'id': sub.feed.pk,
            'feed_title': sub.feed.feed_title,
            'feed_link': sub.feed.feed_link,
            'ps': sub.unread_count_positive,
            'nt': sub.unread_count_neutral,
            'ng': sub.unread_count_negative,
        }

    data = dict(feeds=feeds, folders=json.decode(folders.folders))
    return HttpResponse(json.encode(data), mimetype='application/json')

def load_feeds_iphone(request):
    user = get_user(request)
    feeds = {}
    
    try:
        folders = UserSubscriptionFolders.objects.get(user=user)
    except UserSubscriptionFolders.DoesNotExist:
        data = dict(folders=[])
        return HttpResponse(json.encode(data), mimetype='application/json')
        
    user_subs = UserSubscription.objects.select_related('feed').filter(user=user)

    for sub in user_subs:
        if sub.needs_unread_recalc:
            sub.calculate_feed_scores()
        feeds[sub.feed.pk] = {
            'id': sub.feed.pk,
            'feed_title': sub.feed.feed_title,
            'feed_link': sub.feed.feed_link,
            'ps': sub.unread_count_positive,
            'nt': sub.unread_count_neutral,
            'ng': sub.unread_count_negative,
        }
    
    folders = json.decode(folders.folders)
    flat_folders = {}
    
    def make_feeds_folder(items, parent_folder="", depth=0):
        for item in items:
            if isinstance(item, int):
                feed = feeds[item]
                if not parent_folder:
                    parent_folder = ' '
                if parent_folder in flat_folders:
                    flat_folders[parent_folder].append(feed)
                else:
                    flat_folders[parent_folder] = [feed]
            elif isinstance(item, dict):
                for folder_name in item:
                    folder = item[folder_name]
                    flat_folder_name = "%s%s%s" % (
                        parent_folder,
                        " - " if parent_folder else "",
                        folder_name
                    )
                    make_feeds_folder(folder, flat_folder_name, depth+1)
        
    make_feeds_folder(folders)
    data = dict(flat_folders=flat_folders)
    return HttpResponse(json.encode(data), mimetype='application/json')

def refresh_feeds(request):
    user = get_user(request)
    feeds = {}
            
    user_subs = UserSubscription.objects.select_related('feed').filter(user=user)

    for sub in user_subs:
        if sub.needs_unread_recalc:
            sub.calculate_feed_scores()
        feeds[sub.feed.pk] = {
            'ps': sub.unread_count_positive,
            'nt': sub.unread_count_neutral,
            'ng': sub.unread_count_negative,
        }

    return HttpResponse(json.encode(feeds), mimetype='application/json')

def load_single_feed(request):
    user = get_user(request)
    offset = int(request.REQUEST.get('offset', 0))
    limit = int(request.REQUEST.get('limit', 30))
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
    if stories:
        last_read_date = stories[-1]['story_date']
    else:
        last_read_date = usersub.mark_read_date
    userstory = UserStory.objects.filter(
        user=user, 
        feed=feed.id,
        read_date__gt=last_read_date
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
    classifiers = get_classifiers_for_user(user, feed_id, classifier_feeds, 
                                           classifier_authors, classifier_titles, classifier_tags)
    
    context = dict(stories=stories, feed_tags=feed_tags, feed_authors=feed_authors, classifiers=classifiers)
    data = json.encode(context)
    return HttpResponse(data, mimetype='application/json')

def load_feed_page(request):
    feed = Feed.objects.get(id=request.REQUEST.get('feed_id'))
    feed_page, created = FeedPage.objects.get_or_create(feed=feed)
    if not created:
        data = feed.feed_page.page_data
    else:
        data = "Give it 5-10 minutes...<br /><br />Your feed will be here in under 5 minutes (on average).<br />Soon there will be a progress bar. Until then, take a deep breath."
    
    return HttpResponse(data, mimetype='text/html')
    
    
@login_required
def mark_all_as_read(request):
    code = 1
    days = int(request.POST['days'])
    
    feeds = UserSubscription.objects.filter(user=request.user)
    for sub in feeds:
        if days == 0:
            sub.mark_feed_read()
        else:
            sub.needs_unread_recalc = True
            sub.mark_read_date = datetime.datetime.now() - datetime.timedelta(days=days)
            sub.save()
    
    data = json.encode(dict(code=code))
    return HttpResponse(data)
    
@login_required
def mark_story_as_read(request):
    story_ids = request.REQUEST['story_id'].split(',')
    feed_id = int(request.REQUEST['feed_id'])
    
    usersub = UserSubscription.objects.get(user=request.user, feed=feed_id)
    if not usersub.needs_unread_recalc:
        usersub.needs_unread_recalc = True
        usersub.save()
    
    data = dict(code=0, payload=story_ids)
    
    for story_id in story_ids:
        logging.debug("Marked Read: %s (%s)" % (story_id, feed_id))
        m = UserStory(story_id=int(story_id), user=request.user, feed_id=feed_id)
        try:
            m.save()
            data.update({'code': 1})
        except IntegrityError:
            data.update({'code': -1})
    
    return HttpResponse(json.encode(data))
    
@login_required
def mark_feed_as_read(request):
    feed_id = int(request.REQUEST['feed_id'])
    feed = Feed.objects.get(id=feed_id)
    code = 0
    
    us = UserSubscription.objects.get(feed=feed, user=request.user)
    try:
        us.mark_feed_read()
    except IntegrityError:
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
    
def _parse_user_info(user):
    return {
        'user_info': {
            'is_anonymous': json.encode(user.is_anonymous()),
            'is_authenticated': json.encode(user.is_authenticated()),
            'username': json.encode(user.username if user.is_authenticated() else 'Anonymous')
        }
    }

@login_required
def add_url(request):
    code = 0
    url = request.POST['url']
    folder = request.POST['folder']
    feed = None
    
    if url:
        feed = Feed.objects.filter(Q(feed_address=url) 
                                   | Q(feed_link__icontains=url))
    
    if feed:
        feed = feed[0]
    else:
        feed_finder_url = feedfinder.feed(url)
        if feed_finder_url:
            try:
                feed = Feed.objects.get(feed_address=feed_finder_url)
            except Feed.DoesNotExist:
                try:
                    feed = Feed(feed_address=feed_finder_url)
                    feed.save()
                    feed.update()
                except:
                    code = -2
                    message = "This feed has been added, but something went wrong"\
                              " when downloading it. Maybe the server's busy."
                
    if not feed:    
        code = -1
        message = "That URL does not point to a website or RSS feed."
    else:
        us, _ = UserSubscription.objects.get_or_create(
            feed=feed, 
            user=request.user,
            defaults={'needs_unread_recalc': True}
        )
        code = 1
        message = ""
        
        user_sub_folders_object, created = UserSubscriptionFolders.objects.get_or_create(user=request.user,
            defaults={'folders': '[]'}
        )
        if created:
            user_sub_folders = []
        else:
            user_sub_folders = json.decode(user_sub_folders_object.folders)
        user_sub_folders = _add_object_to_folder(feed.pk, folder, user_sub_folders)
        user_sub_folders_object.folders = json.encode(user_sub_folders)
        user_sub_folders_object.save()
    
    data = dict(code=code, message=message)
    return HttpResponse(json.encode(data))

def _add_object_to_folder(obj, folder, folders):
    if not folder:
        folders.append(obj)
        return folders
        
    for k, v in enumerate(folders):
        if isinstance(v, dict):
            for f_k, f_v in v.items():
                if f_k == folder:
                    f_v.append(obj)
                folders[k][f_k] = _add_object_to_folder(obj, folder, f_v)
    return folders

@login_required
def add_folder(request):
    folder = request.POST['folder']
    parent_folder = request.POST['parent_folder']
    
    if folder:
        code = 1
        message = ""
        user_sub_folders_object, _ = UserSubscriptionFolders.objects.get_or_create(user=request.user)
        if user_sub_folders_object.folders:
            user_sub_folders = json.decode(user_sub_folders_object.folders)
        else:
            user_sub_folders = []
        obj = {folder: []}
        user_sub_folders = _add_object_to_folder(obj, parent_folder, user_sub_folders)
        user_sub_folders_object.folders = json.encode(user_sub_folders)
        user_sub_folders_object.save()
    else:
        code = -1
        message = "Gotta write in a folder name."
        
    data = dict(code=code, message=message)
    return HttpResponse(json.encode(data))
    
@login_required
def delete_feed(request):
    feed_id = int(request.POST['feed_id'])
    user_sub = get_object_or_404(UserSubscription, user=request.user, feed=feed_id)
    user_sub.delete()
    
    user_stories = UserStory.objects.filter(user=request.user, feed=feed_id)
    user_stories.delete()
    
    def _find_feed_in_folders(old_folders):
        new_folders = []
        
        for k, folder in enumerate(old_folders):
            if isinstance(folder, int):
                if folder == feed_id:
                    print "DEL'ED: %s'th item: %s" % (k, old_folders)
                    # folders.remove(folder)
                else:
                    new_folders.append(folder)
            elif isinstance(folder, dict):
                for f_k, f_v in folder.items():
                    new_folders.append({f_k: _find_feed_in_folders(f_v)})

        return new_folders
        
    user_sub_folders_object = UserSubscriptionFolders.objects.get(user=request.user)
    user_sub_folders = json.decode(user_sub_folders_object.folders)
    user_sub_folders = _find_feed_in_folders(user_sub_folders)
    user_sub_folders_object.folders = json.encode(user_sub_folders)
    user_sub_folders_object.save()
    
    data = json.encode(dict(code=1))
    return HttpResponse(data)
    
@login_required
def add_feature(request):
    if not request.user.is_staff:
        return HttpResponseForbidden()

    code = -1    
    form = FeatureForm(request.POST)
    
    if form.is_valid():
        form.save()
        code = 1
        return HttpResponseRedirect(reverse('index'))
    
    data = json.encode(dict(code=code))
    return HttpResponse(data)
    