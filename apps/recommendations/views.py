import datetime
from utils import log as logging
from django.http import HttpResponse
from django.template import RequestContext
from django.shortcuts import render_to_response, get_object_or_404
from apps.recommendations.models import RecommendedFeed
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed
from utils import json_functions as json
from utils.user_functions import get_user, ajax_login_required


def load_recommended_feed(request):
    user = get_user(request)
    page = int(request.REQUEST.get('page', 0))
    usersub = None
    refresh = request.REQUEST.get('refresh')
    now = datetime.datetime.now
    
    recommended_feeds = RecommendedFeed.objects.filter(is_public=True, approved_date__lte=now)[page:page+2]
    if recommended_feeds and request.user.is_authenticated():
        usersub = UserSubscription.objects.filter(user=user, feed=recommended_feeds[0].feed)
    if refresh != 'true':
        logging.user(request.user, "~FBBrowse recommended feed: ~SBPage #%s" % (page+1))
    
    recommended_feed = recommended_feeds and recommended_feeds[0]
    
    if recommended_feed:
        return render_to_response('recommendations/render_recommended_feed.xhtml', {
            'recommended_feed'  : recommended_feed,
            'description'       : recommended_feed.description or recommended_feed.feed.data.feed_tagline,
            'usersub'           : usersub,
            'has_next_page'     : len(recommended_feeds) > 1,
            'has_previous_page' : page != 0,
        }, context_instance=RequestContext(request))
    else:
        return HttpResponse("")
        
@json.json_view
def load_feed_info(request):
    feed_id = request.GET['feed_id']
    feed = get_object_or_404(Feed, pk=feed_id)
    previous_recommendation = None
    recommended_feed = RecommendedFeed.objects.filter(user=request.user, feed=feed)
    if recommended_feed:
        previous_recommendation = recommended_feed[0].created_date
    
    return {
        'subscriber_count': feed.num_subscribers,
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