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
    # uploaded_opml
    user_search
)

if [ "$1" = "stories" ]; then
    collections+=(
        shared_stories
        starred_stories        
    )
fi

now=$(date '+%Y-%m-%d-%H-%M')

for collection in ${collections[@]}; do
    echo "---> Dumping $collection - ${now}"

    docker exec -it mongo mongodump -d newsblur -c $collection -o /backup
done;

echo " ---> Compressing /srv/newsblur/backup/newsblur into /srv/newsblur/backup/backup_mongo_${now}.tgz"
tar -zcf /srv/newsblur/backup/backup_mongo_${now}.tgz -C / srv/newsblur/backup/newsblur

echo " ---> Uploading backups to S3"
docker run --user 1000:1001 --rm -v /srv/newsblur:/srv/newsblur -v /srv/newsblur/backup/:/srv/newsblur/backup/ --network=host newsblur/newsblur_python3:latest python /srv/newsblur/utils/backups/backup_mongo.py

# Don't delete backup since the backup_mongo.py script will rm them
## rm /opt/mongo/newsblur/backup/backup_mongo_${now}.tgz
## rm /opt/mongo/newsblur/backup/backup_mongo_${now}
echo " ---> Finished uploading backups to S3: backup_mongo.tgz"
