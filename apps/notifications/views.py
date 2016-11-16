from django.contrib.auth.decorators import login_required
from utils import json_functions as json
from utils.user_functions import get_user, ajax_login_required
from apps.notifications.models import MUserFeedNotification


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
    feed_id = request.POST['feed_id']
    notification_types = request.POST.getlist('notification_types')
    notification_filter = request.POST.get('notification_filter')
    
    try:
        notification = MUserFeedNotification.objects.get(user_id=user.pk, feed_id=feed_id)
    except MUserFeedNotification.DoesNotExist:
        params = {
            "user_id": user.pk, 
            "feed_id": feed_id,
        }
        notification = MUserFeedNotification.objects.create(**params)
    
    notification.is_focus = bool(notification_filter == "focus")
    notification.is_email = bool('email' in notification_types)
    notification.is_ios = bool('ios' in notification_types)
    notification.is_android = bool('android' in notification_types)
    notification.is_web = bool('web' in notification_types)
    notification.save()
    
    if (not notification.is_email and
        not notification.is_ios and
        not notification.is_android and
        not notification.is_web):
        notification.delete()
        
    notifications_by_feed = MUserFeedNotification.feeds_for_user(user.pk)

    return {"notifications_by_feed": notifications_by_feed}
