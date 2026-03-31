"""Static views: render static content pages and application manifests."""

import os

import redis
import yaml
from django.conf import settings
from django.http import HttpResponse
from django.shortcuts import render

from apps.rss_feeds.models import Feed, MStory
from apps.search.models import SearchFeed
from utils import log as logging


def about(request):
    return render(request, "static/about.xhtml")


def pricing(request):
    return render(request, "static/pricing.xhtml")


def features(request):
    return render(request, "static/features.xhtml")


def compare_feedly(request):
    return render(request, "static/compare_feedly.xhtml")


def compare_inoreader(request):
    return render(request, "static/compare_inoreader.xhtml")


def compare_readwise(request):
    return render(request, "static/compare_readwise.xhtml")


def compare_the_old_reader(request):
    return render(request, "static/compare_the_old_reader.xhtml")


def alt_open_source(request):
    return render(request, "static/alt_open_source.xhtml")


def alt_self_hosted(request):
    return render(request, "static/alt_self_hosted.xhtml")


def alt_google_reader(request):
    return render(request, "static/alt_google_reader.xhtml")


def alt_feedly(request):
    return render(request, "static/alt_feedly.xhtml")


def alt_inoreader(request):
    return render(request, "static/alt_inoreader.xhtml")


def compare_feedbin(request):
    return render(request, "static/compare_feedbin.xhtml")


def feature_intelligence_training(request):
    return render(request, "static/feature_intelligence_training.xhtml")


def feature_ask_ai(request):
    return render(request, "static/feature_ask_ai.xhtml")


def feature_web_feeds(request):
    return render(request, "static/feature_web_feeds.xhtml")


def feature_newsletters(request):
    return render(request, "static/feature_newsletters.xhtml")


def feature_search(request):
    return render(request, "static/feature_search.xhtml")


def feature_archive(request):
    return render(request, "static/feature_archive.xhtml")


def feature_saved_stories(request):
    return render(request, "static/feature_saved_stories.xhtml")


def feature_native_apps(request):
    return render(request, "static/feature_native_apps.xhtml")


def feature_mcp(request):
    return render(request, "static/feature_mcp.xhtml")


def feature_cli(request):
    return render(request, "static/feature_cli.xhtml")


def feature_mcp_cli_redirect(request):
    from django.shortcuts import redirect

    return redirect("feature-mcp", permanent=True)


def feature_story_clustering(request):
    return render(request, "static/feature_story_clustering.xhtml")


def pricing_premium(request):
    return render(request, "static/pricing_premium.xhtml", {"current_plan": "premium"})


def pricing_archive(request):
    return render(request, "static/pricing_archive.xhtml", {"current_plan": "archive"})


def pricing_pro(request):
    return render(request, "static/pricing_pro.xhtml", {"current_plan": "pro"})


def faq(request):
    return render(request, "static/faq.xhtml")


def api(request):
    filename = settings.TEMPLATES[0]["DIRS"][0] + "/static/api.yml"
    api_yml_file = open(filename).read()
    data = yaml.load(api_yml_file)

    return render(request, "static/api.xhtml", {"data": data})


def press(request):
    return render(request, "static/press.xhtml")


def privacy(request):
    return render(request, "static/privacy.xhtml")


def tos(request):
    return render(request, "static/tos.xhtml")


def webmanifest(request):
    filename = settings.MEDIA_ROOT + "/extensions/edge/manifest.json"
    manifest = open(filename).read()

    return HttpResponse(manifest, content_type="application/manifest+json")


def apple_app_site_assoc(request):
    return render(request, "static/apple_app_site_assoc.xhtml", content_type="application/json")


def apple_developer_merchantid(request):
    return render(request, "static/apple_developer_merchantid.xhtml")


def assetlinks(request):
    return render(request, "static/assetlinks.json", content_type="application/json")


def feedback(request):
    return render(request, "static/feedback.xhtml")


def firefox(request):
    filename = settings.MEDIA_ROOT + "/extensions/firefox/manifest.json"
    manifest = open(filename).read()

    return HttpResponse(manifest, content_type="application/x-web-app-manifest+json")


def ios(request):
    return render(request, "static/ios.xhtml")


def android(request):
    return render(request, "static/android.xhtml")


def ios_download(request):
    return render(request, "static/ios_download.xhtml")


def ios_plist(request):
    filename = os.path.join(settings.NEWSBLUR_DIR, "clients/ios/NewsBlur.plist")
    manifest = open(filename).read()

    logging.user(request, "~SK~FR~BBDownloading NewsBlur.plist...")
    return HttpResponse(manifest, content_type="text/xml")


def ios_ipa(request):
    filename = os.path.join(settings.NEWSBLUR_DIR, "clients/ios/NewsBlur.ipa")
    manifest = open(filename).read()

    logging.user(request, "~SK~FR~BBDownloading NewsBlur.ipa...")
    return HttpResponse(manifest, content_type="application/octet-stream")


def haproxy_check(request):
    return HttpResponse("OK")


def postgres_check(request):
    feed = Feed.objects.latest("pk").pk
    if feed:
        return HttpResponse(str(feed))
    assert False, "Cannot read from postgres database"


def mongo_check(request):
    stories = MStory.objects.count()
    if stories:
        return HttpResponse(str(stories))
    assert False, "Cannot read from mongo database"


def elasticsearch_check(request):
    client = SearchFeed.ES()
    if client.indices.exists_index(SearchFeed.index_name()):
        return HttpResponse(SearchFeed.index_name())
    assert False, "Cannot read from elasticsearch database"


def redis_check(request):
    pool = request.GET["pool"]
    if pool == "main":
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
    elif pool == "story":
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
    elif pool == "sessions":
        r = redis.Redis(connection_pool=settings.REDIS_SESSION_POOL)

    key = r.randomkey()
    if key:
        return HttpResponse(str(key))
    assert False, "Cannot read from redis-%s database" % pool


def health_check(request):
    return HttpResponse("OK")
