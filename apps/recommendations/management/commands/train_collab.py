from django.core.management.base import BaseCommand
from apps.recommendations.models import CollaborativelyFilteredRecommendation


class Command(BaseCommand):
    help = "Generate recommendations based on Collaborative Filtering"

    def add_arguments(self, parser):
        parser.add_argument(
            "--user_id", type=int, required=True, help="ID of the user for whom to generate recommendations"
        )
        parser.add_argument(
            "--n", type=int, default=10, help="Number of recommendations to generate (default is 10)"
        )

    def handle(self, *args, **options):
        # Store user feed data to file
        file_name = "user_feed_data.csv"
        CollaborativelyFilteredRecommendation.store_user_feed_data_to_file(file_name)

        # Load data and get the trained model
        trainset, model = CollaborativelyFilteredRecommendation.load_surprise_data(file_name)

        user_id = options["user_id"]
        n = options["n"]

        # Get recommendations
        recommendations = CollaborativelyFilteredRecommendation.get_recommendations(
            trainset, user_id, model, n
        )

        # Print the recommendations
        self.stdout.write(self.style.SUCCESS(f"Recommendations for user {user_id}:"))
        for feed_id in recommendations:
            self.stdout.write(str(feed_id))
