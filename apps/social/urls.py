from django.conf.urls import url

from apps.social import views

urlpatterns = [
    url(r"^river_stories/?$", views.load_river_blurblog, name="social-river-blurblog"),
    url(r"^share_story/?$", views.mark_story_as_shared, name="mark-story-as-shared"),
    url(r"^unshare_story/?$", views.mark_story_as_unshared, name="mark-story-as-unshared"),
    url(r"^load_user_friends/?$", views.load_user_friends, name="load-user-friends"),
    url(r"^load_follow_requests/?$", views.load_follow_requests, name="load-follow-requests"),
    url(r"^profile/?$", views.profile, name="profile"),
    url(r"^load_user_profile/?$", views.load_user_profile, name="load-user-profile"),
    url(r"^save_user_profile/?$", views.save_user_profile, name="save-user-profile"),
    url(r"^upload_avatar/?", views.upload_avatar, name="upload-avatar"),
    url(r"^save_blurblog_settings/?$", views.save_blurblog_settings, name="save-blurblog-settings"),
    url(r"^interactions/?$", views.load_interactions, name="social-interactions"),
    url(r"^activities/?$", views.load_activities, name="social-activities"),
    url(r"^follow/?$", views.follow, name="social-follow"),
    url(r"^unfollow/?$", views.unfollow, name="social-unfollow"),
    url(r"^approve_follower/?$", views.approve_follower, name="social-approve-follower"),
    url(r"^ignore_follower/?$", views.ignore_follower, name="social-ignore-follower"),
    url(r"^mute_user/?$", views.mute_user, name="social-mute-user"),
    url(r"^unmute_user/?$", views.unmute_user, name="social-unmute-user"),
    url(r"^feed_trainer", views.social_feed_trainer, name="social-feed-trainer"),
    url(r"^public_comments/?$", views.story_public_comments, name="story-public-comments"),
    url(r"^save_comment_reply/?$", views.save_comment_reply, name="social-save-comment-reply"),
    url(r"^remove_comment_reply/?$", views.remove_comment_reply, name="social-remove-comment-reply"),
    url(r"^find_friends/?$", views.find_friends, name="social-find-friends"),
    url(r"^like_comment/?$", views.like_comment, name="social-like-comment"),
    url(r"^remove_like_comment/?$", views.remove_like_comment, name="social-remove-like-comment"),
    # url(r'^like_reply/?$', views.like_reply, name='social-like-reply'),
    # url(r'^remove_like_reply/?$', views.remove_like_reply, name='social-remove-like-reply'),
    url(
        r"^comment/(?P<comment_id>\w+)/reply/(?P<reply_id>\w+)/?$",
        views.comment_reply,
        name="social-comment-reply",
    ),
    url(r"^comment/(?P<comment_id>\w+)/?$", views.comment, name="social-comment"),
    url(r"^rss/(?P<user_id>\d+)/?$", views.shared_stories_rss_feed, name="shared-stories-rss-feed"),
    url(
        r"^rss/(?P<user_id>\d+)/(?P<username>[-\w]+)?$",
        views.shared_stories_rss_feed,
        name="shared-stories-rss-feed",
    ),
    url(
        r"^stories/(?P<user_id>\w+)/(?P<username>[-\w]+)?/?$",
        views.load_social_stories,
        name="load-social-stories",
    ),
    url(r"^page/(?P<user_id>\w+)/(?P<username>[-\w]+)?/?$", views.load_social_page, name="load-social-page"),
    url(
        r"^settings/(?P<social_user_id>\w+)/(?P<username>[-\w]+)?/?$",
        views.load_social_settings,
        name="load-social-settings",
    ),
    url(
        r"^statistics/(?P<social_user_id>\w+)/(?P<username>[-\w]+)/?$",
        views.load_social_statistics,
        name="load-social-statistics",
    ),
    url(
        r"^statistics/(?P<social_user_id>\w+)/?$", views.load_social_statistics, name="load-social-statistics"
    ),
    url(
        r"^mute_story/(?P<secret_token>\w+)/(?P<shared_story_id>\w+)?$",
        views.mute_story,
        name="social-mute-story",
    ),
    url(r"^(?P<username>[-\w]+)/?$", views.shared_stories_public, name="shared-stories-public"),
]
