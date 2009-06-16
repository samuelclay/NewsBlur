from django.conf.urls.defaults import *

urlpatterns = patterns('apps.reader.views',
    (r'^$', 'index'),
    (r'^load_single_feed', 'load_single_feed'),
    (r'^load_feeds', 'load_feeds'),
    (r'^refresh_all_feeds', 'refresh_all_feeds'),
    (r'^refresh_feed', 'refresh_feed'),
    (r'^mark_story_as_read', 'mark_story_as_read'),
    (r'^mark_feed_as_read', 'mark_feed_as_read'),
    (r'^get_read_feed_items', 'get_read_feed_items'),
)
