#!/bin/sh

MONGODB_SHELL='mongo'
DUMP_UTILITY='mongodump'
DB_NAME='newsblur'
COLLECTIONS="classifier_tag classifier_author classifier_feed classifier_title userstories"

date_now=`date +%Y_%m_%d_%H_%M`
dir_name='backup_mongo_'${date_now}
file_name='backup_mongo_'${date_now}'.bz2'

log() {
    echo $1
}

do_cleanup(){
    rm -rf backup_mongo_* 
    log 'cleaning up....'
}

do_backup(){
    log 'snapshotting the db and creating archive'
    # ${MONGODB_SHELL} admin fsync_lock.js
    for collection in $COLLECTIONS
    do
        ${DUMP_UTILITY} --db ${DB_NAME} --collection $collection -o ${dir_name}
    done
    tar -jcf $file_name ${dir_name}
    # ${MONGODB_SHELL} admin fsync_unlock.js
    log 'data backd up and created snapshot'
}

save_in_s3(){
    log 'saving the backup archive in amazon S3' && \
    python s3.py set ${file_name} && \
    log 'data backup saved in amazon s3'
}

do_backup && save_in_s3 && do_cleanup
