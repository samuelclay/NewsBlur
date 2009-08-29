from django.conf.urls.defaults import *

urlpatterns = patterns('apps.reader.views',
    (r'^$', 'index'),
    (r'^load_single_feed', 'load_single_feed'),
    (r'^load_feed_page', 'load_feed_page'),
    (r'^load_feeds', 'load_feeds'),
    (r'^refresh_feed', 'refresh_feed'),
    (r'^mark_story_as_read', 'mark_story_as_read'),
    (r'^mark_story_as_like', 'mark_story_as_like'),
    (r'^mark_story_as_dislike', 'mark_story_as_dislike'),
    (r'^mark_feed_as_read', 'mark_feed_as_read'),
    (r'^get_read_feed_items', 'get_read_feed_items'),
)
