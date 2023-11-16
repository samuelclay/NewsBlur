import os

from django.conf import settings
from django.core.management.base import BaseCommand

from apps.reader.models import UserSubscription
from apps.recommendations.models import CollaborativelyFilteredRecommendation
from apps.rss_feeds.models import Feed


class Command(BaseCommand):
    help = "Generate recommendations based on Collaborative Filtering"

    def add_arguments(self, parser):
        parser.add_argument(
            "--user_id",
            "-u",
            type=int,
            required=True,
            help="ID of the user for whom to generate recommendations",
        )
        parser.add_argument(
            "-n", type=int, default=10, help="Number of recommendations to generate (default is 10)"
        )
        parser.add_argument(
            "--clear",
            action="store_true",
            required=False,
            help="Deltes the csv and recreates the user_feed matrix",
        )

    def handle(self, *args, **options):
        user_id = options["user_id"]
        n = options["n"]
        clear = options.get("clear", False)

        # Store user feed data to file
        os.makedirs(settings.SURPRISE_DATA_FOLDER, exist_ok=True)
        file_name = f"{settings.SURPRISE_DATA_FOLDER}/user_feed_data.csv"
        CollaborativelyFilteredRecommendation.store_user_feed_data_to_file(file_name, force=clear)

        # Load data and get the trained model
        trainset, model = CollaborativelyFilteredRecommendation.load_knn_model(file_name)
        # model = CollaborativelyFilteredRecommendation.load_surprise_data(file_name)
        # model = CollaborativelyFilteredRecommendation.nmf(model)
        # Get list of all feed IDs to make predictions
        all_feed_ids = [
            feed.id
            for feed in Feed.objects.filter(num_subscribers__gte=5, active_subscribers__gte=5).only("id")
        ]

        # Predict ratings for all feeds for the given user
        predicted_ratings = CollaborativelyFilteredRecommendation.get_recommendations(
            model, user_id, all_feed_ids
        )

        # Remove feeds that user is already subscribed to
        user_subscribed_feeds = UserSubscription.objects.filter(user_id=user_id).values_list(
            "feed_id", flat=True
        )
        for feed_id in user_subscribed_feeds:
            if feed_id in predicted_ratings:
                del predicted_ratings[feed_id]

        # Sort feeds based on predicted ratings
        print(predicted_ratings)
        recommended_feed_ids = sorted(
            predicted_ratings.keys(),
            key=lambda f: Feed.get_by_id(f).well_read_score()["reach_score"],
            reverse=True,
        )[:n]

        print(f"Top {n} feeds recommended for user {user_id}: {recommended_feed_ids}")

        print(f"Found {len(recommended_feed_ids)} similar feeds")
        for f in recommended_feed_ids:
            feed = Feed.get_by_id(f)
            if not feed:
                continue
            print(feed)
