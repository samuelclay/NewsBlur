#!/usr/bin/env bash
# setup_cron.sh - Prepare the SSH add-on for NewsBlur backups on every start
#
# Runs on SSH add-on startup via init_commands in the add-on config (see
# ensure_addon_init_commands below), and from `make offsite-backup-install`.
#
# Everything here lives inside the add-on container and is lost on every add-on
# update or host reboot, so it has to be redone on each start:
#   1. The crontab entry and crond itself (the container's crontab is ephemeral).
#   2. The Python venv, whenever the add-on ships a new Python version: the venv
#      symlinks /usr/bin/python3 but its site-packages are pinned to the old
#      minor version, so boto3 silently vanishes (3.12 -> 3.14 broke it in 2026).
# Backups silently stopped from April to September 2026 because init_commands
# was never set and an add-on auto-update wiped the crontab.

SCRIPTS_DIR="/config/scripts"
VENV_DIR="${SCRIPTS_DIR}/venv"
CRON_ENTRY='0 6 * * * /config/scripts/mount_backup_drive.sh && /config/scripts/offsite_pull.sh >> /media/newsblur-backup/backup_run.log 2>&1; /config/scripts/unmount_backup_drive.sh >> /media/newsblur-backup/backup_run.log 2>&1'

# --- 1. Cron ---
# Remove any existing offsite_pull entry, then add the current one
(crontab -l 2>/dev/null | grep -v offsite_pull; echo "${CRON_ENTRY}") | crontab -
echo "NewsBlur backup cron job installed (daily 6:00 AM)"

# Start crond if not already running (HAOS SSH add-on doesn't start it by default)
if ! pgrep -x crond > /dev/null 2>&1; then
    crond
    echo "crond started"
else
    echo "crond already running"
fi

# --- 2. Python venv (boto3 for S3, requests) ---
# Rebuild from scratch if it's missing or its packages no longer import under
# the add-on's current Python.
if "${VENV_DIR}/bin/python3" -c "import boto3, requests" > /dev/null 2>&1; then
    echo "Python venv OK ($("${VENV_DIR}/bin/python3" --version 2>&1))"
else
    echo "Python venv missing or broken (add-on Python is $(python3 --version 2>&1)), rebuilding..."
    rm -rf "${VENV_DIR}"
    if python3 -m venv "${VENV_DIR}" && "${VENV_DIR}/bin/pip" install --quiet boto3 requests; then
        echo "Python venv rebuilt ($("${VENV_DIR}/bin/python3" --version 2>&1))"
    else
        echo "WARNING: Python venv rebuild failed; S3 downloads, verification and heartbeats will be skipped"
    fi
fi

# --- 3. Make sure this script runs on every add-on start ---
# The add-on's init_commands option is what re-runs this script after an add-on
# update or reboot. The `ha` CLI has no way to set add-on options, so talk to the
# Supervisor API directly (SUPERVISOR_TOKEN is provided to the add-on). The API
# replaces the whole options object, so the current options are fetched first
# and only init_commands is changed.
ensure_addon_init_commands() {
    if [[ -z "${SUPERVISOR_TOKEN:-}" ]]; then
        echo "WARNING: SUPERVISOR_TOKEN not set; cannot verify add-on init_commands"
        return
    fi
    python3 - "${SCRIPTS_DIR}/setup_cron.sh" <<'PY'
import json, os, sys, urllib.request

script = sys.argv[1]
headers = {"Authorization": "Bearer " + os.environ["SUPERVISOR_TOKEN"], "Content-Type": "application/json"}

def api(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request("http://supervisor" + path, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())

try:
    options = api("GET", "/addons/self/info")["data"]["options"]
    if script in options.get("init_commands", []):
        print("Add-on init_commands already runs %s" % script)
    else:
        options["init_commands"] = list(options.get("init_commands", [])) + [script]
        result = api("POST", "/addons/self/options", {"options": options})
        print("Add-on init_commands updated to run %s on start (%s)" % (script, result.get("result")))
except Exception as e:
    print("WARNING: could not verify add-on init_commands: %s" % e)
PY
}
ensure_addon_init_commands
