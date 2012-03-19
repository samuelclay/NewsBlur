from django.conf.urls.defaults import url, patterns
from apps.social import views

urlpatterns = patterns('',
    url(r'^share_story/?$', views.mark_story_as_shared, name='mark-story-as-shared'),
    url(r'^friends/?$', views.friends, name='friends'),
    url(r'^profile/?$', views.profile, name='profile'),
    url(r'^follow/?$', views.follow, name='social-follow'),
    url(r'^unfollow/?$', views.unfollow, name='social-unfollow'),
    url(r'^feed_trainer', views.social_feed_trainer, name='social-feed-trainer'),
    url(r'^comments/?$', views.story_comments, name='social-story-comments'),
    url(r'^find_friends/?$', views.find_friends, name='social-find-friends'),
    url(r'^rss/(?P<user_id>\d+)/(?P<username>\w+)?$', views.shared_stories_rss_feed, name='shared-stories-rss-feed'),
    url(r'^stories/(?P<user_id>\w+)/(?P<username>\w+)?/?$', views.load_social_stories, name='load-social-stories'),
    url(r'^page/(?P<user_id>\w+)/(?P<username>\w+)?/?$', views.load_social_page, name='load-social-page'),
    url(r'^settings/(?P<social_user_id>\w+)/(?P<username>\w+)?/?$', views.load_social_settings, name='load-social-settings'),
    url(r'^statistics/(?P<social_user_id>\w+)/(?P<username>\w+)?/?$', views.load_social_statistics, name='load-social-statistics'),
    url(r'^(?P<username>\w+)/?$', views.shared_stories_public, name='shared-stories-public'),
)
