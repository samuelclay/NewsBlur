from django.conf.urls import url, patterns
from apps.oauth import views
from oauth2_provider import views as op_views

urlpatterns = patterns('',
    url(r'^twitter_connect/?$', views.twitter_connect, name='twitter-connect'),
    url(r'^facebook_connect/?$', views.facebook_connect, name='facebook-connect'),
    url(r'^appdotnet_connect/?$', views.appdotnet_connect, name='appdotnet-connect'),
    url(r'^twitter_disconnect/?$', views.twitter_disconnect, name='twitter-disconnect'),
    url(r'^facebook_disconnect/?$', views.facebook_disconnect, name='facebook-disconnect'),
    url(r'^appdotnet_disconnect/?$', views.appdotnet_disconnect, name='appdotnet-disconnect'),
    url(r'^follow_twitter_account/?$', views.follow_twitter_account, name='social-follow-twitter'),
    url(r'^unfollow_twitter_account/?$', views.unfollow_twitter_account, name='social-unfollow-twitter'),

    # Django OAuth Toolkit
    url(r'^status/?$', views.ifttt_status, name="ifttt-status"),
    url(r'^oauth2/authorize/?$', op_views.AuthorizationView.as_view(), name="ifttt-authorize"),
    url(r'^oauth2/token/?$', op_views.TokenView.as_view(), name="ifttt-token"),
    url(r'^user/info/?$', views.api_user_info, name="ifttt-user-info"),
    url(r'^triggers/(?P<trigger_slug>(new-unread-story|new-focus-story))/fields/feed_or_folder/options/?$', 
        views.api_feed_list, name="ifttt-trigger-feedlist"),
    url(r'^triggers/(?P<unread_score>(new-unread-story|new-focus-story))/?$', 
        views.api_unread_story, name="ifttt-trigger-unreadstory"),
    url(r'^triggers/new-saved-story/fields/story_tag/options/?$', 
        views.api_saved_tag_list, name="ifttt-trigger-taglist"),
    url(r'^triggers/new-saved-story/?$', views.api_saved_story, name="ifttt-trigger-saved"),
    url(r'^triggers/new-shared-story/fields/blurblog_user/options/?$', 
        views.api_shared_usernames, name="ifttt-trigger-blurbloglist"),
    url(r'^triggers/new-shared-story/?$', views.api_shared_story, name="ifttt-trigger-shared"),
    url(r'^actions/post-new-shared-story/?$', views.api_share_new_story, name="ifttt-action-share"),
    url(r'^actions/save-new-saved-story/?$', views.api_save_new_story, name="ifttt-action-saved"),
    url(r'^actions/add-new-subscription/?$', views.api_save_new_subscription, name="ifttt-action-subscription"),
    url(r'^actions/add-new-subscription/fields/folder/options/?$', 
        views.api_folder_list, name="ifttt-action-folderlist"),
)
