from vendor.haystack import indexes
from apps.rss_feeds.models import Feed
from django.conf import settings

class FeedIndex(indexes.SearchIndex, indexes.Indexable):
    text = indexes.IntegerField(document=True, model_attr='pk')
    num_subscribers = indexes.IntegerField(model_attr='num_subscribers')
    address = indexes.EdgeNgramField(model_attr='feed_address')
    title = indexes.EdgeNgramField(model_attr='feed_title')

    def get_model(self):
        return Feed

    def index_queryset(self, using=None):
        """Used when the entire index for model is updated."""
        sub_count = 1 if settings.DEBUG else 10
        return Feed.objects.filter(num_subscribers__gte=sub_count, branch_from_feed__isnull=True)