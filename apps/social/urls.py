from django.urls import re_path

from apps.social import views

urlpatterns = [
    re_path(r"^river_stories/?$", views.load_river_blurblog, name="social-river-blurblog"),
    re_path(r"^share_story/?$", views.mark_story_as_shared, name="mark-story-as-shared"),
    re_path(r"^unshare_story/?$", views.mark_story_as_unshared, name="mark-story-as-unshared"),
    re_path(r"^load_user_friends/?$", views.load_user_friends, name="load-user-friends"),
    re_path(r"^load_follow_requests/?$", views.load_follow_requests, name="load-follow-requests"),
    re_path(r"^profile/?$", views.profile, name="profile"),
    re_path(r"^load_user_profile/?$", views.load_user_profile, name="load-user-profile"),
    re_path(r"^save_user_profile/?$", views.save_user_profile, name="save-user-profile"),
    re_path(r"^upload_avatar/?", views.upload_avatar, name="upload-avatar"),
    re_path(r"^save_blurblog_settings/?$", views.save_blurblog_settings, name="save-blurblog-settings"),
    re_path(r"^interactions/?$", views.load_interactions, name="social-interactions"),
    re_path(r"^activities/?$", views.load_activities, name="social-activities"),
    re_path(r"^follow/?$", views.follow, name="social-follow"),
    re_path(r"^unfollow/?$", views.unfollow, name="social-unfollow"),
    re_path(r"^approve_follower/?$", views.approve_follower, name="social-approve-follower"),
    re_path(r"^ignore_follower/?$", views.ignore_follower, name="social-ignore-follower"),
    re_path(r"^mute_user/?$", views.mute_user, name="social-mute-user"),
    re_path(r"^unmute_user/?$", views.unmute_user, name="social-unmute-user"),
    re_path(r"^feed_trainer", views.social_feed_trainer, name="social-feed-trainer"),
    re_path(r"^public_comments/?$", views.story_public_comments, name="story-public-comments"),
    re_path(r"^save_comment_reply/?$", views.save_comment_reply, name="social-save-comment-reply"),
    re_path(r"^remove_comment_reply/?$", views.remove_comment_reply, name="social-remove-comment-reply"),
    re_path(r"^find_friends/?$", views.find_friends, name="social-find-friends"),
    re_path(r"^like_comment/?$", views.like_comment, name="social-like-comment"),
    re_path(r"^remove_like_comment/?$", views.remove_like_comment, name="social-remove-like-comment"),
    # re_path(r'^like_reply/?$', views.like_reply, name='social-like-reply'),
    # re_path(r'^remove_like_reply/?$', views.remove_like_reply, name='social-remove-like-reply'),
    re_path(
        r"^comment/(?P<comment_id>\w+)/reply/(?P<reply_id>\w+)/?$",
        views.comment_reply,
        name="social-comment-reply",
    ),
    re_path(r"^comment/(?P<comment_id>\w+)/?$", views.comment, name="social-comment"),
    re_path(r"^rss/(?P<user_id>\d+)/?$", views.shared_stories_rss_feed, name="shared-stories-rss-feed"),
    re_path(
        r"^rss/(?P<user_id>\d+)/(?P<username>[-\w]+)?$",
        views.shared_stories_rss_feed,
        name="shared-stories-rss-feed",
    ),
    re_path(
        r"^stories/(?P<user_id>\w+)/(?P<username>[-\w]+)?/?$",
        views.load_social_stories,
        name="load-social-stories",
    ),
    re_path(r"^page/(?P<user_id>\w+)/(?P<username>[-\w]+)?/?$", views.load_social_page, name="load-social-page"),
    re_path(
        r"^settings/(?P<social_user_id>\w+)/(?P<username>[-\w]+)?/?$",
        views.load_social_settings,
        name="load-social-settings",
    ),
    re_path(
        r"^statistics/(?P<social_user_id>\w+)/(?P<username>[-\w]+)/?$",
        views.load_social_statistics,
        name="load-social-statistics",
    ),
    re_path(
        r"^statistics/(?P<social_user_id>\w+)/?$", views.load_social_statistics, name="load-social-statistics"
    ),
    re_path(
        r"^mute_story/(?P<secret_token>\w+)/(?P<shared_story_id>\w+)?$",
        views.mute_story,
        name="social-mute-story",
    ),
    re_path(r"^(?P<username>[-\w]+)/?$", views.shared_stories_public, name="shared-stories-public"),
]
