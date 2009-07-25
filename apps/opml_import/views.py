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
            print '.'
            feed_data = dict(feed_address=feed.xmlUrl, feed_link=feed.htmlUrl, feed_title=feed.title)
            feeds.append(feed_data)
            new_feed = Feed(**feed_data)
            try:
                new_feed.save()
            except:
                new_feed = Feed.objects.get(**feed_data)
            us = UserSubscription(feed=new_feed, user=user)
            try:
                us.save()
            except:
                us = UserSubscription.objects.get(feed=new_feed, user=user)
            user_sub_folder = UserSubscriptionFolders(user=user, feed=new_feed, user_sub=us, folder=folder.text)
            try:
                user_sub_folder.save()
            except:
                print 'Can\'t save user_sub_folder'
    data = json_encode(dict(message=message, code=code, payload=dict(feeds=feeds, feed_count=len(feeds))))
    
    return data