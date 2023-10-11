from django.conf import settings
from django.core.management.base import BaseCommand

from apps.recommendations.models import SubscriptionBasedRecommendation
from apps.rss_feeds.models import Feed


class Command(BaseCommand):
    help = "Generate recommendations based on Collaborative Filtering"

    def add_arguments(self, parser):
        parser.add_argument(
            "--user_id", type=int, required=False, help="ID of the user for whom to generate recommendations"
        )
        parser.add_argument(
            "--n", type=int, default=10, help="Number of recommendations to generate (default is 10)"
        )
        parser.add_argument("-f", type=str, required=False, help="Feed ids, separated by commas")

    def handle(self, *args, **options):
        # Store user feed data to file
        file_name = f"{settings.SURPRISE_DATA_FOLDER}/user_feed_data.csv"

        user_id = options["user_id"]
        n = options["n"]
        feed_ids = options["f"]

        # First, store the data
        SubscriptionBasedRecommendation.store_user_feed_data_to_file(file_name)

        if feed_ids:
            print(f"Finding similar feeds: {feed_ids}")
            # Assuming user_subscriptions is a list where each element is a space-separated string of feed IDs/names that a user is subscribed to
            user_subscriptions = SubscriptionBasedRecommendation.generate_user_subscription_documents(
                file_name
            )

            # To get recommendations for a specific set of feeds (for instance, feeds from a specific folder)
            feed_ids = feed_ids.split(",")
            recommended_feeds = SubscriptionBasedRecommendation.recommend_feeds_for_feed_set(
                feed_ids, user_subscriptions
            )

            print(f"Found {len(recommended_feeds)} similar feeds to {[Feed.get_by_id(f) for f in feed_ids]}")
            for f in recommended_feeds:
                feed = Feed.get_by_id(f)
                if not feed:
                    continue
                print(feed)
        elif user_id:
            # Generate user subscription "documents"
            user_subscriptions = SubscriptionBasedRecommendation.generate_user_subscription_documents(
                file_name
            )

            # Get recommendations for a user at a specific index
            recommended_feeds = SubscriptionBasedRecommendation.recommend_feeds_for_user(
                user_id, user_subscriptions
            )

            self.stdout.write(self.style.SUCCESS(f"Recommendations for user {user_id}:"))
            for feed_id in recommended_feeds:
                feed = Feed.get_by_id(feed_id)
                if not feed:
                    continue
                print(feed)
