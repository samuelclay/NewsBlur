"""apps/describe/tasks.py: runs a Describe search in Celery and streams it over Redis pubsub.

Events are published on the user's channel with a "describe:" prefix. The node
socket server (node/describe.coffee) relays them to the browser as
"describe:<type>" socket events. The MDescribeSearch document is updated
alongside, so clients that poll /discover/describe/status see the same state.
"""

import json

import redis
from celery.exceptions import SoftTimeLimitExceeded
from django.conf import settings
from django.contrib.auth.models import User
from django.utils.translation import gettext

from apps.describe.models import STATUS_QUEUED, MDescribeSearch
from apps.describe.pipeline import DescribeFeedSearch
from apps.describe.usage import DescribeUsageTracker
from newsblur_web.celeryapp import app
from utils import log as logging
from utils.languages import account_translation


@app.task(name="describe-feeds-search", time_limit=420, soft_time_limit=390)
def DescribeFeedsSearch(user_id, search_id, request_id=None):
    user = User.objects.get(pk=user_id)
    search = MDescribeSearch.for_user(user_id, search_id)
    if not search:
        logging.user(user, f"~FBDescribe: ~FRsearch {search_id} not found~SN, skipping")
        return {"code": -1, "message": "Search not found"}

    if request_id and search.request_id != request_id:
        logging.user(
            user, f"~FBDescribe: ~FRstale task~SN for search ~SB{search_id}~SN, a newer run replaced it"
        )
        return {"code": -1, "message": "Search was restarted"}

    # apps/describe/tasks.py: only a queued search runs. One that was expired while it waited in the
    # queue (MDescribeSearch.expire_if_stale), or a task delivered twice, stops here.
    if search.status != STATUS_QUEUED:
        logging.user(user, f"~FBDescribe: ~FRskipping~SN search ~SB{search_id}~SN, already {search.status}")
        return {"code": -1, "message": "Search is not waiting to run"}

    # apps/describe/tasks.py: a task has no request, so gettext would use the server's language for
    # every phase message, note and error. The whole run speaks the account's language instead.
    with account_translation(user.profile):
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        request_token = request_id or search.request_id

        def publish(event_type, extra=None):
            payload = {"type": event_type, "search_id": str(search.id), "request_id": request_token}
            if extra:
                payload.update(extra)
            try:
                r.publish(user.username, "describe:" + json.dumps(payload, ensure_ascii=False, default=str))
            except redis.RedisError:
                logging.user(user, f"~FBDescribe: ~FR~SBPublish failure~SN for event ~SB{event_type}~SN")

        logging.user(user, f"~FBDescribe: ~SBstarting~SN search ~SB{search.id}~SN: {search.prompt[:80]!r}")
        pipeline = DescribeFeedSearch(search, user, publish)
        try:
            pipeline.run()
        except SoftTimeLimitExceeded:
            logging.user(user, f"~FBDescribe: ~FRout of time~SN on search ~SB{search.id}~SN, finishing early")
            pipeline.finish(note=gettext("The search ran out of time, so this is what was found so far."))
        except Exception as e:
            search.mark_error(str(e)[:300])
            publish("error", {"error": gettext("Something went wrong while searching. Please try again.")})
            logging.user(user, f"~FBDescribe: ~FR~SBError~SN on search ~SB{search.id}~SN: {e}")
            raise

        tracker = DescribeUsageTracker(user)
        publish("usage", {"message": tracker.get_usage_message(), "usage": tracker.snapshot()})
        logging.user(
            user,
            f"~FBDescribe: ~FGfinished~SN search ~SB{search.id}~SN with ~SB{len(pipeline.results)}~SN feeds "
            f"in {pipeline.stats.get('duration_seconds')}s",
        )
        return {"code": 1, "search_id": str(search.id), "result_count": len(pipeline.results)}
