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
from apps.rss_feeds.models import Feed, Story, Tag, StoryAuthor
from apps.reader.models import UserSubscription, UserStory
from apps.analyzer.models import ClassifierTitle, ClassifierAuthor, ClassifierFeed, ClassifierTag, get_classifiers_for_user
from utils import json
from utils.user_functions import get_user
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
    feed = Feed.objects.get(pk=post['feed_id'])
    code = 0
    message = 'OK'
    payload = {}

    def _save_classifier(opinions, ContentCls, ClassifierCls, content_type, post_content_field):
        for opinion, score in opinions.items():
            if opinion in post:
                post_contents = post.getlist(opinion)
                for post_content in post_contents:
                    classifier_dict = {
                        'user': request.user,
                        'feed': feed,
                        'defaults': {
                            'score': score
                        }
                    }
                    if ContentCls:
                        # Can't use post_content. lookup content and refer to that. Authors, Tags.
                        content_dict = {
                            post_content_field: post_content,
                            'feed': feed
                        }
                        content = ContentCls.objects.get(**content_dict)
                        classifier_dict.update({content_type: content})
                    elif content_type:
                        # Skip content lookup and just use content directly. Titles.
                        classifier_dict.update({content_type: post_content})
                    classifier, _ = ClassifierCls.objects.get_or_create(**classifier_dict)
                    if classifier.score != score:
                        classifier.score = score
                        classifier.save()
                        
    _save_classifier({'like_author': 1, 'dislike_author': -1}, StoryAuthor, ClassifierAuthor, 'author', 'author_name')
    _save_classifier({'like_tag': 1, 'dislike_tag': -1}, Tag, ClassifierTag, 'tag', 'name')
    _save_classifier({'like_title': 1, 'dislike_title': -1}, None, ClassifierTitle, 'title', None)
    _save_classifier({'like_publisher': 1, 'dislike_publisher': -1}, None, ClassifierFeed, None, None)
    
    response = dict(code=code, message=message, payload=payload)
    return response
    
@json.json_view
def get_classifiers_feed(request):
    feed = request.POST['feed_id']
    user = get_user(request)
    code = 0
    
    payload = get_classifiers_for_user(user, feed)
    
    response = dict(code=code, payload=payload)
    
    return response