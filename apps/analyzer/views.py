from django.shortcuts import render_to_response, get_list_or_404, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.template import RequestContext
from django.db import IntegrityError
from django.core.cache import cache
from django.contrib.auth.models import User
from django.http import HttpResponse, HttpRequest
from django.core import serializers 
from django.utils.safestring import mark_safe
from django.views.decorators.cache import cache_page
from django.views.decorators.http import require_POST
from apps.rss_feeds.models import Feed, Story, Tag
from apps.reader.models import UserSubscription, UserSubscriptionFolders, UserStory
from apps.analyzer.models import ClassifierTitle, ClassifierAuthor, ClassifierFeed, ClassifierTag
from utils import json
from utils.user_functions import get_user
from djangologging.decorators import suppress_logging_output
import logging
import datetime
import random

def index(requst):
    pass
    
@require_POST
@json.json_view
def save_classifier_story(request):
    post = request.POST
    facets = post.getlist('facet')
    code = 0
    message = 'OK'
    payload = {}
    feed = Feed.objects.get(pk=post['feed_id'])
    story = Story.objects.get(pk=post['story_id'])
    score = int(post['score'])

    if 'title' in post and 'title' in facets:
        ClassifierTitle.objects.create(user=request.user,
                                       score=score,
                                       title=post['title'],
                                       feed=feed,
                                       original_story=story)
    
    if 'author' in facets:
        author = story.story_author
        ClassifierAuthor.objects.create(user=request.user,
                                        score=score,
                                        author=author,
                                        feed=feed,
                                        original_story=story)
                         
    if 'publisher' in facets:
        ClassifierFeed.objects.create(user=request.user,
                                      score=score,
                                      feed=feed,
                                      original_story=story)
    
    if 'tag' in post:
        tags = post.getlist('tag')
        for tag_name in tags:
            tag = Tag.objects.get(name=tag_name, feed=feed)
            ClassifierTag.objects.create(user=request.user,
                                         score=score,
                                         tag=tag,
                                         feed=feed,
                                         original_story=story)
    
    response = dict(code=code, message=message, payload=payload)
    return response
    
@require_POST
@json.json_view
def save_classifier_publisher(request):
    post = request.POST
    facets = post.getlist('facet')
    code = 0
    message = 'OK'
    payload = {}
    feed = Feed.objects.get(pk=post['feed_id'])
    score = int(post['score'])

    if 'author' in post:
        authors = post.getlist('authors')
        for author_name in authors:
            author = StoryAuthor.objects.get(author_name=author_name, feed=feed)
            ClassifierAuthor.objects.create(user=request.user,
                                            score=score,
                                            author=author,
                                            feed=feed)
                         
    if 'publisher' in facets:
        ClassifierFeed.objects.create(user=request.user,
                                      score=score,
                                      feed=feed)
    
    if 'tag' in post:
        tags = post.getlist('tag')
        for tag_name in tags:
            tag = Tag.objects.get(name=tag_name, feed=feed)
            ClassifierTag.objects.create(user=request.user,
                                         score=score,
                                         tag=tag,
                                         feed=feed)
    
    response = dict(code=code, message=message, payload=payload)
    return response