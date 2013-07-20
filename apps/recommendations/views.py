import re
import datetime
from utils import log as logging
from django.http import HttpResponse
from django.template import RequestContext
from django.shortcuts import render_to_response, get_object_or_404
from apps.recommendations.models import RecommendedFeed
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MFeedIcon
from utils import json_functions as json
from utils.user_functions import get_user, ajax_login_required, admin_only


def load_recommended_feed(request):
    user        = get_user(request)
    page        = max(int(request.REQUEST.get('page', 0)), 0)
    usersub     = None
    refresh     = request.REQUEST.get('refresh')
    now         = datetime.datetime.now
    unmoderated = request.REQUEST.get('unmoderated', False) == 'true'
    
    if unmoderated:
        recommended_feeds = RecommendedFeed.objects.filter(is_public=False, declined_date__isnull=True)[page:page+2]
    else:
        recommended_feeds = RecommendedFeed.objects.filter(is_public=True, approved_date__lte=now)[page:page+2]
    if recommended_feeds and request.user.is_authenticated():
        usersub = UserSubscription.objects.filter(user=user, feed=recommended_feeds[0].feed)
    if refresh != 'true' and page > 0:
        logging.user(request, "~FBBrowse recommended feed: ~SBPage #%s" % (page+1))
    
    recommended_feed = recommended_feeds and recommended_feeds[0]
    if not recommended_feeds:
        return HttpResponse("")
        
    feed_icon = MFeedIcon.objects(feed_id=recommended_feed.feed_id)
    
    if recommended_feed:
        return render_to_response('recommendations/render_recommended_feed.xhtml', {
            'recommended_feed'  : recommended_feed,
            'description'       : recommended_feed.description or recommended_feed.feed.data.feed_tagline,
            'usersub'           : usersub,
            'feed_icon'         : feed_icon and feed_icon[0],
            'has_next_page'     : len(recommended_feeds) > 1,
            'has_previous_page' : page != 0,
            'unmoderated'       : unmoderated,
            'today'             : datetime.datetime.now(),
            'page'              : page,
        }, context_instance=RequestContext(request))
    else:
        return HttpResponse("")
        
@json.json_view
def load_feed_info(request, feed_id):
    feed = get_object_or_404(Feed, pk=feed_id)
    previous_recommendation = None
    if request.user.is_authenticated():
        recommended_feed = RecommendedFeed.objects.filter(user=request.user, feed=feed)
        if recommended_feed:
            previous_recommendation = recommended_feed[0].created_date
    
    return {
        'num_subscribers': feed.num_subscribers,
        'tagline': feed.data.feed_tagline,
        'previous_recommendation': previous_recommendation
    }
    
@ajax_login_required
@json.json_view
def save_recommended_feed(request):
    feed_id = request.POST['feed_id']
    feed    = get_object_or_404(Feed, pk=int(feed_id))
    tagline = request.POST['tagline']
    twitter = request.POST.get('twitter')
    code    = 1
    
    recommended_feed, created = RecommendedFeed.objects.get_or_create(
        feed=feed, 
        user=request.user,
        defaults=dict(
            description=tagline,
            twitter=twitter
        )
    )

    return dict(code=code if created else -1)
    
@admin_only
@ajax_login_required
def approve_feed(request):
    feed_id = request.POST['feed_id']
    feed    = get_object_or_404(Feed, pk=int(feed_id))
    date    = request.POST['date']
    recommended_feed = RecommendedFeed.objects.filter(feed=feed)[0]
    
    year, month, day = re.search(r'(\d{4})-(\d{1,2})-(\d{1,2})', date).groups()
    recommended_feed.is_public = True
    recommended_feed.approved_date = datetime.date(int(year), int(month), int(day))
    recommended_feed.save()
    
    return load_recommended_feed(request)

@admin_only
@ajax_login_required
def decline_feed(request):
    feed_id = request.POST['feed_id']
    feed    = get_object_or_404(Feed, pk=int(feed_id))
    recommended_feeds = RecommendedFeed.objects.filter(feed=feed)
    
    for recommended_feed in recommended_feeds:
        recommended_feed.is_public = False
        recommended_feed.declined_date = datetime.datetime.now()
        recommended_feed.save()
        
    return load_recommended_feed(request)