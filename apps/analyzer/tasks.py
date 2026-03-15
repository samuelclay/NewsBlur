"""Analyzer tasks: email notifications and AI classification."""

from newsblur_web.celeryapp import app
from utils import log as logging


@app.task()
def EmailPopularityQuery(pk):
    from apps.analyzer.models import MPopularityQuery

    query = MPopularityQuery.objects.get(pk=pk)
    logging.debug(" -> ~BB~FCRunning popularity query: ~SB%s" % query)

    query.send_email()


@app.task()
def ClassifyStoriesWithPrompt(user_id, story_hashes):
    """Classify stories with AI prompt classifiers in the background.

    Loads stories from MongoDB, runs them through the user's prompt classifiers,
    and caches results in Redis. Idempotent — cached stories are skipped.
    """
    from apps.analyzer.models import MClassifierPrompt
    from apps.rss_feeds.models import Feed, MStory

    if not story_hashes:
        return

    stories_db = MStory.objects(story_hash__in=story_hashes)
    stories = Feed.format_stories(stories_db)

    if not stories:
        return

    feed_ids = list(set(s["story_feed_id"] for s in stories))

    logging.debug(
        " -> ~BB~FCClassifying ~SB%s~SN stories for user ~SB%s~SN across ~SB%s~SN feeds"
        % (len(stories), user_id, len(feed_ids))
    )

    MClassifierPrompt.classify_stories(user_id, stories, feed_ids=feed_ids)
