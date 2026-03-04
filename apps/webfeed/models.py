import datetime

import mongoengine as mongo


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
