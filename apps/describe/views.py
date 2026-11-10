"""apps/describe/views.py: endpoints for searching feeds by description.

Mounted under /discover/describe/ (see apps/discover/urls.py). The web Describe
tab, the iOS app and the Android app all use these four endpoints:

  POST start    {prompt, search_id?, request_id?}  start, or re-run in place
  GET  status   ?search_id=                        progress and results so far
  GET  history                                     the user's last searches
  POST delete   {search_id}                        remove one history entry
"""

import re
import uuid

from django.core.cache import cache
from django.utils.translation import gettext
from django.views.decorators.http import require_http_methods

from apps.describe.models import MDescribeSearch
from apps.describe.tasks import DescribeFeedsSearch
from apps.describe.usage import TIER_FREE, DescribeUsageTracker
from utils import json_functions as json
from utils import log as logging
from utils.user_functions import ajax_login_required

MIN_PROMPT_LENGTH = 3
MAX_PROMPT_LENGTH = 500
# apps/describe/views.py: long enough to cover the handful of queries a start makes.
START_LOCK_SECONDS = 15
REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9_\-]{8,64}$")


@ajax_login_required
@require_http_methods(["POST"])
@json.json_view
def start_search(request):
    prompt = " ".join((request.POST.get("prompt") or "").split())
    search_id = request.POST.get("search_id") or None
    request_id = request.POST.get("request_id") or ""

    if request_id and not REQUEST_ID_RE.match(request_id):
        return {"code": -1, "message": gettext("Invalid request identifier")}
    if not request_id:
        request_id = str(uuid.uuid4())

    if len(prompt) < MIN_PROMPT_LENGTH:
        return {"code": -1, "message": gettext("Describe what you'd like to read in a few words.")}
    if len(prompt) > MAX_PROMPT_LENGTH:
        return {
            "code": -1,
            "message": gettext("Descriptions are limited to %(limit)d characters")
            % {"limit": MAX_PROMPT_LENGTH},
        }

    if search_id:
        existing = MDescribeSearch.for_user(request.user.pk, search_id)
        if not existing:
            return {"code": -1, "message": gettext("That search is no longer in your history.")}
        if existing.is_running:
            return {
                "code": -1,
                "message": gettext("That search is still running. Wait for it to finish first."),
            }

    # apps/describe/views.py: one search at a time per person. Each holds a work_queue worker for a
    # minute or more, and a stuck one is expired by running_for_user so it never blocks for long.
    # The check, the quota and the new search are claimed together: cache.add is atomic, so two
    # starts that arrive at once (a double tap, web and phone) cannot both pass the checks below.
    already_running = {
        "code": -1,
        "message": gettext("You already have a search running. Wait for it to finish first."),
    }
    start_lock = f"describe:start:{request.user.pk}"
    if not cache.add(start_lock, request_id, START_LOCK_SECONDS):
        return already_running
    try:
        return start_search_locked(request, prompt, search_id, request_id, already_running)
    finally:
        cache.delete(start_lock)


def start_search_locked(request, prompt, search_id, request_id, already_running):
    """The part of start_search that runs while this user's start lock is held."""
    if MDescribeSearch.running_for_user(request.user.pk):
        return already_running

    tracker = DescribeUsageTracker(request.user)
    can_use, limit_message = tracker.can_use()
    if not can_use:
        tracker.record_denied(search_id=search_id, request_id=request_id)
        return {
            "code": -1,
            "message": limit_message,
            "upgrade": tracker.plan_tier == TIER_FREE,
            "usage": tracker.snapshot(),
        }

    search = MDescribeSearch.start(request.user.pk, prompt, request_id, search_id=search_id)
    search.charge(tracker.record_usage(search_id=search.id, request_id=request_id))
    DescribeFeedsSearch.apply_async(
        kwargs={"user_id": request.user.pk, "search_id": str(search.id), "request_id": request_id},
        queue="work_queue",
    )
    logging.user(request, f"~FBDescribe: ~SB{'re-running' if search_id else 'starting'}~SN {prompt[:80]!r}")

    return {
        "code": 1,
        "search": search.to_payload(),
        "usage": tracker.snapshot(),
    }


@ajax_login_required
@json.json_view
def search_status(request):
    search_id = request.GET.get("search_id") or request.POST.get("search_id")
    search = MDescribeSearch.for_user(request.user.pk, search_id)
    if not search:
        return {"code": -1, "message": gettext("That search is no longer in your history.")}
    return {"code": 1, "search": search.to_payload()}


@ajax_login_required
@json.json_view
def search_history(request):
    tracker = DescribeUsageTracker(request.user)
    return {
        "code": 1,
        "searches": MDescribeSearch.history_for_user(request.user.pk),
        "usage": tracker.snapshot(),
    }


@ajax_login_required
@require_http_methods(["POST"])
@json.json_view
def delete_search(request):
    search_id = request.POST.get("search_id")
    search = MDescribeSearch.for_user(request.user.pk, search_id)
    if not search:
        return {"code": -1, "message": gettext("That search is no longer in your history.")}
    search.delete()
    logging.user(request, f"~FBDescribe: deleted search ~SB{search_id}~SN")
    return {"code": 1, "searches": MDescribeSearch.history_for_user(request.user.pk)}
