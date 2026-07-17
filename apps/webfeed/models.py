import datetime
import re

import mongoengine as mongo

# A story container XPath must describe the page's repeating structure, not enumerate
# the specific items that happened to be on it during analysis. A container pinned to
# item ids can only ever re-match those exact items, so the feed never discovers a new
# story. Long digit runs are item ids (e.g. @data-test-id='listing-item-32438580283')
# and long or-chains enumerate analysis-time items one by one. Checked when variants
# are generated (apps/webfeed/tasks.py) and again at subscribe (apps/webfeed/views.py).
ITEM_ID_DIGIT_RUN_RE = re.compile(r"\d{5,}")
MAX_CONTAINER_OR_CHAIN = 2


def is_degenerate_container_xpath(xpath):
    """True when a container XPath is pinned to specific items instead of structure."""
    if not xpath:
        return False
    if ITEM_ID_DIGIT_RUN_RE.search(xpath):
        return True
    if xpath.count(" or ") > MAX_CONTAINER_OR_CHAIN:
        return True
    return False


class MWebFeedConfig(mongo.Document):
    """Configuration for a web feed that extracts stories from a website using XPath expressions."""

    feed_id = mongo.IntField(unique=True, required=True)
    url = mongo.StringField(required=True)
    story_container_xpath = mongo.StringField(required=True)
    title_xpath = mongo.StringField(required=True)
    link_xpath = mongo.StringField(required=True)
    content_xpath = mongo.StringField()
    image_xpath = mongo.StringField()
    author_xpath = mongo.StringField()
    date_xpath = mongo.StringField()
    staleness_days = mongo.IntField(default=30)
    mark_unread_on_change = mongo.BooleanField(default=False)
    variant_index = mongo.IntField()
    analysis_html_hash = mongo.StringField()
    last_successful_extract = mongo.DateTimeField()
    consecutive_failures = mongo.IntField(default=0)
    needs_reanalysis = mongo.BooleanField(default=False)
    created_at = mongo.DateTimeField(default=datetime.datetime.utcnow)
    updated_at = mongo.DateTimeField(default=datetime.datetime.utcnow)

    meta = {
        "collection": "webfeed_configs",
        "indexes": [
            {"fields": ["feed_id"], "unique": True},
            "url",
            "needs_reanalysis",
        ],
        "allow_inheritance": False,
        "strict": False,
    }

    def save(self, *args, **kwargs):
        self.updated_at = datetime.datetime.utcnow()
        super(MWebFeedConfig, self).save(*args, **kwargs)

    @classmethod
    def get_config(cls, feed_id):
        try:
            return cls.objects.get(feed_id=feed_id)
        except cls.DoesNotExist:
            return None

    def record_success(self):
        self.consecutive_failures = 0
        self.last_successful_extract = datetime.datetime.utcnow()
        self.needs_reanalysis = False
        self.save()

    def record_failure(self):
        self.consecutive_failures += 1
        if self.consecutive_failures >= 3:
            self.needs_reanalysis = True
        self.save()
