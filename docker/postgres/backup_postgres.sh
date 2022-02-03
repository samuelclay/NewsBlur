#!/usr/bin/env bash

now=$(date '+%Y-%m-%d-%H-%M')

echo "---> PG dumping - ${now}"
BACKUP_FILE="/srv/newsblur/backups/backup_postgresql_${now}.sql"
sudo docker exec -it postgres /usr/lib/postgresql/13/bin/pg_dump -U newsblur -h 127.0.0.1 -Fc newsblur > $BACKUP_FILE

echo " ---> Compressing $BACKUP_FILE"
gzip $BACKUP_FILE

echo " ---> Uploading postgres backup to S3"
sudo docker run --user 1000:1001 --rm \
    -v /srv/newsblur:/srv/newsblur \
    -v /srv/newsblur/backups/:/srv/newsblur/backups/ \
    --network=host \
    newsblur/newsblur_python3 \
    python /srv/newsblur/utils/backups/backup_psql.py

# Don't delete backup since the backup_mongo.py script will rm them
## rm /opt/mongo/newsblur/backup/backup_mongo_${now}.tgz
## rm /opt/mongo/newsblur/backup/backup_mongo_${now}
echo " ---> Finished uploading backups to S3: "
