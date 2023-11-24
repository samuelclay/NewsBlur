import datetime
import os
import tempfile
from collections import defaultdict

import mongoengine as mongo
from django.contrib.auth.models import User
from django.core.paginator import Paginator
from django.db import models

# # from sklearn.feature_extraction.text import TfidfVectorizer
# # from sklearn.metrics.pairwise import cosine_similarity, linear_kernel
from surprise import NMF, SVD, Dataset, KNNBasic, KNNWithMeans, Reader, accuracy
from surprise.model_selection import cross_validate, train_test_split

from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.models import Feed
from utils import json_functions as json


class RecommendedFeed(models.Model):
    feed = models.ForeignKey(Feed, related_name="recommendations", on_delete=models.CASCADE)
    user = models.ForeignKey(User, related_name="recommendations", on_delete=models.CASCADE)
    description = models.TextField(null=True, blank=True)
    is_public = models.BooleanField(default=False)
    created_date = models.DateField(auto_now_add=True)
    approved_date = models.DateField(null=True)
    declined_date = models.DateField(null=True)
    twitter = models.CharField(max_length=50, null=True, blank=True)

    def __str__(self):
        return "%s (%s)" % (self.feed, self.approved_date or self.created_date)

    class Meta:
        ordering = ["-approved_date", "-created_date"]


class RecommendedFeedUserFeedback(models.Model):
    recommendation = models.ForeignKey(RecommendedFeed, related_name="feedback", on_delete=models.CASCADE)
    user = models.ForeignKey(User, related_name="feed_feedback", on_delete=models.CASCADE)
    score = models.IntegerField(default=0)
    created_date = models.DateField(auto_now_add=True)


class MFeedFolder(mongo.Document):
    feed_id = mongo.IntField()
    folder = mongo.StringField()
    count = mongo.IntField()

    meta = {
        "collection": "feed_folders",
        "indexes": ["feed_id", "folder"],
        "allow_inheritance": False,
    }

    def __str__(self):
        feed = Feed.get_by_id(self.feed_id)
        return "%s - %s (%s)" % (feed, self.folder, self.count)

    @classmethod
    def count_feed(cls, feed_id):
        feed = Feed.get_by_id(feed_id)
        print(feed)
        found_folders = defaultdict(int)
        user_ids = [sub["user_id"] for sub in UserSubscription.objects.filter(feed=feed).values("user_id")]
        usf = UserSubscriptionFolders.objects.filter(user_id__in=user_ids)
        for sub in usf:
            user_sub_folders = json.decode(sub.folders)
            folder_title = cls.feed_folder_parent(user_sub_folders, feed.pk)
            if not folder_title:
                continue
            found_folders[folder_title.lower()] += 1
            # print "%-20s - %s" % (folder_title if folder_title != '' else '[Top]', sub.user_id)
        print(sorted(list(found_folders.items()), key=lambda f: f[1], reverse=True))

    @classmethod
    def feed_folder_parent(cls, folders, feed_id, folder_title=""):
        for item in folders:
            if isinstance(item, int) and item == feed_id:
                return folder_title
            elif isinstance(item, dict):
                for f_k, f_v in list(item.items()):
                    sub_folder_title = cls.feed_folder_parent(f_v, feed_id, f_k)
                    if sub_folder_title:
                        return sub_folder_title


class CollaborativelyFilteredRecommendation(models.Model):
    @classmethod
    def store_user_feed_data_to_file(cls, file_name, force=False, skip=0):
        if os.path.exists(file_name) and not force:
            print(f"{file_name} exists, skipping storing data...")
            return

        temp_file = open(file_name, "w+")
        max_user_pk = User.objects.latest("pk").pk
        for user_id in range(skip, max_user_pk):
            try:
                user = User.objects.get(pk=user_id)
            except User.DoesNotExist:
                continue
            # Only include feeds with num_subscribers >= 5
            last_month = datetime.datetime.now() - datetime.timedelta(days=30)
            subs = UserSubscription.objects.filter(
                user=user,
                feed__num_subscribers__gte=5,
                feed__stories_last_month__gte=1,
                feed__active_subscribers__gte=1,
                feed__last_story_date__gte=last_month,
            )
            for sub in subs:
                well_read_score = sub.feed.well_read_score(user_id=sub.user_id)["reach_score"]
                if not well_read_score:
                    continue
                temp_file.write(f"{user.id},{sub.feed_id},{well_read_score}\n")
            temp_file.flush()
            if user_id % 1000 == 0:
                print(f"User {user_id} saved to {file_name}")

    @classmethod
    def load_surprise_data(cls, file_name):
        reader = Reader(line_format="user item rating", sep=",", rating_scale=(0, 100))
        data = Dataset.load_from_file(file_name, reader)

        trainset, testset = train_test_split(data, test_size=0.2)
        return trainset, testset

    @classmethod
    def svd(cls, trainset, testset):
        model = SVD()
        model.fit(trainset)
        predictions = model.test(testset)
        accuracy.rmse(predictions)

        return model

    @classmethod
    def nmf(cls, trainset):
        model = NMF()
        model.fit(trainset)
        return model
        # cross_validate(model, data, measures=["RMSE", "MAE"], cv=5, verbose=True)

        return model

    @classmethod
    def get_predicted_ratings(cls, model, user_id, all_feed_ids):
        predicted_ratings = {}
        for feed_id in all_feed_ids:
            pred = model.predict(user_id, feed_id)
            predicted_ratings[feed_id] = pred.est
        return predicted_ratings

    @classmethod
    def get_recommendations(cls, user_id, feed_ids, model, n=10):
        # Predict ratings for all feeds
        predictions = [model.predict(str(user_id), str(feed_id), verbose=False) for feed_id in feed_ids]

        # Sort by highest predicted rating
        sorted_predictions = sorted(predictions, key=lambda x: x.est if x.est != 1 else 0, reverse=True)

        # Return top n feed IDs as recommendations
        return [(pred.iid, pred.est) for pred in sorted_predictions[:n]]

    @classmethod
    def load_knn_model(cls, file_name):
        """OOM"""
        print(f"Loading user item rating from {file_name}")
        reader = Reader(line_format="user item rating", sep=",", rating_scale=(0, 100))
        data = Dataset.load_from_file(file_name, reader)
        print(f"Training model with {data.n_users} users and {data.n_items} items")
        trainset = data.build_full_trainset()
        print(f"Training set has {trainset.n_users} users and {trainset.n_items} items")

        # Using KNNWithMeans to compute item-item similarities
        model = KNNBasic(sim_options={"name": "cosine", "user_based": False})
        model.fit(trainset)

        return trainset, model

    @classmethod
    def load_knnbasic_model(cls, file_name):
        """OOM"""
        reader = Reader(line_format="user item rating", sep=",", rating_scale=(0, 1))
        data = Dataset.load_from_file(file_name, reader)
        trainset = data.build_full_trainset()

        # Print the number of users and items from trainset, not data
        print(f"Training model with {trainset.n_users} users and {trainset.n_items} items")

        # Configure KNNBasic for item-item similarities
        model = KNNBasic(sim_options={"name": "cosine", "user_based": False})
        model.fit(trainset)

        return trainset, model

    @classmethod
    def get_feed_similarities(cls, trainset, model, feed_id, n=10):
        """OOM"""
        # Retrieve the inner id of the feed
        feed_inner_id = trainset.to_inner_iid(str(feed_id))

        # Get the top N most similar feeds
        neighbors = model.get_neighbors(feed_inner_id, k=n)
        similar_feeds = [trainset.to_raw_iid(inner_id) for inner_id in neighbors]

        return similar_feeds

    @classmethod
    def recommend_similar_feeds_for_folder(cls, trainset, model, folder_feeds, n=10):
        all_similar_feeds = defaultdict(float)

        for feed_id in folder_feeds:
            similar_feeds = cls.get_feed_similarities(trainset, model, feed_id, n)
            for sf in similar_feeds:
                all_similar_feeds[sf] += 1  # Count occurrences for ranking

        # Sort feeds based on occurrence and take top N
        sorted_feeds = sorted(all_similar_feeds, key=all_similar_feeds.get, reverse=True)
        recommendations = [feed for feed in sorted_feeds if feed not in folder_feeds][:n]

        return recommendations

    @classmethod
    def load_svd_model(cls, file_name):
        reader = Reader(line_format="user item rating", sep=",", rating_scale=(0, 1))
        data = Dataset.load_from_file(file_name, reader)
        trainset = data.build_full_trainset()

        print(f"Training SVG model")
        model = SVD()
        model.fit(trainset)
        print(f"SVD model trained")

        return trainset, model

    @classmethod
    def get_item_similarities(cls, model):
        """OOM"""
        # Retrieve item factor vectors (embeddings)
        item_factors = model.qi

        # Compute cosine similarity between item embeddings
        item_similarities = cosine_similarity(item_factors)

        return item_similarities

    # @classmethod
    # def build_faiss_index(cls, model):
    #     # Retrieve item factor vectors (embeddings)
    #     item_factors = model.qi.astype("float32")  # Faiss requires float32 type

    #     # Build the Faiss index
    #     index = faiss.IndexFlatL2(item_factors.shape[1])
    #     index.add(item_factors)

    #     return index

    # @classmethod
    # def build_faiss_ivfpq_index(cls, model, nlists=100):
    #     item_factors = model.qi.astype("float32")
    #     dim = item_factors.shape[1]

    #     # Choose an M that divides dim. This is just an example, adjust as needed.
    #     M = 4 if dim % 4 == 0 else 8 if dim % 8 == 0 else 1  # Adjust this based on your actual dimension

    #     # Quantizer and Index
    #     quantizer = faiss.IndexFlatL2(dim)
    #     index = faiss.IndexIVFPQ(quantizer, dim, nlists, M, 8)  # Adjusted M
    #     index.train(item_factors)
    #     index.add(item_factors)

    #     return index

    @classmethod
    def recommend_similar_feeds_for_item_nnmf(cls, model, trainset, user_id, feed_ids, n=10):
        users_who_liked_feeds = set()

        # Collect users who interacted with these feeds
        for _, uid, _ in trainset.all_ratings():
            for feed_id in feed_ids:
                if model.predict(uid, feed_id).est > 0.5:  # Assuming > 0.5 implies interaction/like
                    users_who_liked_feeds.add(uid)

        # Predict feeds for these users
        all_recommendations = {}
        print(f"Number of users who liked the feeds: {len(users_who_liked_feeds)}")
        for uid in users_who_liked_feeds:
            user_recs = cls.get_recommendations(trainset, uid, model, n)
            print(f"Recommendations for user {uid}: {user_recs}")
            for rec in user_recs:
                if rec not in feed_ids:  # Exclude original feeds
                    all_recommendations[rec] = all_recommendations.get(rec, 0) + 1

        # Sort feeds based on how many times they appear as recommendations
        sorted_recommendations = sorted(all_recommendations, key=all_recommendations.get, reverse=True)

        return sorted_recommendations[:n]

    @classmethod
    def recommend_feeds_for_user_nnmf(cls, model, trainset, user_id, n=10):
        try:
            # Convert user_id to inner user id used by Surprise
            user_inner_id = trainset.to_inner_uid(str(user_id))
        except ValueError:
            # If user_id is not in the training set, you cannot provide recommendations
            print(f"User {user_id} not found in the training set.")
            return []

        # Get the list of all feed ids (items) in the training set
        all_feed_ids = set([j for j in trainset.all_items()])

        # Get the list of feed ids (items) that the user has already rated
        rated_feeds = set([j for (j, _) in trainset.ur[user_inner_id]])

        # Get the list of feed ids (items) that the user has not rated yet
        unrated_feeds = all_feed_ids - rated_feeds

        # Predict the ratings for all unrated items
        predictions = [model.predict(user_inner_id, feed_id, verbose=False) for feed_id in unrated_feeds]

        # Sort predictions by estimated rating in descending order
        predictions.sort(key=lambda x: x.est, reverse=True)

        # Extract the top 'n' feed ids with highest predicted ratings
        recommended_feed_ids = [pred.iid for pred in predictions[:n]]

        print(f"Recommended {len(recommended_feed_ids)} feeds for user {user_id}:")
        return recommended_feed_ids

    @classmethod
    def recommend_similar_feeds_for_user_and_item_nnmf(cls, model, trainset, user_id, feed_ids, n=10):
        # Convert feed_ids to the proper format if it's a comma-separated string
        if isinstance(feed_ids, str):
            feed_ids = [str(fid) for fid in feed_ids.split(",")]

        users_who_liked_feeds = set()

        # Check if the given user interacted with the given feeds
        for feed_id in feed_ids:
            if model.predict(user_id, feed_id).est > 0.5:  # Assuming > 0.5 implies interaction/like
                # Collect users who interacted with these feeds
                for _, uid, _ in trainset.all_ratings():
                    if model.predict(uid, feed_id).est > 0.5:
                        users_who_liked_feeds.add(uid)

        # Predict feeds for these users
        all_recommendations = {}
        print(f"Number of users who liked the feeds: {len(users_who_liked_feeds)}")
        for uid in users_who_liked_feeds:
            user_recs = cls.get_recommendations(trainset, uid, model, n)
            print(f"Recommendations for user {uid}: {user_recs}")
            for rec in user_recs:
                if rec not in feed_ids:  # Exclude original feeds
                    all_recommendations[rec] = all_recommendations.get(rec, 0) + 1

        # Sort feeds based on how many times they appear as recommendations
        sorted_recommendations = sorted(all_recommendations, key=all_recommendations.get, reverse=True)

        return sorted_recommendations[:n]

    def recommend_similar_feeds_for_item_faiss(cls, model, trainset, feed_id, n=10):
        # Build Faiss index
        # index = cls.build_faiss_index(model)
        index = cls.build_faiss_ivfpq_index(model)
        index.nprobe = 100  # Adjust as needed

    #     # Retrieve the inner id of the feed and its embedding
    #     feed_inner_id = trainset.to_inner_iid(feed_id)
    #     feed_vector = model.qi[feed_inner_id].astype("float32").reshape(1, -1)

    #     # Use Faiss to get the most similar items
    #     _, similar_feed_inner_ids = index.search(feed_vector, n + 1)
    #     similar_feed_inner_ids = similar_feed_inner_ids[0][1:]  # Exclude the feed itself

    #     # Convert inner ids to raw ids
    #     similar_feed_ids = [trainset.to_raw_iid(int(inner_id)) for inner_id in similar_feed_inner_ids]

    #     return similar_feed_ids


class SubscriptionBasedRecommendation:
    @classmethod
    def store_user_feed_data_to_file(cls, file_name):
        if os.path.exists(file_name):
            print(f"{file_name} exists, skipping storing data...")
            return

        temp_file = open(file_name, "w+")
        users = User.objects.all().order_by("pk")
        paginator = Paginator(users, 1000)
        for page_num in paginator.page_range:
            users = paginator.page(page_num)
            for user in users:
                # Only include feeds with num_subscribers >= 5
                subs = UserSubscription.objects.filter(user=user, feed__num_subscribers__gte=5)
                # print(f"User {user} has {subs.count()} feeds")
                for sub in subs:
                    temp_file.write(f"{user.id},{sub.feed_id},1\n")
            print(f"Page {page_num} of {paginator.num_pages} saved to {file_name}")
            temp_file.flush()

    @classmethod
    def generate_user_subscription_documents(cls, file_name):
        # Create a dictionary to hold each user's subscriptions
        user_subscriptions = {}

        with open(file_name, "r") as f:
            for line in f:
                user_id, feed_id, _ = line.strip().split(",")
                if user_id not in user_subscriptions:
                    user_subscriptions[user_id] = []
                user_subscriptions[user_id].append(feed_id)

        # Convert lists to space-separated strings
        return [" ".join(feeds) for feeds in user_subscriptions.values()]

    @classmethod
    def recommend_feeds_for_user(cls, user_index, user_subscriptions, n=10):
        # Convert user subscriptions to TF-IDF matrix
        vectorizer = TfidfVectorizer()
        tfidf_matrix = vectorizer.fit_transform(user_subscriptions)

        # Compute cosine similarity between this user and all others
        cosine_similarities = linear_kernel(tfidf_matrix[user_index], tfidf_matrix).flatten()

        # Get top N similar users (excluding the user itself)
        similar_users = cosine_similarities.argsort()[-n - 2 : -1][::-1]  # -2 to exclude the user themselves

        # Gather feed IDs from similar users
        recommended_feeds = set()
        for idx in similar_users:
            recommended_feeds.update(set(user_subscriptions[idx].split()))

        # Remove feeds the user is already subscribed to
        current_user_feeds = set(user_subscriptions[user_index].split())
        recommended_feeds = recommended_feeds - current_user_feeds

        return list(recommended_feeds)

    @classmethod
    def recommend_feeds_for_feed_set(cls, feed_ids, user_subscriptions, n=10):
        # Convert the list of feed IDs to a space-separated string (similar to the format in user_subscriptions)
        user_profile = " ".join(feed_ids)

        # Convert user subscriptions + the new user profile to TF-IDF matrix
        vectorizer = TfidfVectorizer()
        tfidf_matrix = vectorizer.fit_transform(user_subscriptions + [user_profile])

        # Compute cosine similarity between this user profile and all others
        cosine_similarities = linear_kernel(
            tfidf_matrix[-1], tfidf_matrix[:-1]
        ).flatten()  # last entry is our user profile
        threshold = 0.9  # Adjust based on your data and requirements
        strongly_similar_users = [idx for idx, sim in enumerate(cosine_similarities) if sim >= threshold]

        # Get top N similar users
        similar_users = cosine_similarities.argsort()[-n:][::-1]

        # Gather feed IDs from similar users
        recommended_feeds = set()
        for idx in similar_users:
            recommended_feeds.update(set(user_subscriptions[idx].split()))

        # Remove feeds that are in the user's current profile
        recommended_feeds = recommended_feeds - set(feed_ids)

        return list(recommended_feeds)
