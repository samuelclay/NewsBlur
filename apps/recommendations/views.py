from utils import log as logging
from django.http import HttpResponse
from django.template import RequestContext
from django.shortcuts import render_to_response
from apps.recommendations.models import RecommendedFeed
from apps.reader.models import UserSubscription
# from utils import json_functions as json
from utils.user_functions import get_user


def load_recommended_feed(request):
    user = get_user(request)
    page = int(request.REQUEST.get('page', 0))
    usersub = None
    
    recommended_feeds = RecommendedFeed.objects.all()[page:page+2]
    if recommended_feeds and request.user.is_authenticated():
        usersub = UserSubscription.objects.filter(user=user, feed=recommended_feeds[0].feed)
    if page != 0:
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