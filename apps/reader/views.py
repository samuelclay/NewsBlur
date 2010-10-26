import datetime
import random
import zlib
from django.shortcuts import render_to_response, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.template import RequestContext
from django.db import IntegrityError
from django.views.decorators.cache import never_cache
from django.core.urlresolvers import reverse
from django.contrib.auth import login as login_user
from django.contrib.auth.models import User
from django.http import HttpResponse, HttpResponseRedirect, HttpResponseForbidden, Http404
from django.conf import settings
from django.core.mail import mail_admins
from mongoengine.queryset import OperationError
from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
from apps.analyzer.models import apply_classifier_titles, apply_classifier_feeds, apply_classifier_authors, apply_classifier_tags
from apps.analyzer.models import get_classifiers_for_user
from apps.reader.models import UserSubscription, UserSubscriptionFolders, MUserStory, Feature
from apps.reader.forms import SignupForm, LoginForm, FeatureForm
try:
    from apps.rss_feeds.models import Feed, MFeedPage, DuplicateFeed, MStory, FeedLoadtime
except:
    pass
from utils import json_functions as json, urlnorm
from utils.user_functions import get_user, ajax_login_required
from utils.feed_functions import fetch_address_from_page, relative_timesince
from utils import log as logging

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
    
    features = Feature.objects.all()[:3]
    feature_form = None
    if request.user.is_staff:
        feature_form = FeatureForm()

    feed_count = 0
    train_count = 0
    if request.user.is_authenticated():
        feed_count = UserSubscription.objects.filter(user=request.user, active=True).count()
        train_count = UserSubscription.objects.filter(user=request.user, active=True, is_trained=False, feed__stories_last_month__gte=1).count()

    howitworks_page = random.randint(0, 5)
    return render_to_response('reader/feeds.xhtml', {
        'login_form': login_form,
        'signup_form': signup_form,
        'feature_form': feature_form,
        'features': features,
        'start_import_from_google_reader': request.session.get('import_from_google_reader', False),
        'howitworks_page': howitworks_page,
        'feed_count': feed_count,
        'train_count': feed_count - train_count,
        'account_images': range(1, 4),
    }, context_instance=RequestContext(request))

@never_cache
def login(request):
    if request.method == "POST":
        form = LoginForm(request.POST, prefix='login')
        if form.is_valid():
            login_user(request, form.get_user())
            logging.info(" ---> [%s] Login" % form.get_user())
            return HttpResponseRedirect(reverse('index'))

    return index(request)
    
@never_cache
def signup(request):
    if request.method == "POST":
        form = SignupForm(prefix='signup', data=request.POST)
        if form.is_valid():
            new_user = form.save()
            login_user(request, new_user)
            logging.info(" ---> [%s] NEW SIGNUP" % new_user)
            return HttpResponseRedirect(reverse('index'))

    return index(request)
        
@never_cache
def logout(request):
    logging.info(" ---> [%s] Logout" % request.user)
    from django.contrib.auth import logout
    logout(request)
    
    return HttpResponseRedirect(reverse('index'))
    
@json.json_view
def load_feeds(request):
    user            = get_user(request)
    feeds           = {}
    not_yet_fetched = False
    
    try:
        folders = UserSubscriptionFolders.objects.get(user=user)
    except UserSubscriptionFolders.DoesNotExist:
        data = dict(feeds=[], folders=[])
        return data
        
    user_subs = UserSubscription.objects.select_related('feed').filter(user=user)
    
    for sub in user_subs:
        feeds[sub.feed.pk] = {
            'id': sub.feed.pk,
            'feed_title': sub.feed.feed_title,
            'feed_address': sub.feed.feed_address,
            'feed_link': sub.feed.feed_link,
            'ps': sub.unread_count_positive,
            'nt': sub.unread_count_neutral,
            'ng': sub.unread_count_negative, 
            'updated': relative_timesince(sub.feed.last_update),
            'subs': sub.feed.num_subscribers,
            'active': sub.active
        }
        
        if not sub.feed.fetched_once:
            not_yet_fetched = True
            feeds[sub.feed.pk]['not_yet_fetched'] = True
        if sub.feed.has_page_exception or sub.feed.has_feed_exception:
            feeds[sub.feed.pk]['has_exception'] = True
            feeds[sub.feed.pk]['exception_type'] = 'feed' if sub.feed.has_feed_exception else 'page'
            feeds[sub.feed.pk]['feed_address'] = sub.feed.feed_address
            feeds[sub.feed.pk]['exception_code'] = sub.feed.exception_code
        if not sub.feed.active and not sub.feed.has_feed_exception and not sub.feed.has_page_exception:
            sub.feed.count_subscribers()
            sub.feed.schedule_feed_fetch_immediately()
            
    if not_yet_fetched:
        for f in feeds:
            if 'not_yet_fetched' not in feeds[f]:
                feeds[f]['not_yet_fetched'] = False
                
    data = dict(feeds=feeds, folders=json.decode(folders.folders))
    return data

@json.json_view
def load_feeds_iphone(request):
    user = get_user(request)
    feeds = {}
    
    try:
        folders = UserSubscriptionFolders.objects.get(user=user)
    except UserSubscriptionFolders.DoesNotExist:
        data = dict(folders=[])
        return data
        
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
    return data

@json.json_view
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
        if sub.feed.has_feed_exception or sub.feed.has_page_exception:
            feeds[sub.feed.pk]['has_exception'] = True
            feeds[sub.feed.pk]['exception_type'] = 'feed' if sub.feed.has_feed_exception else 'page'
            feeds[sub.feed.pk]['feed_address'] = sub.feed.feed_address
            feeds[sub.feed.pk]['exception_code'] = sub.feed.exception_code
        if request.POST.get('check_fetch_status', False):
            feeds[sub.feed.pk]['not_yet_fetched'] = not sub.feed.fetched_once
            
    return {'feeds': feeds}

@json.json_view
def load_single_feed(request):
    user = get_user(request)
    offset = int(request.REQUEST.get('offset', 0))
    limit = int(request.REQUEST.get('limit', 30))
    page = int(request.REQUEST.get('page', 0))
    if page:
        offset = limit * page
    feed_id = int(request.REQUEST.get('feed_id', 0))
    if feed_id == 0:
        raise Http404
        
    try:
        feed = Feed.objects.get(id=feed_id)
    except Feed.DoesNotExist:
        feed_address = request.REQUEST.get('feed_address')
        dupe_feed = DuplicateFeed.objects.filter(duplicate_address=feed_address)
        if dupe_feed:
            feed = dupe_feed[0].feed
        else:
            raise Http404
        
    force_update = request.GET.get('force_update', False)
    
    now = datetime.datetime.utcnow()
    stories = feed.get_stories(offset, limit) 
        
    if force_update:
        feed.update(force_update)
    
    # Get intelligence classifier for user
    classifier_feeds = MClassifierFeed.objects(user_id=user.pk, feed_id=feed_id)
    classifier_authors = MClassifierAuthor.objects(user_id=user.pk, feed_id=feed_id)
    classifier_titles = MClassifierTitle.objects(user_id=user.pk, feed_id=feed_id)
    classifier_tags = MClassifierTag.objects(user_id=user.pk, feed_id=feed_id)
    
    try:
        usersub = UserSubscription.objects.get(user=user, feed=feed)
    except UserSubscription.DoesNotExist:
        # FIXME: Why is this happening for `conesus` when logged into another account?!
        logging.info(" ***> [%s] UserSub DNE, creating: %s" % (user, feed))
        usersub = UserSubscription.objects.create(user=user, feed=feed)
            
    userstories = []
    userstories_db = MUserStory.objects(user_id=user.pk, 
                                        feed_id=feed.pk,
                                        read_date__gte=usersub.mark_read_date)
    for us in userstories_db:
        if hasattr(us.story, 'story_guid') and isinstance(us.story.story_guid, unicode):
            userstories.append(us.story.story_guid)
        elif hasattr(us.story, 'id') and isinstance(us.story.id, unicode):
            userstories.append(us.story.id) # TODO: Remove me after migration from story.id->guid
            
    for story in stories:
        classifier_feeds.rewind()
        classifier_authors.rewind()
        classifier_tags.rewind()
        classifier_titles.rewind()
        if story['id'] in userstories:
            story['read_status'] = 1
        elif not story.get('read_status') and story['story_date'] < usersub.mark_read_date:
            story['read_status'] = 1
        elif not story.get('read_status') and story['story_date'] > usersub.last_read_date:
            story['read_status'] = 0
        story['intelligence'] = {
            'feed': apply_classifier_feeds(classifier_feeds, feed),
            'author': apply_classifier_authors(classifier_authors, story),
            'tags': apply_classifier_tags(classifier_tags, story),
            'title': apply_classifier_titles(classifier_titles, story),
        }
    
    # Intelligence
    feed_tags = json.decode(feed.popular_tags) if feed.popular_tags else []
    feed_authors = json.decode(feed.popular_authors) if feed.popular_authors else []
    classifiers = get_classifiers_for_user(user, feed_id, classifier_feeds, 
                                           classifier_authors, classifier_titles, classifier_tags)
    
    usersub.feed_opens += 1
    usersub.save()
    
    diff = datetime.datetime.utcnow()-now
    timediff = float("%s.%s" % (diff.seconds, (diff.microseconds / 1000)))
    logging.info(" ---> [%s] Loading feed: %s (%s seconds)" % (request.user, feed, timediff))
    FeedLoadtime.objects.create(feed=feed, loadtime=timediff)
    
    last_update = relative_timesince(feed.last_update)
    data = dict(stories=stories, 
                feed_tags=feed_tags, 
                feed_authors=feed_authors, 
                classifiers=classifiers,
                last_update=last_update)
    return data

def load_feed_page(request):
    feed_id = int(request.GET.get('feed_id', 0))
    if feed_id == 0:
        raise Http404
        
    feed_page, created = MFeedPage.objects.get_or_create(feed_id=feed_id)
    data = None
    
    if not created:
        data = feed_page.page_data and zlib.decompress(feed_page.page_data)
        
    if created:
        data = "Fetching feed..."
        
    if not data:
        data = ("There is something wrong with this feed. You shouldn't be seeing this "
                "(as you are not allowed to open feeds that are throwing exceptions).")
    
    return HttpResponse(data, mimetype='text/html')
    
    
@ajax_login_required
@json.json_view
def mark_all_as_read(request):
    code = 1
    days = int(request.POST['days'])
    
    feeds = UserSubscription.objects.filter(user=request.user)
    for sub in feeds:
        if days == 0:
            sub.mark_feed_read()
        else:
            read_date = datetime.datetime.utcnow() - datetime.timedelta(days=days)
            if sub.mark_read_date < read_date:
                sub.needs_unread_recalc = True
                sub.mark_read_date = read_date
                sub.save()
    
    logging.info(" ---> [%s] Marking all as read: %s days" % (request.user, days,))
    return dict(code=code)
    
@ajax_login_required
@json.json_view
def mark_story_as_read(request):
    story_ids = request.REQUEST.getlist('story_id')
    feed_id = int(request.REQUEST['feed_id'])
    
    usersub = UserSubscription.objects.select_related('feed').get(user=request.user, feed=feed_id)
    if not usersub.needs_unread_recalc:
        usersub.needs_unread_recalc = True
        usersub.save()
        
    data = dict(code=0, payload=story_ids)
    
    if len(story_ids) > 1:
        logging.debug(" ---> [%s] Read %s stories in feed: %s" % (request.user, len(story_ids), usersub.feed))
    else:
        logging.debug(" ---> [%s] Read story in feed: %s" % (request.user, usersub.feed))
        
    for story_id in story_ids:
        story = MStory.objects(story_feed_id=feed_id, story_guid=story_id)[0]
        now = datetime.datetime.utcnow()
        m = MUserStory(story=story, user_id=request.user.pk, feed_id=feed_id, read_date=now)
        try:
            m.save()
        except OperationError:
            logging.info(' ---> [%s] *** Marked story as read: Duplicate Story -> %s' % (request.user, story_id))
    
    return data
    
@ajax_login_required
@json.json_view
def mark_feed_as_read(request):
    feed_ids = request.REQUEST.getlist('feed_id')
    code = 0
    for feed_id in feed_ids:
        feed = Feed.objects.get(id=feed_id)
        code = 0
    
        us = UserSubscription.objects.get(feed=feed, user=request.user)
        try:
            us.mark_feed_read()
        except IntegrityError:
            code = -1
        else:
            code = 1
        
        logging.info(" ---> [%s] Marking feed as read: %s" % (request.user, feed,))
        MUserStory.objects(user_id=request.user.pk, feed_id=feed_id).delete()
    return dict(code=code)

def _parse_user_info(user):
    return {
        'user_info': {
            'is_anonymous': json.encode(user.is_anonymous()),
            'is_authenticated': json.encode(user.is_authenticated()),
            'username': json.encode(user.username if user.is_authenticated() else 'Anonymous')
        }
    }

@ajax_login_required
@json.json_view
def add_url(request):
    code = 0
    url = request.POST['url']
    folder = request.POST['folder']
    feed = None
    
    logging.info(" ---> [%s] Adding URL: %s (in %s)" % (request.user, url, folder))
    
    if url:
        url = urlnorm.normalize(url)
        # See if it exists as a duplicate first
        duplicate_feed = DuplicateFeed.objects.filter(duplicate_address=url)
        if duplicate_feed:
            feed = [duplicate_feed[0].feed]
        else:
            feed = Feed.objects.filter(feed_address=url)
    
    if feed:
        feed = feed[0]
    else:
        try:
            feed = fetch_address_from_page(url)
        except:
            code = -2
            message = "This feed has been added, but something went wrong"\
                      " when downloading it. Maybe the server's busy."
                
    if not feed:    
        code = -1
        message = "That URL does not point to an RSS feed or a website that has an RSS feed."
    else:
        us, _ = UserSubscription.objects.get_or_create(
            feed=feed, 
            user=request.user,
            defaults={
                'needs_unread_recalc': True,
                'active': True,
            }
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
    
    return dict(code=code, message=message)

@ajax_login_required
@json.json_view
def add_folder(request):
    folder = request.POST['folder']
    parent_folder = request.POST['parent_folder']
    
    logging.info(" ---> [%s] Adding Folder: %s (in %s)" % (request.user, folder, parent_folder))
    
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
        
    return dict(code=code, message=message)

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
    
@ajax_login_required
@json.json_view
def delete_feed(request):
    feed_id = int(request.POST['feed_id'])
    in_folder = request.POST.get('in_folder', '')
    
    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders.delete_feed(feed_id, in_folder)
    
    return dict(code=1)
    
@ajax_login_required
@json.json_view
def delete_folder(request):
    folder_to_delete = request.POST['folder_name']
    in_folder = request.POST.get('in_folder', '')
    feed_ids_in_folder = request.REQUEST.getlist('feed_id')
    feed_ids_in_folder = [int(f) for f in feed_ids_in_folder]
    
    # Works piss poor with duplicate folder titles, if they are both in the same folder.
    # Deletes all, but only in the same folder parent. But nobody should be doing that, right?
    user_sub_folders = get_object_or_404(UserSubscriptionFolders, user=request.user)
    user_sub_folders.delete_folder(folder_to_delete, in_folder, feed_ids_in_folder)

    return dict(code=1)
    
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
    
    return dict(code=code)
    
@json.json_view
def load_features(request):
    page = int(request.POST.get('page', 0))
    logging.info(" ---> [%s] Browse features: Page #%s" % (request.user, page+1))
    features = Feature.objects.all()[page*3:(page+1)*3+1].values()
    features = [{
        'description': f['description'], 
        'date': f['date'].strftime("%b %d, %Y")
    } for f in features]
    return features

@json.json_view
def save_feed_order(request):
    folders = request.POST.get('folders')
    if folders:
        # Test that folders can be JSON decoded
        folders_list = json.decode(folders)
        assert folders_list is not None
        logging.info(" ---> [%s] Feed re-ordering: %s folders/feeds" % (request.user, 
                                                                        len(folders_list)))
        user_sub_folders = UserSubscriptionFolders.objects.get(user=request.user)
        user_sub_folders.folders = folders
        user_sub_folders.save()
    
    return {}

@json.json_view
def get_feeds_trainer(request):
    classifiers = []
    feed_id = request.POST.get('feed_id')
    usersubs = UserSubscription.objects.filter(user=request.user)
    if feed_id:
        feed = get_object_or_404(Feed, pk=feed_id)
        usersubs = usersubs.filter(feed=feed)
    usersubs = usersubs.select_related('feed').order_by('-feed__stories_last_month')
                
    for us in usersubs:
        if (not us.is_trained and us.feed.stories_last_month > 0) or feed_id:
            classifier = dict()
            classifier['classifiers'] = get_classifiers_for_user(request.user, us.feed.pk)
            classifier['feed_id'] = us.feed.pk
            classifier['stories_last_month'] = us.feed.stories_last_month
            classifier['feed_tags'] = json.decode(us.feed.popular_tags) if us.feed.popular_tags else []
            classifier['feed_authors'] = json.decode(us.feed.popular_authors) if us.feed.popular_authors else []
            classifiers.append(classifier)
    
    logging.info(" ---> [%s] Loading Trainer: %s feeds" % (request.user, len(classifiers)))
    
    return classifiers
    
@login_required
def login_as(request):
    if not request.user.is_staff:
        assert False
        return HttpResponseForbidden()
    username = request.GET['user']
    user = get_object_or_404(User, username=username)
    user.backend = settings.AUTHENTICATION_BACKENDS[0]
    login_user(request, user)
    return HttpResponseRedirect(reverse('index'))

@ajax_login_required
@json.json_view
def save_feed_chooser(request):
    approved_feeds = [int(feed_id) for feed_id in request.POST.getlist('approved_feeds')][:64]
    activated = 0
    usersubs = UserSubscription.objects.filter(user=request.user)
    for sub in usersubs:
        if sub.feed.pk in approved_feeds:
            sub.active = True
            activated += 1
            sub.save()
        elif sub.active:
            sub.active = False
            sub.save()
    logging.info(' ---> [%s] Activated standard account: %s/%s' % (request.user, 
                                                                   activated, 
                                                                   usersubs.count()))        
    return {'activated': activated}

@login_required
def activate_premium_account(request):
    try:
        usersubs = UserSubscription.objects.select_related('feed').filter(user=request.user)
        for sub in usersubs:
            sub.active = True
            sub.save()
            if sub.feed.premium_subscribers <= 0:
                sub.feed.count_subscribers()
                sub.feed.schedule_feed_fetch_immediately()
    except Exception, e:
        subject = "Premium activation failed"
        message = "%s -- %s\n\n%s" % (request.user, usersubs, e)
        mail_admins(subject, message, fail_silently=True)
        
    request.user.profile.is_premium = True
    request.user.profile.save()
        
    return HttpResponseRedirect(reverse('index'))

def iframe_buster(request):
    logging.info(" ---> [%s] iFrame bust!" % (request.user,))
    return HttpResponse(status=204)