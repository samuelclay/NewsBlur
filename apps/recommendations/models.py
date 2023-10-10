import tempfile
import mongoengine as mongo
from surprise import SVD
from surprise.model_selection import train_test_split
from surprise import Reader, Dataset
from django.db import models
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from utils import json_functions as json
from collections import defaultdict


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
    def store_user_feed_data_to_file(cls, file_name="user_feed_data.csv"):
        temp_file = open(file_name, "w+")
        users = User.objects.all()
        paginator = Paginator(users, 1000)
        for page_num in paginator.page_range:
            users = paginator.page(page_num)
            for user in users:
                # Only include feeds with num_subscribers >= 5
                subs = UserSubscription.objects.filter(user=user, feed__num_subscribers__gte=5)
                for sub in subs:
                    temp_file.write(f"{user.id},{sub.feed_id},1\n")
            print(f"Page {page_num} of {paginator.num_pages} saved to {file_name}")
            temp_file.flush()

    @classmethod
    def load_surprise_data(cls, file_name="user_feed_data.csv"):
        reader = Reader(line_format="user item rating", sep=",", rating_scale=(0, 1))
        data = Dataset.load_from_file(file_name, reader)

        trainset, _ = train_test_split(data, test_size=0.2)
        model = SVD()
        model.fit(trainset)

        return trainset, model

    @classmethod
    def get_recommendations(cls, trainset, user_id, model, n=10):
        # Retrieve the inner id of the user
        user_inner_id = trainset.to_inner_uid(user_id)

        # Predict ratings for all feeds
        predictions = [model.predict(user_inner_id, iid, verbose=False) for iid in trainset.all_items()]

        # Sort by highest predicted rating
        sorted_predictions = sorted(predictions, key=lambda x: x.est, reverse=True)

        # Return top n feed IDs as recommendations
        return [pred.iid for pred in sorted_predictions[:n]]
