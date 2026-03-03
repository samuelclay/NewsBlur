#!/usr/bin/env bash
# offsite_pull.sh - Pull NewsBlur backups to Home Assistant box
#
# Runs on the HA box (HAOS). Pulls:
# - MongoDB full dump: streamed directly via SSH (mongodump --archive --gzip)
# - PostgreSQL + Redis: download latest from S3 (small files)
#
# Usage: ./offsite_pull.sh [--dry-run]

set -euo pipefail

# --- Configuration ---
BACKUP_DRIVE="/media/newsblur-backup"
SSH_KEY="/config/scripts/docker.key"
SSH_USER="nb"

# Hetzner server IPs (from ansible/inventories/hetzner.ini)
MONGO_SECONDARY="37.27.129.218"  # hdb-mongo-secondary-1

# S3 configuration — credentials loaded from config file
S3_BUCKET="newsblur-backups"
AWS_CREDS_FILE="/config/scripts/aws_s3_credentials"
if [[ -f "${AWS_CREDS_FILE}" ]]; then
    # File format: line 1 = access key, line 2 = secret key
    AWS_ACCESS_KEY_ID=$(sed -n '1p' "${AWS_CREDS_FILE}")
    AWS_SECRET_ACCESS_KEY=$(sed -n '2p' "${AWS_CREDS_FILE}")
else
    echo "ERROR: AWS credentials file not found at ${AWS_CREDS_FILE}"
    echo "Create it with: echo 'ACCESS_KEY' > ${AWS_CREDS_FILE} && echo 'SECRET_KEY' >> ${AWS_CREDS_FILE}"
    exit 1
fi

# S3 prefixes for each backup type (hostname with underscores)
# Postgres backs up from the secondary (physical hostname: hdb-redis-secondary)
S3_POSTGRES_PREFIXES=(
    "backup_hdb_redis_secondary/backup_postgresql"
    "backup_hdb_postgres_1/backup_postgresql"
)
# Redis: replica (-2) backups
S3_REDIS_PREFIXES=(
    "backup_hdb_redis_story_2/backup_hdb_redis_story_2"
    "backup_hdb_redis_user_2/backup_hdb_redis_user_2"
    "backup_hdb_redis_session_2/backup_hdb_redis_session_2"
)

# Local retention: how many backups to keep per type
MONGO_FULL_KEEP=7
POSTGRES_KEEP=8
REDIS_KEEP=8

# --- End Configuration ---

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

LOG_FILE="${BACKUP_DRIVE}/backup.log"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i ${SSH_KEY}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "${LOG_FILE}"
}

# Check that backup drive is mounted
if [[ ! -d "${BACKUP_DRIVE}" ]]; then
    echo "ERROR: Backup drive not mounted at ${BACKUP_DRIVE}"
    echo "Run: shell_command.mount_backup_drive from HA"
    exit 1
fi

# Create directory structure
mkdir -p "${BACKUP_DRIVE}/mongo_full"
mkdir -p "${BACKUP_DRIVE}/postgres"
mkdir -p "${BACKUP_DRIVE}/redis"

log "=== Starting NewsBlur off-site backup pull ==="

# --- 1. Full MongoDB Dump (stream directly via SSH) ---
# Streams mongodump --archive --gzip over SSH directly to the backup drive.
# Uses zero disk space on the mongo server.
# NOTE: No -t flag on docker exec — TTY mangles binary streams.
log "--- MongoDB full dump (streaming from server) ---"

DUMP_DATE=$(date '+%Y-%m-%d')
DUMP_FILE="${BACKUP_DRIVE}/mongo_full/mongodump_full_${DUMP_DATE}.gz"
DUMP_TMP="${DUMP_FILE}.partial"

if [[ -f "${DUMP_FILE}" ]]; then
    log "MongoDB dump already exists for today: $(basename ${DUMP_FILE}). Skipping."
elif [[ -f "${DUMP_TMP}" ]]; then
    log "MongoDB dump already in progress: $(basename ${DUMP_TMP}). Skipping."
else
    log "Streaming full mongodump from ${MONGO_SECONDARY}..."
    if [[ "${DRY_RUN}" == "false" ]]; then
        # Write to .partial first, rename on success to avoid keeping truncated dumps
        ssh ${SSH_OPTS} ${SSH_USER}@${MONGO_SECONDARY} \
            "docker exec mongo mongodump -d newsblur --gzip --archive" \
            > "${DUMP_TMP}"
        mv "${DUMP_TMP}" "${DUMP_FILE}"
        DUMP_SIZE=$(du -sh "${DUMP_FILE}" | cut -f1)
        log "MongoDB dump complete: $(basename ${DUMP_FILE}) (${DUMP_SIZE})"
    else
        log "[DRY RUN] Would stream mongodump to ${DUMP_FILE}"
    fi
fi

# --- 2. PostgreSQL + Redis (download from S3) ---
# Uses python (from venv with boto3) to find and download the latest backup.

s3_download_latest() {
    local prefix="$1"
    local local_dir="$2"

    /config/scripts/venv/bin/python3 -c "
import boto3, os, sys

s3 = boto3.client('s3',
    aws_access_key_id='${AWS_ACCESS_KEY_ID}',
    aws_secret_access_key='${AWS_SECRET_ACCESS_KEY}')

prefix = '${prefix}'
bucket = '${S3_BUCKET}'
local_dir = '${local_dir}'

# List objects with this prefix
paginator = s3.get_paginator('list_objects_v2')
objects = []
for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
    for obj in page.get('Contents', []):
        objects.append(obj)

if not objects:
    print('No backups found for prefix: %s' % prefix)
    sys.exit(0)

# Sort by LastModified, get the most recent
objects.sort(key=lambda x: x['LastModified'], reverse=True)
latest = objects[0]
key = latest['Key']
filename = key.split('/')[-1]
local_path = os.path.join(local_dir, filename)

if os.path.exists(local_path):
    print('Already downloaded: %s' % filename)
    sys.exit(0)

size_mb = latest['Size'] / 1024 / 1024
print('Downloading: %s (%.1f MB)' % (filename, size_mb))

if '${DRY_RUN}' == 'true':
    print('[DRY RUN] Would download %s' % key)
    sys.exit(0)

s3.download_file(bucket, key, local_path)
print('Downloaded: %s' % local_path)
" 2>&1
}

log "--- PostgreSQL backup from S3 ---"
for pg_prefix in "${S3_POSTGRES_PREFIXES[@]}"; do
    s3_download_latest "${pg_prefix}" "${BACKUP_DRIVE}/postgres" | while read line; do log "  $line"; done
done

log "--- Redis backups from S3 ---"
for redis_prefix in "${S3_REDIS_PREFIXES[@]}"; do
    redis_name=$(echo "${redis_prefix}" | cut -d/ -f1)
    mkdir -p "${BACKUP_DRIVE}/redis/${redis_name}"
    s3_download_latest "${redis_prefix}" "${BACKUP_DRIVE}/redis/${redis_name}" | while read line; do log "  $line"; done
done

# --- 3. Local Retention Cleanup ---
log "--- Running local retention cleanup ---"

if [[ "${DRY_RUN}" == "false" ]]; then
    # Mongo full dumps: keep N most recent files
    cd "${BACKUP_DRIVE}/mongo_full"
    MONGO_FILES=$(ls -t mongodump_full_*.gz 2>/dev/null || true)
    MONGO_COUNT=$(echo "${MONGO_FILES}" | grep -c "mongodump_full_" 2>/dev/null || true)
    if [[ ${MONGO_COUNT} -gt ${MONGO_FULL_KEEP} ]]; then
        echo "${MONGO_FILES}" | tail -n +$((MONGO_FULL_KEEP + 1)) | while read f; do
            log "  Removing old mongo dump: ${f}"
            rm -f "${f}"
        done
    fi
    # Clean up stale .partial files older than 24h (failed dumps, not in-progress)
    find "${BACKUP_DRIVE}/mongo_full/" -name "*.partial" -mmin +1440 -delete 2>/dev/null || true

    # Postgres dumps: keep N most recent files
    cd "${BACKUP_DRIVE}/postgres"
    PG_FILES=$(ls -t backup_postgresql_*.sql 2>/dev/null || true)
    PG_COUNT=$(echo "${PG_FILES}" | grep -c "backup_postgresql_" 2>/dev/null || true)
    if [[ ${PG_COUNT} -gt ${POSTGRES_KEEP} ]]; then
        echo "${PG_FILES}" | tail -n +$((POSTGRES_KEEP + 1)) | while read f; do
            log "  Removing old postgres backup: ${f}"
            rm -f "${f}"
        done
    fi

    # Redis dumps: keep N most recent per instance
    for redis_dir in "${BACKUP_DRIVE}"/redis/backup_hdb_redis_*/; do
        if [[ ! -d "${redis_dir}" ]]; then continue; fi
        cd "${redis_dir}"
        REDIS_FILES=$(ls -t *.rdb.gz 2>/dev/null || true)
        REDIS_COUNT=$(echo "${REDIS_FILES}" | grep -c ".rdb.gz" 2>/dev/null || true)
        if [[ ${REDIS_COUNT} -gt ${REDIS_KEEP} ]]; then
            echo "${REDIS_FILES}" | tail -n +$((REDIS_KEEP + 1)) | while read f; do
                log "  Removing old redis backup: $(basename ${redis_dir})/${f}"
                rm -f "${f}"
            done
        fi
    done
fi

# --- 4. Summary ---
log "=== Backup pull complete ==="
log "Disk usage:"
du -sh "${BACKUP_DRIVE}/mongo_full" "${BACKUP_DRIVE}/postgres" "${BACKUP_DRIVE}/redis" 2>/dev/null | while read line; do log "  $line"; done
df -h "${BACKUP_DRIVE}" | tail -1 | while read line; do log "  $line"; done
