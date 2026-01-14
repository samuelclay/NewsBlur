from django.urls import re_path
from oauth2_provider import views as op_views

from apps.oauth import views

urlpatterns = [
    re_path(r"^twitter_connect/?$", views.twitter_connect, name="twitter-connect"),
    re_path(r"^facebook_connect/?$", views.facebook_connect, name="facebook-connect"),
    re_path(r"^twitter_disconnect/?$", views.twitter_disconnect, name="twitter-disconnect"),
    re_path(r"^facebook_disconnect/?$", views.facebook_disconnect, name="facebook-disconnect"),
    re_path(r"^follow_twitter_account/?$", views.follow_twitter_account, name="social-follow-twitter"),
    re_path(r"^unfollow_twitter_account/?$", views.unfollow_twitter_account, name="social-unfollow-twitter"),
    # Django OAuth Toolkit
    re_path(r"^status/?$", views.ifttt_status, name="ifttt-status"),
    re_path(r"^authorize/?$", op_views.AuthorizationView.as_view(), name="oauth-authorize"),
    re_path(r"^token/?$", op_views.TokenView.as_view(), name="oauth-token"),
    re_path(r"^oauth2/authorize/?$", op_views.AuthorizationView.as_view(), name="ifttt-authorize"),
    re_path(r"^oauth2/token/?$", op_views.TokenView.as_view(), name="ifttt-token"),
    re_path(r"^user/info/?$", views.api_user_info, name="ifttt-user-info"),
    re_path(
        r"^triggers/(?P<trigger_slug>new-unread-(focus-)?story)/fields/feed_or_folder/options/?$",
        views.api_feed_list,
        name="ifttt-trigger-feedlist",
    ),
    re_path(
        r"^triggers/(?P<trigger_slug>new-unread-(focus-)?story)/?$",
        views.api_unread_story,
        name="ifttt-trigger-unreadstory",
    ),
    re_path(
        r"^triggers/new-saved-story/fields/story_tag/options/?$",
        views.api_saved_tag_list,
        name="ifttt-trigger-taglist",
    ),
    re_path(r"^triggers/new-saved-story/?$", views.api_saved_story, name="ifttt-trigger-saved"),
    re_path(
        r"^triggers/new-shared-story/fields/blurblog_user/options/?$",
        views.api_shared_usernames,
        name="ifttt-trigger-blurbloglist",
    ),
    re_path(r"^triggers/new-shared-story/?$", views.api_shared_story, name="ifttt-trigger-shared"),
    re_path(r"^actions/share-story/?$", views.api_share_new_story, name="ifttt-action-share"),
    re_path(r"^actions/save-story/?$", views.api_save_new_story, name="ifttt-action-saved"),
    re_path(r"^actions/add-site/?$", views.api_save_new_subscription, name="ifttt-action-subscription"),
    re_path(r"^actions/add-site/fields/folder/options/?$", views.api_folder_list, name="ifttt-action-folderlist"),
]
