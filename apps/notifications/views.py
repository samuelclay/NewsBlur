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