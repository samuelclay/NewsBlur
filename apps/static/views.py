import os
import yaml
import redis
from django.conf import settings
from django.http import HttpResponse
from django.shortcuts import render_to_response
from django.template import RequestContext
from apps.rss_feeds.models import Feed, MStory
from apps.search.models import SearchFeed
from utils import log as logging

def about(request):
    return render_to_response('static/about.xhtml', {}, 
                              context_instance=RequestContext(request))
                              
def faq(request):
    return render_to_response('static/faq.xhtml', {}, 
                              context_instance=RequestContext(request))
                              
def api(request):
    filename     = settings.TEMPLATE_DIRS[0] + '/static/api.yml'
    api_yml_file = open(filename).read()
    data         = yaml.load(api_yml_file)

    return render_to_response('static/api.xhtml', {
        'data': data
    }, context_instance=RequestContext(request))
                              
def press(request):
    return render_to_response('static/press.xhtml', {}, 
                              context_instance=RequestContext(request))

def privacy(request):
    return render_to_response('static/privacy.xhtml', {}, 
                              context_instance=RequestContext(request))

def tos(request):
    return render_to_response('static/tos.xhtml', {}, 
                              context_instance=RequestContext(request))
                        
def apple_app_site_assoc(request):
    return render_to_response('static/apple_app_site_assoc.xhtml', {}, 
                              context_instance=RequestContext(request))
                                                      
def feedback(request):
    return render_to_response('static/feedback.xhtml', {}, 
                              context_instance=RequestContext(request))

def firefox(request):
    filename = settings.MEDIA_ROOT + '/extensions/firefox/manifest.json'
    manifest = open(filename).read()
    
    return HttpResponse(manifest, content_type='application/x-web-app-manifest+json')

def ios(request):
    return render_to_response('static/ios.xhtml', {},
                              context_instance=RequestContext(request))
    
def android(request):
    return render_to_response('static/android.xhtml', {},
                              context_instance=RequestContext(request))
    
def ios_download(request):
    return render_to_response('static/ios_download.xhtml', {},
                              context_instance=RequestContext(request))
                              
def ios_plist(request):
    filename = os.path.join(settings.NEWSBLUR_DIR, 'clients/ios/NewsBlur.plist')
    manifest = open(filename).read()
    
    logging.user(request, "~SK~FR~BBDownloading NewsBlur.plist...")
    return HttpResponse(manifest, content_type='text/xml')
    
def ios_ipa(request):
    filename = os.path.join(settings.NEWSBLUR_DIR, 'clients/ios/NewsBlur.ipa')
    manifest = open(filename).read()
    
    logging.user(request, "~SK~FR~BBDownloading NewsBlur.ipa...")
    return HttpResponse(manifest, content_type='application/octet-stream')

def haproxy_check(request):
    return HttpResponse("OK")

def postgres_check(request):
    feed = Feed.objects.latest('pk').pk
    if feed:
        return HttpResponse(unicode(feed))
    assert False, "Cannot read from postgres database"

def mongo_check(request):
    stories = MStory.objects.count()
    if stories:
        return HttpResponse(unicode(stories))
    assert False, "Cannot read from mongo database"

def elasticsearch_check(request):
    client = SearchFeed.ES()
    if client.indices.exists_index(SearchFeed.index_name()):
        return HttpResponse(SearchFeed.index_name())
    assert False, "Cannot read from elasticsearch database"

def redis_check(request):
    pool = request.GET['pool']
    if pool == 'main':
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
    elif pool == 'story':
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
    elif pool == 'sessions':
        r = redis.Redis(connection_pool=settings.REDIS_SESSION_POOL)
        
    key = r.randomkey()
    if key:
        return HttpResponse(unicode(key))
    assert False, "Cannot read from redis-%s database" % pool
