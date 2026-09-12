#!/usr/local/bin/python3
"""
monitor_offsite_backup.py - Dead man's switch for the off-site backup pull.

utils/backups/offsite_pull.sh runs nightly on the Home Assistant box and uploads
two small markers to the S3 backup bucket: offsite_backup/started.json at the
top of every pull and offsite_backup/completed.json at the end. This script runs
daily from cron on a task server (see ansible/roles/celery_task/tasks/main.yml)
and emails the admin if either marker is stale or the newest MongoDB dump is
too old.

The alerting lives here, off the backup box, on purpose. The pull script's own
failure emails only fire when the pull runs, so a dead cron or an add-on update
that wiped the crontab (which happened silently from April to September 2026)
would never be reported by the box itself.
"""

import datetime
import json
import socket
import sys

sys.path.append("/srv/newsblur")

import boto3
import requests

from newsblur_web import settings

STARTED_KEY = "offsite_backup/started.json"
COMPLETED_KEY = "offsite_backup/completed.json"

# The pull is scheduled daily at 6am on the HA box and this check runs once a
# day, so anything over a day since the last start means a slot was missed.
MAX_HOURS_SINCE_START = 25
# Sunday's pull includes a 12+ hour MongoDB dump (24h timeout), so allow longer
# between completions before calling the pull hung.
MAX_HOURS_SINCE_COMPLETE = 36
# MongoDB dumps are weekly (Sundays); a week plus a couple of days of slack.
MAX_DAYS_SINCE_MONGO_DUMP = 9


def fetch_marker(s3, key):
    """Return (parsed JSON, LastModified) for an S3 marker, or (None, None) if missing."""
    try:
        obj = s3.get_object(Bucket=settings.S3_BACKUP_BUCKET, Key=key)
    except s3.exceptions.NoSuchKey:
        return None, None
    return json.loads(obj["Body"].read().decode("utf-8")), obj["LastModified"]


def hours_since(when):
    return (datetime.datetime.now(datetime.timezone.utc) - when).total_seconds() / 3600.0


def send_alert(hostname, problems, details):
    admin_email = settings.ADMINS[0][1]
    text = "The off-site backup pull on the Home Assistant box looks stale:\n\n"
    text += "".join("  * %s\n" % p for p in problems)
    text += "\n%s\n" % details
    text += (
        "\nCheck it with:\n"
        "  make offsite-backup-status\n"
        "  ssh root@192.168.1.27 'crontab -l; pgrep -x crond'\n"
        "\nIf the crontab is empty the SSH add-on was restarted without init_commands;\n"
        "see utils/backups/ha_configuration.yaml.\n"
    )
    requests.post(
        "https://api.mailgun.net/v2/%s/messages" % settings.MAILGUN_SERVER_NAME,
        auth=("api", settings.MAILGUN_ACCESS_KEY),
        data={
            "from": "NewsBlur Backup Monitor: %s <admin@%s.newsblur.com>" % (hostname, hostname),
            "to": [admin_email],
            "subject": "Off-site backup stale: %s" % "; ".join(problems),
            "text": text,
        },
    )


def main():
    hostname = socket.gethostname()
    s3 = boto3.client(
        "s3",
        aws_access_key_id=settings.S3_ACCESS_KEY,
        aws_secret_access_key=settings.S3_SECRET,
    )

    started, started_modified = fetch_marker(s3, STARTED_KEY)
    completed, completed_modified = fetch_marker(s3, COMPLETED_KEY)

    problems = []
    details = []

    if started_modified is None:
        problems.append("no started marker found in s3://%s/%s" % (settings.S3_BACKUP_BUCKET, STARTED_KEY))
    else:
        started_hours = hours_since(started_modified)
        details.append("Last pull started:   %s (%.1fh ago)" % (started["started_at"], started_hours))
        if started_hours > MAX_HOURS_SINCE_START:
            problems.append("no pull started in %.0f hours" % started_hours)

    if completed_modified is None:
        problems.append(
            "no completed marker found in s3://%s/%s" % (settings.S3_BACKUP_BUCKET, COMPLETED_KEY)
        )
    else:
        completed_hours = hours_since(completed_modified)
        details.append("Last pull completed: %s (%.1fh ago)" % (completed["written_at"], completed_hours))
        if completed_hours > MAX_HOURS_SINCE_COMPLETE:
            problems.append("no pull completed in %.0f hours" % completed_hours)
        if completed.get("failures"):
            details.append("Last pull reported failures: %s" % completed["failures"])

        newest_mongo = completed.get("newest_mongo_dump") or ""
        if newest_mongo:
            mongo_date = datetime.datetime.strptime(newest_mongo, "%Y-%m-%d").replace(
                tzinfo=datetime.timezone.utc
            )
            mongo_days = hours_since(mongo_date) / 24.0
            details.append("Newest MongoDB dump: %s (%.1f days old)" % (newest_mongo, mongo_days))
            if mongo_days > MAX_DAYS_SINCE_MONGO_DUMP:
                problems.append("newest MongoDB dump is %.0f days old" % mongo_days)
        else:
            problems.append("no completed MongoDB dump on the backup drive")

        verify = completed.get("verify", {}).get("results", {})
        for service, result in sorted(verify.items()):
            status = "OK" if result.get("ok") else "FAIL"
            details.append("  [%s] %s: %s" % (status, service, "; ".join(result.get("checks", []))))

    details_text = "\n".join(details)
    if problems:
        send_alert(hostname, problems, details_text)
        print(" ---> %s off-site backup STALE: %s\n%s" % (hostname, "; ".join(problems), details_text))
    else:
        print(" ---> %s off-site backup OK\n%s" % (hostname, details_text))


if __name__ == "__main__":
    main()
