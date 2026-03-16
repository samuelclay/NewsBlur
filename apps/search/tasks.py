"""Search tasks: index user subscriptions and feeds in Elasticsearch."""

from celery.exceptions import SoftTimeLimitExceeded

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

    user_search = MUserSearch.get_user(user_id)
    user_search.index_subscriptions_chunk_for_search(feed_ids)


@app.task()
def IndexSubscriptionsChunkForDiscover(feed_ids, user_id):
    from apps.search.models import MUserSearch

    try:
        user_search = MUserSearch.get_user(user_id)
        user_search.index_subscriptions_chunk_for_discover(feed_ids)
    except (Exception, SoftTimeLimitExceeded) as e:
        # Catch all exceptions so the chord callback always fires. Without this,
        # a single chunk failure silently breaks the chord, leaving
        # discover_indexing=True forever and causing daily re-indexing retries
        # at ~$3-10/day in embedding costs.
        logging.debug(
            " ---> ~FR~SBDiscover chunk failed for user %s, feeds %s: %s" % (user_id, feed_ids, e)
        )


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


@app.task()
def FinishIndexSubscriptionsForDiscover(results, user_id, start, total):
    logging.debug(" ---> Indexing finished for %s" % (user_id))
    from apps.search.models import MUserSearch

    user_search = MUserSearch.get_user(user_id)
    user_search.finish_index_subscriptions_for_discover(start, total)
