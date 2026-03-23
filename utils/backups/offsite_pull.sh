#!/usr/bin/env bash
# offsite_pull.sh - Pull NewsBlur backups to Home Assistant box
#
# Runs on the HA box (HAOS). Pulls:
# - MongoDB full dump: streamed directly via SSH (mongodump --archive --gzip)
# - PostgreSQL + Redis: download latest from S3 (small files)
#
# Each section runs independently — a failure in one (e.g. broken venv)
# does not prevent the others from completing.
#
# Usage: ./offsite_pull.sh

set -uo pipefail  # No -e: sections handle errors independently

# --- Configuration ---
BACKUP_DRIVE="/media/newsblur-backup"
SSH_KEY="/config/scripts/docker.key"
SSH_USER="nb"
MONGO_DUMP_TIMEOUT="24h"  # Kill mongodump if it takes longer than this
MAILGUN_CREDS_FILE="/config/scripts/mailgun_credentials"
VENV_PYTHON="/config/scripts/venv/bin/python3"

# Hetzner server IPs (from ansible/inventories/hetzner.ini)
MONGO_SECONDARY="37.27.129.218"  # hdb-mongo-secondary-1

# S3 configuration — credentials loaded from config file
S3_BUCKET="newsblur-backups"
AWS_CREDS_FILE="/config/scripts/aws_s3_credentials"
AWS_ACCESS_KEY_ID=""
AWS_SECRET_ACCESS_KEY=""
S3_AVAILABLE=true
if [[ -f "${AWS_CREDS_FILE}" ]]; then
    # File format: line 1 = access key, line 2 = secret key
    AWS_ACCESS_KEY_ID=$(sed -n '1p' "${AWS_CREDS_FILE}")
    AWS_SECRET_ACCESS_KEY=$(sed -n '2p' "${AWS_CREDS_FILE}")
else
    S3_AVAILABLE=false
fi

if [[ ! -x "${VENV_PYTHON}" ]]; then
    S3_AVAILABLE=false
fi

# S3 prefixes for each backup type (hostname with underscores)
# Postgres backs up from the secondary (physical hostname: hdb-redis-secondary)
S3_POSTGRES_PREFIXES=(
    "backup_hdb_postgres_secondary/backup_postgresql"
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

LOG_FILE="${BACKUP_DRIVE}/backup.log"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i ${SSH_KEY}"
FAILURES=""  # Track failed sections for final summary

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "${LOG_FILE}"
}

send_failure_alert() {
    local subject="$1"
    local body="$2"
    log "Sending failure alert: ${subject}"
    if [[ ! -f "${MAILGUN_CREDS_FILE}" ]]; then
        log "  WARNING: Mailgun credentials not found, cannot send alert"
        return
    fi
    local api_key domain
    api_key=$(sed -n '1p' "${MAILGUN_CREDS_FILE}")
    domain=$(sed -n '2p' "${MAILGUN_CREDS_FILE}")
    if [[ -z "${api_key}" || -z "${domain}" ]]; then
        log "  WARNING: Could not read Mailgun credentials"
        return
    fi
    if curl -s --max-time 30 \
        -u "api:${api_key}" \
        "https://api.mailgun.net/v3/${domain}/messages" \
        -F from="NewsBlur Backup <admin@${domain}>" \
        -F to="samuel@newsblur.com" \
        -F subject="NewsBlur Backup FAILED: ${subject}" \
        -F text="${body}" \
        > /dev/null 2>&1; then
        log "  Alert email sent to samuel@newsblur.com"
    else
        log "  WARNING: Failed to send alert email"
    fi
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

# --- 1. PostgreSQL + Redis (download from S3) ---
# Done first since they're fast; mongo dump takes 12+ hours.
# Uses python (from venv with boto3) to find and download the latest backup.

s3_download_latest() {
    local prefix="$1"
    local local_dir="$2"

    "${VENV_PYTHON}" -c "
import boto3, os, sys, json, time

s3 = boto3.client('s3',
    aws_access_key_id='${AWS_ACCESS_KEY_ID}',
    aws_secret_access_key='${AWS_SECRET_ACCESS_KEY}')

prefix = '${prefix}'
bucket = '${S3_BUCKET}'
local_dir = '${local_dir}'
progress_file = '${BACKUP_DRIVE}/download_progress.json'

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

total_size = latest['Size']
size_mb = total_size / 1024 / 1024
print('Downloading: %s (%.1f MB)' % (filename, size_mb))

# Download to .partial with progress tracking
local_partial = local_path + '.partial'
start_time = time.time()
downloaded = [0]
last_write = [0.0]

def progress_callback(bytes_amount):
    downloaded[0] += bytes_amount
    now = time.time()
    if now - last_write[0] >= 2:
        last_write[0] = now
        try:
            with open(progress_file, 'w') as f:
                json.dump({
                    'file': filename,
                    'local_dir': local_dir,
                    'total_bytes': total_size,
                    'downloaded_bytes': downloaded[0],
                    'start_time': start_time
                }, f)
        except Exception:
            pass

s3.download_file(bucket, key, local_partial, Callback=progress_callback)
os.rename(local_partial, local_path)

try:
    os.remove(progress_file)
except Exception:
    pass

print('Downloaded: %s' % local_path)
" 2>&1
}

if [[ "${S3_AVAILABLE}" == "true" ]]; then
    log "--- PostgreSQL backup from S3 ---"
    for pg_prefix in "${S3_POSTGRES_PREFIXES[@]}"; do
        if ! s3_download_latest "${pg_prefix}" "${BACKUP_DRIVE}/postgres" | while read line; do log "  $line"; done; then
            log "  WARNING: PostgreSQL download failed for prefix ${pg_prefix}"
            FAILURES="${FAILURES}PostgreSQL S3; "
        fi
    done

    log "--- Redis backups from S3 ---"
    for redis_prefix in "${S3_REDIS_PREFIXES[@]}"; do
        redis_name=$(echo "${redis_prefix}" | cut -d/ -f1)
        mkdir -p "${BACKUP_DRIVE}/redis/${redis_name}"
        if ! s3_download_latest "${redis_prefix}" "${BACKUP_DRIVE}/redis/${redis_name}" | while read line; do log "  $line"; done; then
            log "  WARNING: Redis download failed for prefix ${redis_prefix}"
            FAILURES="${FAILURES}Redis S3; "
        fi
    done
else
    log "--- Skipping S3 downloads ---"
    if [[ ! -x "${VENV_PYTHON}" ]]; then
        log "  Python venv not found at ${VENV_PYTHON}"
    fi
    if [[ ! -f "${AWS_CREDS_FILE}" ]]; then
        log "  AWS credentials not found at ${AWS_CREDS_FILE}"
    fi
    FAILURES="${FAILURES}S3 downloads (prerequisites unavailable); "
fi

# --- 2. Full MongoDB Dump (stream directly via SSH) ---
# Streams mongodump --archive --gzip over SSH directly to the backup drive.
# Uses zero disk space on the mongo server. Takes 12+ hours.
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
    log "Streaming full mongodump from ${MONGO_SECONDARY} (timeout: ${MONGO_DUMP_TIMEOUT})..."
    # Write to .partial first, rename on success to avoid keeping truncated dumps
    # mongodump progress (stderr) flows through to the caller's stderr (backup_run.log via nohup)
    #
    # timeout returns 124 on timeout, or the command's exit code on other failures.
    if timeout "${MONGO_DUMP_TIMEOUT}" \
        ssh ${SSH_OPTS} ${SSH_USER}@${MONGO_SECONDARY} \
            "docker exec mongo mongodump -d newsblur --gzip --archive" \
            > "${DUMP_TMP}"; then
        mv "${DUMP_TMP}" "${DUMP_FILE}"
        DUMP_SIZE=$(du -sh "${DUMP_FILE}" | cut -f1)
        log "MongoDB dump complete: $(basename ${DUMP_FILE}) (${DUMP_SIZE})"
    else
        EXIT_CODE=$?
        rm -f "${DUMP_TMP}"
        if [[ ${EXIT_CODE} -eq 124 ]]; then
            log "ERROR: MongoDB dump TIMED OUT after ${MONGO_DUMP_TIMEOUT}"
            FAILURES="${FAILURES}MongoDB (timeout); "
            send_failure_alert \
                "MongoDB dump timed out" \
                "MongoDB dump timed out after ${MONGO_DUMP_TIMEOUT} on $(date '+%Y-%m-%d %H:%M').

The mongodump stream from ${MONGO_SECONDARY} did not complete within the allowed time.
The partial file has been removed. The next nightly run will retry automatically."
        else
            log "ERROR: MongoDB dump FAILED with exit code ${EXIT_CODE}"
            FAILURES="${FAILURES}MongoDB (exit ${EXIT_CODE}); "
            send_failure_alert \
                "MongoDB dump failed (exit ${EXIT_CODE})" \
                "MongoDB dump failed with exit code ${EXIT_CODE} on $(date '+%Y-%m-%d %H:%M').

The SSH stream from ${MONGO_SECONDARY} exited unexpectedly.
The partial file has been removed. The next nightly run will retry automatically."
        fi
    fi
fi

# --- 3. Local Retention Cleanup ---
log "--- Running local retention cleanup ---"

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
    REDIS_FILES=$(ls -t *.rdb *.rdb.gz 2>/dev/null || true)
    REDIS_COUNT=$(echo "${REDIS_FILES}" | grep -c ".rdb" 2>/dev/null || true)
    if [[ ${REDIS_COUNT} -gt ${REDIS_KEEP} ]]; then
        echo "${REDIS_FILES}" | tail -n +$((REDIS_KEEP + 1)) | while read f; do
            log "  Removing old redis backup: $(basename ${redis_dir})/${f}"
            rm -f "${f}"
        done
    fi
done

# --- 4. Verify backup integrity ---
if [[ -x "${VENV_PYTHON}" ]]; then
    log "--- Verifying backup integrity ---"
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if ! "${VENV_PYTHON}" "${SCRIPT_DIR}/offsite_verify.py" 2>&1 | while read line; do log "  $line"; done; then
        log "  WARNING: Verification reported failures"
        FAILURES="${FAILURES}verification; "
    fi
else
    log "--- Skipping verification (no Python venv) ---"
    FAILURES="${FAILURES}verification (no venv); "
fi

# --- 5. Summary ---
log "=== Backup pull complete ==="
log "Disk usage:"
du -sh "${BACKUP_DRIVE}/mongo_full" "${BACKUP_DRIVE}/postgres" "${BACKUP_DRIVE}/redis" 2>/dev/null | while read line; do log "  $line"; done
df -h "${BACKUP_DRIVE}" | tail -1 | while read line; do log "  $line"; done

if [[ -n "${FAILURES}" ]]; then
    log "WARNING: Some sections had issues: ${FAILURES}"
    send_failure_alert \
        "Backup partially failed" \
        "NewsBlur off-site backup on $(date '+%Y-%m-%d %H:%M') completed with issues:

${FAILURES}

Check the backup log for details:
  ssh root@192.168.1.27 'tail -50 /media/newsblur-backup/backup.log'"
fi

# --- 6. Unmount backup drive ---
# Unmount so the drive can spin down and rest between backups.
# Without this, HA's filesystem monitoring keeps the drive spinning 24/7.
log "Unmounting backup drive..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"${SCRIPT_DIR}/unmount_backup_drive.sh" 2>&1 | while read line; do log "  $line"; done
