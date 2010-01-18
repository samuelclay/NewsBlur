from django.shortcuts import render_to_response, get_list_or_404, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.template import RequestContext
from django.core.cache import cache
from apps.rss_feeds.models import Feed
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from utils.json import json_encode
import utils.opml as opml
from django.contrib.auth.models import User
from django.http import HttpResponse, HttpRequest
from django.core import serializers 
from pprint import pprint
from django.db import IntegrityError
import datetime


def opml_upload(request):
    xml_opml = None
    
    if request.method == 'POST':
        if 'file' in request.FILES:
            file = request.FILES['file']
            xml_opml = file.read()
            
    data = opml_import(xml_opml, request.user).encode('utf-8')
    return HttpResponse(data, mimetype='text/plain')

def opml_import(xml_opml, user):
    context = None
    outline = opml.from_string(xml_opml)
    feeds = []
    message = "OK"
    code = 1
    for folder in outline:
        print folder.text
        for feed in folder:
            print '\t%s' % (feed.title,)
            feed_data = dict(feed_address=feed.xmlUrl, feed_link=feed.htmlUrl, feed_title=feed.title)
            feeds.append(feed_data)
            new_feed, _ = Feed.objects.get_or_create(feed_address=feed.xmlUrl, defaults=feed_data)
            us, _ = UserSubscription.objects.get_or_create(feed=new_feed, user=user)
            user_sub_folder, _ = UserSubscriptionFolders.objects.get_or_create(user=user, feed=new_feed, user_sub=us, defaults=dict(folder=folder.text))
    data = json_encode(dict(message=message, code=code, payload=dict(feeds=feeds, feed_count=len(feeds))))
    cache.delete('usersub:%s' % user)

    return data