from faker import Faker
import factory
from factory.django import DjangoModelFactory
from factory.fuzzy import FuzzyAttribute
from apps.rss_feeds.models import DuplicateFeed, Feed
from django.conf import settings

NEWSBLUR_DIR = settings.NEWSBLUR_DIR
fake = Faker()

def generate_address():
    return f"{NEWSBLUR_DIR}/apps/analyzer/fixtures/{fake.word()}.xml"

class FeedFactory(DjangoModelFactory):
    feed_address = FuzzyAttribute(generate_address)
    feed_link = FuzzyAttribute(generate_address)
    creation = factory.Faker('date')
    feed_title = factory.Faker('sentence')
    last_update = factory.Faker('date_time')
    next_scheduled_update = factory.Faker('date_time')
    last_story_date = factory.Faker('date_time')
    min_to_decay = 1
    last_modified = factory.Faker('date_time')
    hash_address_and_link = fake.sha1()

    class Meta:
        model = Feed

class DuplicateFeedFactory(DjangoModelFactory):
    class Meta:
        model = DuplicateFeed