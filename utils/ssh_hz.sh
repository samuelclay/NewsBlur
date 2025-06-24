#!/bin/bash

# The script name
SCRIPT_NAME=$(basename "$0")

# Parse arguments
NONINTERACTIVE=false
ALIAS=""
COMMAND=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--noninteractive)
            NONINTERACTIVE=true
            shift
            ;;
        *)
            if [ -z "$ALIAS" ]; then
                ALIAS=$1
            else
                # Everything after the alias is the command
                COMMAND="${@:1}"
                break
            fi
            shift
            ;;
    esac
done

# The .ini file location
INI_FILE="ansible/inventories/hetzner.ini"

# Check if an alias is provided
if [ -z "$ALIAS" ]; then
    echo "Usage: $SCRIPT_NAME [-n|--noninteractive] <alias> [command]"
    echo "  -n, --noninteractive  Run in non-interactive mode"
    echo "  alias                 Server alias from hetzner.ini"
    echo "  command               Command to execute (only in non-interactive mode)"
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
if [ "$NONINTERACTIVE" = true ]; then
    # Non-interactive mode with command
    if [ -z "$COMMAND" ]; then
        echo "Error: Command required in non-interactive mode"
        exit 1
    fi
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /srv/secrets-newsblur/keys/docker.key "nb@$HOST" "$COMMAND"
else
    # Interactive mode
    ssh -i /srv/secrets-newsblur/keys/docker.key "nb@$HOST"
fi
