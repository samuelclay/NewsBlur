#!/usr/bin/env bash

collections=(
    activities
    category
    category_site
    classifier_author
    classifier_feed
    classifier_tag
    classifier_title
    custom_styling
    dashboard_river
    # feed_icons
    # feed_pages
    feedback
    # fetch_exception_history
    # fetch_history
    follow_request
    gift_codes
    inline
    interactions
    m_dashboard_river
    notification_tokens
    notifications
    popularity_query
    redeemed_codes
    saved_searches
    sent_emails
    # shared_stories
    social_invites
    social_profile
    social_services
    social_subscription
    # starred_stories
    starred_stories_counts
    statistics
    # stories
    system.profile
    system.users
    uploaded_opml
    user_search
)

if [$1 == "stories"]; then
    collections +=(
        shared_stories
        starred_stories        
    )
fi

for collection in ${collections[@]}; do
    now=$(date '+%Y-%m-%d-%H-%M')
    echo "---> Dumping $collection - ${now}"

    docker exec -it mongo mongodump -d newsblur -c $collection -o /backup/backup_mongo
done;

echo " ---> Compressing backup_mongo.tgz"
tar -zcf /opt/mongo/newsblur/backup/backup_mongo.tgz /opt/mongo/newsblur/backup/backup_mongo

echo " ---> Uploading backups to S3"
docker run --rm -v /srv/newsblur:/srv/newsblur -v /opt/mongo/newsblur/backup/:/opt/mongo/newsblur/backup/ --network=newsblurnet newsblur/newsblur_python3:latest python /srv/newsblur/utils/backups/backup_mongo.py

# Don't delete backup since the backup_mongo.py script will rm them
## rm /opt/mongo/newsblur/backup/backup_mongo_${now}.tgz
## rm /opt/mongo/newsblur/backup/backup_mongo_${now}
echo " ---> Finished uploading backups to S3: backup_mongo.tgz"
