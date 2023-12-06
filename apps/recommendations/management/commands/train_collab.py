import logging
import os

from django.conf import settings
from django.contrib.auth.models import User
from django.core.management.base import BaseCommand

from apps.reader.models import UserSubscription
from apps.recommendations.models import CollaborativelyFilteredRecommendation
from apps.rss_feeds.models import Feed

logger = logging.getLogger(__name__)


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
            "--skip",
            "-s",
            type=int,
            required=False,
            help="# of user pks to skip, for continuing a previous run",
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
        parser.add_argument("--path", type=str, required=False, help="Path to the data file")

    def handle(self, *args, **options):
        user_id = options["user_id"]
        n = options["n"]
        clear = options.get("clear", False)
        skip = options.get("skip", 0)

        # Store user feed data to file
        os.makedirs(settings.SURPRISE_DATA_FOLDER, exist_ok=True)
        file_name = options.get("path", f"{settings.SURPRISE_DATA_FOLDER}/user_feed_data.csv")
        CollaborativelyFilteredRecommendation.store_user_feed_data_to_file(file_name, force=clear, skip=skip)

        # Load data and get the trained model
        model = CollaborativelyFilteredRecommendation.load_surprise_data(file_name)

        user_id = options["user_id"]
        n = options["n"]
        feed_ids = options["f"]

        logger.debug(f"Generating recommendations for user {User.objects.get(id=user_id)}")
        recommendations = self.get_recommendations(model, user_id, feed_ids, n)
        for feed_id in recommendations:
            feed = Feed.get_by_id(feed_id)
            print(f"Feed ID: {feed}")

    def get_recommendations(self, model, user_id, feed_ids, n):
        # If feed_ids are not provided, get all feed ids
        feed_ids = [feed.id for feed in Feed.objects.all()]

        # Predict ratings for all feeds and sort them
        predictions = [model.predict(user_id, feed_id) for feed_id in feed_ids]
        predictions.sort(key=lambda x: x.est, reverse=True)

        # Return top N feed ids
        return [pred.iid for pred in predictions[:n]]
