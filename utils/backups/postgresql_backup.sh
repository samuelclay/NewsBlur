#!/bin/sh

DB_NAME='newsblur'
date_now=`date +%Y_%m_%d_%H_%M`
file_name='backup_postgresql_'${date_now}'.pgbackup'

log() {
    echo $1
}

do_cleanup(){
    log 'cleaning up...'
    rm ${file_name}
}

do_backup(){
    log 'snapshotting the db and creating archive'
    pg_dump -U newsblur -Fc ${DB_NAME} > ${file_name}
    log 'data backed up and created snapshot'
}

save_in_s3(){
    log 'saving the psql backup archive in amazon S3' && \
    python s3.py set ${file_name} && \
    log 'data backup saved in amazon s3'
}

do_backup && save_in_s3 && do_cleanup
