#!/bin/sh

DB_NAME='newsblur'
date_now=`date +%Y_%m_%d_%H_%M`
file_name='backup_postgresql_'${date_now}'.sql.gz'

log() {
    echo $1
}

do_cleanup(){
    sudo su postgres -c "rm ~/${file_name}"
    log 'cleaning up....'
}

do_backup(){
    log 'snapshotting the db and creating archive'
    sudo su postgres -c "time pg_dump ${DB_NAME} | gzip -c > /tmp/${file_name}"
    log 'data backd up and created snapshot'
}

save_in_s3(){
    log 'saving the psql backup archive in amazon S3' && \
    cd /tmp &&
    python s3.py set ${file_name} && \
    log 'data backup saved in amazon s3'
}

do_backup && save_in_s3 && do_cleanup
