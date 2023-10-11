from django.conf import settings
from django.core.management.base import BaseCommand

from apps.recommendations.models import CollaborativelyFilteredRecommendation
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
        CollaborativelyFilteredRecommendation.store_user_feed_data_to_file(file_name)

        # Load data and get the trained model
        trainset, model = CollaborativelyFilteredRecommendation.load_surprise_data(file_name)

        user_id = options["user_id"]
        n = options["n"]
        feed_ids = options["f"]

        if feed_ids:
            print(f"Finding similar feeds: {feed_ids}")
            # trainset, model = CollaborativelyFilteredRecommendation.load_knnbasic_model(file_name)
            # print(f"Trained, now finding similar feeds: {feed_ids}")
            # similar_feeds = CollaborativelyFilteredRecommendation.recommend_similar_feeds_for_folder(
            #     trainset,
            #     model,
            #     feed_ids.split(","),
            #     n=n,
            # )

            # Load trainset and SVD model (assuming file_name is already known)
            trainset, model = CollaborativelyFilteredRecommendation.load_svd_model(file_name)

            # Assuming target_feed_id is the ID of the feed you want similar feeds for
            similar_feeds = CollaborativelyFilteredRecommendation.recommend_similar_feeds_for_item(
                model, trainset, feed_ids, n=n
            )

            print(f"Found {len(similar_feeds)} similar feeds to {Feed.get_by_id(feed_ids)}")
            for f in similar_feeds:
                feed = Feed.get_by_id(f)
                if not feed:
                    continue
                print(feed)
        elif user_id:
            # Print the recommendations
            self.stdout.write(self.style.SUCCESS(f"Recommendations for user {user_id}:"))
            for feed_id in recommendations:
                self.stdout.write(str(feed_id))
