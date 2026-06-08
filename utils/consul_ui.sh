#!/bin/bash
#
# consul_ui.sh - Open the Consul web UI over an SSH tunnel.
#
# The Consul HTTP API (port 8500) is firewalled off the public internet (servers)
# and bound to loopback (clients), so there is no public UI and no IP allowlisting.
# This opens an SSH tunnel from your machine to a consul server's loopback 8500 and
# points your browser at it. Works from anywhere you hold the SSH key, no matter
# what your current IP is.
#
# Usage:
#   ./utils/consul_ui.sh            # tunnel to the default consul server
#   ./utils/consul_ui.sh <server>   # tunnel to a specific server alias from hetzner.ini
#
# Then open: http://localhost:8500
# Press Ctrl-C to close the tunnel.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INI_FILE="$SCRIPT_DIR/../ansible/inventories/hetzner.ini"
KEY="/srv/secrets-newsblur/keys/docker.key"
LOCAL_PORT="${LOCAL_PORT:-8500}"
ALIAS="${1:-hdb-consul-1}"

# Resolve the server alias to its ansible_host IP from the inventory
HOST=$(grep "^$ALIAS[[:space:]]" "$INI_FILE" | grep -v "^[;#]" | awk '{print $2}' | cut -d'=' -f2)
if [ -z "$HOST" ]; then
    echo "Server alias '$ALIAS' not found in $INI_FILE" >&2
    exit 1
fi

echo "Tunneling http://localhost:$LOCAL_PORT  ->  $ALIAS ($HOST) 127.0.0.1:8500"
echo "Open http://localhost:$LOCAL_PORT in your browser. Ctrl-C to close."

# -N: no remote command, just forward. The tunnel target is the server's loopback,
# which is where Consul listens, so this works even though 8500 is firewalled.
exec ssh -i "$KEY" \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    -N -L "$LOCAL_PORT:127.0.0.1:8500" "nb@$HOST"
