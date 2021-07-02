import factory
from factory.fuzzy import FuzzyAttribute
from factory.django import DjangoModelFactory
from faker import Faker
from apps.rss_feeds.factories import FeedFactory
from apps.reader.models import Feature, UserSubscription, UserSubscriptionFolders
from apps.profile.factories import UserFactory

fake = Faker()

def generate_folder():
    string = '{"'
    string += " ".join(fake.words(2))
    string += '": ['
    for _ in range(3):
        string += f"{fake.pyint()}, "
    string = string[:-2]
    string += "]},"
    return string

def generate_folders():
    """
    "folders": "[5299728, 644144, 1187026, {\"Brainiacs & Opinion\": [569, 38, 3581, 183139, 1186180, 15]}, {\"Science & Technology\": [731503, 140145, 1272495, 76, 161, 39, {\"Hacker\": [5985150, 3323431]}]}, {\"Humor\": [212379, 3530, 5994357]}, {\"Videos\": [3240, 5168]}]"
    """
    string = '"folders":['
    
    for _ in range(3):
        string += f"{fake.pyint()}, "
    for _ in range(3):
        string += generate_folder()

    string = string[:-1] + "]"
    return string

class UserSubscriptionFoldersFactory(DjangoModelFactory):
    user = factory.SubFactory(UserFactory)
    folders = FuzzyAttribute(generate_folders)

    class Meta:
        model = UserSubscriptionFolders

    
class UserSubscriptionFactory(DjangoModelFactory):
    user = factory.SubFactory(UserFactory)
    feed = FuzzyAttribute(FeedFactory)
    last_read_date = factory.Faker('date_time')

    class Meta:
        model = UserSubscription


class FeatureFactory(DjangoModelFactory):
    description = factory.Faker('text')
    date = factory.Faker('date_time')
    class Meta:
        model = Feature
