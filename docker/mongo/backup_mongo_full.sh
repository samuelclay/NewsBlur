#!/usr/bin/env bash
# backup_mongo_full.sh - Weekly full MongoDB dump for off-site backup
# Runs on hdb-mongo-secondary-*. Dump stays on disk for the HA box to pull via rsync.
# Includes ALL collections (stories, shared_stories, starred_stories, etc.)

set -euo pipefail

BACKUP_DIR="/srv/newsblur/docker/volumes/mongo/backup"
now=$(date '+%Y-%m-%d-%H-%M')
DUMP_NAME="mongodump_full_${now}"

echo "$(date -u) ---> Starting full mongodump to ${BACKUP_DIR}/${DUMP_NAME}"

# Full mongodump with gzip compression, all collections
docker exec -t mongo mongodump -d newsblur --gzip -o "/backup/${DUMP_NAME}"

echo "$(date -u) ---> Full mongodump complete"

# Clean up old full dumps, keep only the 2 most recent
cd "${BACKUP_DIR}"
OLD_DUMPS=$(ls -dt mongodump_full_* 2>/dev/null | tail -n +3)
if [ -n "${OLD_DUMPS}" ]; then
    echo "${OLD_DUMPS}" | while read dir; do
        echo "$(date -u) ---> Removing old dump: ${dir}"
        rm -rf "${dir}"
    done
fi

# Write marker file for the off-site pull script
echo "${now}" > "${BACKUP_DIR}/latest_full_dump.txt"

echo "$(date -u) ---> Current full dumps:"
ls -la "${BACKUP_DIR}"/mongodump_full_* 2>/dev/null || echo "  (none)"
echo "$(date -u) ---> Finished full mongodump"
