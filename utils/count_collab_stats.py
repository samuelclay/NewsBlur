import argparse
import csv
import math
from collections import defaultdict


def calculate_statistics(ratings):
    min_rating = min(ratings)
    max_rating = max(ratings)
    avg_rating = sum(ratings) / len(ratings)

    # Standard deviation
    variance = sum((x - avg_rating) ** 2 for x in ratings) / len(ratings)
    std_dev = math.sqrt(variance)

    # Median
    sorted_ratings = sorted(ratings)
    mid = len(sorted_ratings) // 2
    median = (sorted_ratings[mid] + sorted_ratings[~mid]) / 2

    return min_rating, max_rating, avg_rating, std_dev, median


def process_file(path):
    user_feeds = defaultdict(set)  # Stores feeds rated by each user
    feed_users = defaultdict(set)  # Stores users who have rated each feed
    ratings = []

    with open(path, newline="") as csvfile:
        reader = csv.reader(csvfile)
        for row in reader:
            user, feed, rating = row
            user_feeds[user].add(feed)
            feed_users[feed].add(user)
            ratings.append(float(rating))

    # Overlap statistics
    avg_user_overlap = sum(len(feeds) for feeds in user_feeds.values()) / len(user_feeds)
    avg_feed_overlap = sum(len(users) for users in feed_users.values()) / len(feed_users)

    unique_users = len(user_feeds)
    unique_feeds = len(feed_users)
    min_rating, max_rating, avg_rating, std_dev, median = calculate_statistics(ratings)

    return (
        unique_users,
        unique_feeds,
        avg_user_overlap,
        avg_feed_overlap,
        min_rating,
        max_rating,
        avg_rating,
        std_dev,
        median,
    )


def main():
    parser = argparse.ArgumentParser(description="Process a CSV file with <user,feed,rating> data.")
    parser.add_argument("path", type=str, help="Path to the CSV file")

    args = parser.parse_args()
    path = args.path

    (
        unique_users,
        unique_feeds,
        avg_user_overlap,
        avg_feed_overlap,
        min_rating,
        max_rating,
        avg_rating,
        std_dev,
        median,
    ) = process_file(path)
    print(f"Unique Users: {unique_users}")
    print(f"Unique Feeds: {unique_feeds}")
    print(f"Average Feeds per User: {avg_user_overlap:.2f}")
    print(f"Average Users per Feed: {avg_feed_overlap:.2f}")
    print(
        f"Rating Stats - Min: {min_rating}, Max: {max_rating}, Average: {avg_rating:.2f}, Std Dev: {std_dev:.2f}, Median: {median}"
    )


if __name__ == "__main__":
    main()
