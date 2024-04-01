#!/bin/bash

# The script name
SCRIPT_NAME=$(basename "$0")

# The alias provided as an argument
ALIAS=$1

# The .ini file location
INI_FILE="ansible/inventories/hetzner.ini"

# Check if an alias is provided
if [ -z "$ALIAS" ]; then
    echo "Usage: $SCRIPT_NAME <alias>"
    exit 1
fi

# Function to extract ansible_host value
extract_host() {
    grep "$1" "$INI_FILE" | awk '{print $2}' | cut -d'=' -f2
}

# Extract the host for the given alias
HOST=$(extract_host "$ALIAS")

# Check if a host was found
if [ -z "$HOST" ]; then
    echo "Host for alias '$ALIAS' not found in $INI_FILE."
    exit 1
fi

# SSH into the host
ssh -i /srv/secrets-newsblur/keys/docker.key "nb@$HOST"
