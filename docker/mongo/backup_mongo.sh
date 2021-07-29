#!/usr/bin/env bash

collections=(
    classifier_tag
    classifier_author
    classifier_feed
    classifier_title
    # shared_stories
    category
    category_site
    sent_emails
    social_profile
    social_subscription
    social_services
    statistics
    user_search
    feedback
)

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
