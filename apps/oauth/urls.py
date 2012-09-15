from django.conf.urls.defaults import url, patterns
from apps.oauth import views

urlpatterns = patterns('',
    url(r'^twitter_connect/?$', views.twitter_connect, name='twitter-connect'),
    url(r'^facebook_connect/?$', views.facebook_connect, name='facebook-connect'),
    url(r'^twitter_disconnect/?$', views.twitter_disconnect, name='twitter-disconnect'),
    url(r'^facebook_disconnect/?$', views.facebook_disconnect, name='facebook-disconnect'),
    url(r'^follow_twitter_account/?$', views.follow_twitter_account, name='social-follow-twitter'),
    url(r'^unfollow_twitter_account/?$', views.unfollow_twitter_account, name='social-unfollow-twitter'),
)
