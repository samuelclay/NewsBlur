from django.shortcuts import render_to_response, get_list_or_404, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.template import RequestContext
from apps.rss_feeds.models import Feed, Story
from apps.reader.models import UserSubscription, ReadStories, UserSubscriptionFolders
from utils.json import json_encode
import utils.opml as opml
from django.contrib.auth.models import User
from django.http import HttpResponse, HttpRequest
from django.core import serializers 
from pprint import pprint
import datetime


def opml_import(request):
    context = None
    return render_to_response('opml_import/import.xhtml', context,
                              context_instance=RequestContext(request))

def process(request):
    context = None
    outline = opml.from_string(request.POST['opml'])
    feeds = []
    for folder in outline:
        for feed in folder:
            feed_data = dict(feed_address=feed.xmlUrl, feed_link=feed.htmlUrl, feed_title=feed.title)
            feeds.append(feed_data)
            new_feed = Feed(**feed_data)
            try:
                new_feed.save()
            except:
                new_feed = Feed.objects.get(**feed_data)
            us = UserSubscription(feed=new_feed, user=request.user)
            try:
                us.save()
            except:
                us = UserSubscription.objects.get(feed=new_feed, user=request.user)
            user_sub_folder = UserSubscriptionFolders(user=request.user, feed=new_feed, user_sub=us, folder=folder.text)
            try:
                user_sub_folder.save()
            except:
                pass
    data = json_encode(feeds)
    return HttpResponse(data, mimetype='application/json')