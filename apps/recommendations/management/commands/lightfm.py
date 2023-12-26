import numpy as np
import pandas as pd
from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError
from lightfm import LightFM
from scipy.sparse import coo_matrix
from sklearn.feature_extraction.text import TfidfTransformer

from apps.rss_feeds.models import Feed


class Command(BaseCommand):
    help = "Recommend feeds based on a feed ID using LightFM"

    def add_arguments(self, parser):
        parser.add_argument(
            "--path",
            "-p",
            type=str,
            required=False,
            default="docker/volumes/surprise/user_feed_rating_subs.500k.csv",
            help="Path to the CSV file containing user, feed, and rating data",
        )
        parser.add_argument(
            "--feed",
            "-f",
            type=int,
            required=True,
            help="ID of the feed for which to generate recommendations",
        )

    def handle(self, *args, **options):
        csv_path = options["path"]

        try:
            # Load data
            data = pd.read_csv(
                csv_path, header=None, names=["user_id", "feed_id", "rating", "num_subscribers"]
            )

            # Apply a logarithmic transformation to the ratings
            data["rating"] = np.log1p(data["rating"])  # log1p is used to ensure log(0) does not occur

            # Create a sparse matrix
            user_feed_matrix = coo_matrix((data["rating"], (data["user_id"], data["feed_id"]))).tocsr()
            self.stdout.write("Successfully loaded and transformed data")

            # Train the model
            model = LightFM(loss="warp")
            self.stdout.write("Training data...")
            model.fit(user_feed_matrix, epochs=30, num_threads=2)

            def recommend_for_all_users_for_feed(feed_id, user_feed_matrix, feed_subscribers, n_items=10):
                # Apply TF-IDF transformation
                transformer = TfidfTransformer()
                tfidf_matrix = transformer.fit_transform(user_feed_matrix)

                # Calculate the sum of tfidf scores for each feed across all users
                feed_scores = tfidf_matrix.sum(axis=0)

                # Convert to a 1D numpy array
                feed_scores = np.array(feed_scores).squeeze()

                # Adjust the scores based on the number of subscribers
                for idx, score in enumerate(feed_scores):
                    # Apply some adjustment based on feed_subscribers
                    # For example, you could decrease the score for feeds with many subscribers
                    feed_scores[idx] = score / (1 + np.log1p(feed_subscribers[idx]))

                # Sort feeds based on adjusted scores
                top_feeds_indices = np.argsort(-feed_scores)

                # Build the list of recommended feeds
                top_feeds = []
                for idx in top_feeds_indices:
                    if len(top_feeds) >= n_items:
                        break
                    if idx != feed_id:
                        top_feeds.append(idx)

                return top_feeds

            # Recommend for a specific feed ID
            feed_id = options["feed"]
            self.stdout.write(
                self.style.SUCCESS(f"Generating recommendations for feed: {Feed.get_by_id(feed_id)}")
            )
            # Create a NumPy array for the number of subscribers per feed
            max_feed_id = data["feed_id"].max()
            feed_subscribers = np.zeros(max_feed_id + 1)
            for _, row in data.iterrows():
                feed_subscribers[int(row["feed_id"])] = row["num_subscribers"]

            # Call the recommendation function with this data
            top_recommended_feeds = recommend_for_all_users_for_feed(
                feed_id, user_feed_matrix, feed_subscribers
            )
            self.stdout.write(f"Found {len(top_recommended_feeds)} recommendations for feed ID {feed_id}")

            for feed_id in top_recommended_feeds:
                feed = Feed.get_by_id(feed_id)
                if not feed:
                    continue
                self.stdout.write(f"\tFeed: {feed}")

        except FileNotFoundError:
            raise CommandError('File "%s" does not exist.' % csv_path)
