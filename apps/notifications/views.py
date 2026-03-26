"""Notification views: manage push notification settings and device token registration."""

import redis
from django.conf import settings
from django.contrib.admin.views.decorators import staff_member_required

from apps.notifications.models import (
    MUserClassifierNotification,
    MUserFeedNotification,
    MUserNotificationTokens,
)
from apps.rss_feeds.models import Feed
from utils import json_functions as json
from utils import log as logging
from utils.user_functions import ajax_login_required, get_user
from utils.view_functions import required_params


@ajax_login_required
@json.json_view
def notifications_by_feed(request):
    user = get_user(request)
    notifications_by_feed = MUserFeedNotification.feeds_for_user(user.pk)

    return notifications_by_feed


@ajax_login_required
@json.json_view
def set_notifications_for_feed(request):
    user = get_user(request)
    feed_id = request.POST["feed_id"]
    notification_types = request.POST.getlist("notification_types") or request.POST.getlist(
        "notification_types[]"
    )
    notification_filter = request.POST.get("notification_filter")

    try:
        notification = MUserFeedNotification.objects.get(user_id=user.pk, feed_id=feed_id)
    except MUserFeedNotification.DoesNotExist:
        params = {
            "user_id": user.pk,
            "feed_id": feed_id,
        }
        notification = MUserFeedNotification.objects.create(**params)

    web_was_off = not notification.is_web
    notification.is_focus = bool(notification_filter == "focus")
    notification.is_email = bool("email" in notification_types)
    notification.is_ios = bool("ios" in notification_types)
    notification.is_android = bool("android" in notification_types)
    notification.is_web = bool("web" in notification_types)
    notification.save()

    if (
        not notification.is_email
        and not notification.is_ios
        and not notification.is_android
        and not notification.is_web
    ):
        notification.delete()

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    if web_was_off and notification.is_web:
        r.publish(user.username, "notification:setup:%s" % feed_id)

    notifications_by_feed = MUserFeedNotification.feeds_for_user(user.pk)

    return {"notifications_by_feed": notifications_by_feed}


@ajax_login_required
@json.json_view
def get_classifier_notifications(request):
    """Get all classifier notifications for the current user."""
    user = get_user(request)
    return {"classifier_notifications": MUserClassifierNotification.for_user(user.pk)}


@ajax_login_required
@json.json_view
def set_classifier_notification(request):
    """Set notification channels for a specific classifier. Premium Archive only."""
    user = get_user(request)

    if not user.profile.is_archive:
        return {"code": -1, "message": "Premium Archive required for classifier notifications"}

    classifier_type = request.POST.get("classifier_type", "")
    classifier_value = request.POST.get("classifier_value", "")
    scope = request.POST.get("scope", "feed")
    feed_id = int(request.POST.get("feed_id", 0))
    folder_name = request.POST.get("folder_name", "")
    notification_types = request.POST.getlist("notification_types") or request.POST.getlist(
        "notification_types[]"
    )

    if not classifier_type or not classifier_value:
        return {"code": -1, "message": "classifier_type and classifier_value are required"}

    if classifier_type not in ("title", "author", "tag", "text", "url"):
        return {"code": -1, "message": "Invalid classifier_type"}

    try:
        notif = MUserClassifierNotification.objects.get(
            user_id=user.pk,
            classifier_type=classifier_type,
            classifier_value=classifier_value,
            scope=scope,
            feed_id=feed_id,
            folder_name=folder_name,
        )
    except MUserClassifierNotification.DoesNotExist:
        notif = MUserClassifierNotification.objects.create(
            user_id=user.pk,
            classifier_type=classifier_type,
            classifier_value=classifier_value,
            scope=scope,
            feed_id=feed_id,
            folder_name=folder_name,
        )

    notif.is_email = bool("email" in notification_types)
    notif.is_web = bool("web" in notification_types)
    notif.is_ios = bool("ios" in notification_types)
    notif.is_android = bool("android" in notification_types)
    notif.save()

    # Delete if all channels cleared
    if not any([notif.is_email, notif.is_web, notif.is_ios, notif.is_android]):
        notif.delete()

    logging.user(
        user,
        "~FCSet classifier notification: %s/%s (%s) -> %s"
        % (classifier_type, classifier_value[:30], scope, notification_types),
    )

    return {"classifier_notifications": MUserClassifierNotification.for_user(user.pk)}


@ajax_login_required
@json.json_view
def set_apns_token(request):
    """
    Apple Push Notification Service, token is sent by the iOS app. Used to send
    push notifications to iOS.
    """
    user = get_user(request)
    tokens = MUserNotificationTokens.get_tokens_for_user(user.pk)
    apns_token = request.POST["apns_token"]

    logging.user(user, "~FCUpdating APNS push token")
    if apns_token not in tokens.ios_tokens:
        tokens.ios_tokens.append(apns_token)
        tokens.save()
        return {"message": "Token saved."}

    return {"message": "Token already saved."}


@ajax_login_required
@json.json_view
def set_android_token(request):
    """
    Android's push notification tokens. Not sure why I can't find this function in
    the Android code.
    """
    user = get_user(request)
    tokens = MUserNotificationTokens.get_tokens_for_user(user.pk)
    token = request.POST["token"]

    logging.user(user, "~FCUpdating Android push token")
    if token not in tokens.android_tokens:
        tokens.android_tokens.append(token)
        tokens.save()
        return {"message": "Token saved."}

    return {"message": "Token already saved."}


@required_params(feed_id=int)
@staff_member_required
@json.json_view
def force_push(request):
    """
    Intended to force a push notification for a feed for testing. Handier than the console.
    """
    user = get_user(request)
    feed_id = request.GET["feed_id"]
    count = int(request.GET.get("count", 1))

    logging.user(user, "~BM~FWForce pushing %s stories: ~SB%s" % (count, Feed.get_by_id(feed_id)))
    sent_count, user_count = MUserFeedNotification.push_feed_notifications(
        feed_id, new_stories=count, force=True
    )

    return {"message": "Pushed %s notifications to %s users" % (sent_count, user_count)}
