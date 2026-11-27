"""Search tasks: index user subscriptions and feeds in Elasticsearch."""

import time

from celery.exceptions import SoftTimeLimitExceeded
from django.conf import settings

from newsblur_web.celeryapp import app
from utils import log as logging


@app.task()
def IndexSubscriptionsForSearch(user_id):
    from apps.search.models import MUserSearch

    user_search = MUserSearch.get_user(user_id)
    user_search.index_subscriptions_for_search()


@app.task()
def IndexSubscriptionsForDiscover(user_id):
    from apps.search.models import MUserSearch

    user_search = MUserSearch.get_user(user_id)
    user_search.index_subscriptions_for_discover()


@app.task()
def IndexSubscriptionsChunkForSearch(feed_ids, user_id):
    logging.debug(" ---> Indexing: %s for %s" % (feed_ids, user_id))
    from apps.search.models import MUserSearch

    try:
        user_search = MUserSearch.get_user(user_id)
        user_search.index_subscriptions_chunk_for_search(feed_ids)
    except (Exception, SoftTimeLimitExceeded) as e:
        # Catch all exceptions so the chord callback always fires. Without this,
        # a single chunk failure silently breaks the chord, leaving
        # subscriptions_indexing=True forever and users stuck on "Indexing your
        # feeds for search" indefinitely. Mirrors the discover fix in f94100f93.
        logging.debug(" ---> ~FR~SBSearch chunk failed for user %s, feeds %s: %s" % (user_id, feed_ids, e))


@app.task()
def IndexSubscriptionsChunkForDiscover(feed_ids, user_id, claim_id=None):
    from apps.search.models import MUserSearch

    if claim_id:
        owner = f"{claim_id}:running"
        feed_ids = MUserSearch.update_discover_claims(feed_ids, claim_id, owner)
        if not feed_ids:
            return
    try:
        user_search = MUserSearch.get_user(user_id)
        user_search.index_subscriptions_chunk_for_discover(feed_ids)
    except (Exception, SoftTimeLimitExceeded) as e:
        # Catch all exceptions so the chord callback always fires. Without this,
        # a single chunk failure silently breaks the chord, leaving
        # discover_indexing=True forever and causing daily re-indexing retries
        # at ~$3-10/day in embedding costs.
        logging.debug(" ---> ~FR~SBDiscover chunk failed for user %s, feeds %s: %s" % (user_id, feed_ids, e))
    finally:
        if claim_id:
            MUserSearch.update_discover_claims(feed_ids, owner)


@app.task()
def IndexFeedsForSearch(feed_ids, user_id):
    from apps.search.models import MUserSearch

    MUserSearch.index_feeds_for_search(feed_ids, user_id)


@app.task()
def FinishIndexSubscriptionsForSearch(results, user_id, start):
    logging.debug(" ---> Indexing finished for %s" % (user_id))
    from apps.search.models import MUserSearch

    user_search = MUserSearch.get_user(user_id)
    user_search.finish_index_subscriptions_for_search(start)


@app.task(bind=True, max_retries=None)
def FinishIndexSubscriptionsForDiscover(
    self, results, user_id, start, total, notify_only=False, feed_ids=None
):
    from apps.search.models import MUserSearch

    # apps/search/models.py gives each claim one lease in the queue and one on the worker.
    # Later runs can reclaim a failed feed, but must not keep this account waiting indefinitely.
    deadline = start + 2 * settings.MAX_SECONDS_COMPLETE_ARCHIVE_FETCH
    if feed_ids and time.time() < deadline and MUserSearch.claimed_discover_feeds(feed_ids):
        raise self.retry(countdown=15)

    logging.debug(" ---> Indexing finished for %s" % (user_id))
    user_search = MUserSearch.get_user(user_id)
    user_search.finish_index_subscriptions_for_discover(start, total, notify_only=notify_only)
