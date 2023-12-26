import numpy as np
import pandas as pd
from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError
from lightfm import LightFM
from scipy.sparse import coo_matrix, csr_matrix
from sklearn.feature_extraction.text import TfidfTransformer
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.neighbors import NearestNeighbors

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

            def calculate_similarity(user_feed_matrix):
                # Ensure the matrix is in CSR format for efficient row-wise operations
                if not isinstance(user_feed_matrix, csr_matrix):
                    user_feed_matrix = csr_matrix(user_feed_matrix)

                # Compute the cosine similarity matrix (result is dense, handle with care)
                similarity_matrix = cosine_similarity(user_feed_matrix.T, dense_output=False)
                return similarity_matrix

            def recommend_feeds_knn(feed_id, user_feed_matrix, n_items=10):
                model_knn = NearestNeighbors(
                    metric="cosine", algorithm="brute", n_neighbors=n_items, n_jobs=-1
                )

                # Fit the model
                model_knn.fit(user_feed_matrix.T)  # Transpose to get feed-wise neighbors

                # Find neighbors for the specified feed
                distances, indices = model_knn.kneighbors(
                    user_feed_matrix.T[feed_id], n_neighbors=n_items + 1
                )

                # Exclude the feed itself and return the indices of recommended feeds
                recommended_feeds = [idx for idx in indices[0] if idx != feed_id]

                return recommended_feeds[:n_items]

            # Recommend for a specific feed ID
            feed_id = options["feed"]
            self.stdout.write(
                self.style.SUCCESS(f"Generating recommendations for feed: {Feed.get_by_id(feed_id)}")
            )
            # Create a NumPy array for the number of subscribers per feed
            similarity_matrix = calculate_similarity(user_feed_matrix)
            top_recommended_feeds = recommend_feeds_knn(feed_id, similarity_matrix)
            self.stdout.write(
                f"Found {len(top_recommended_feeds)} recommendations for feed ID {feed_id}: {top_recommended_feeds}"
            )

            for feed_id in top_recommended_feeds:
                feed = Feed.get_by_id(feed_id)
                if not feed:
                    continue
                self.stdout.write(f"\tFeed: {feed}")

        except FileNotFoundError:
            raise CommandError('File "%s" does not exist.' % csv_path)
