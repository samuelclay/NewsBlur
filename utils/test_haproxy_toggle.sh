#!/bin/bash

# Test HAProxy server enable/disable functionality

set -e

# Parse arguments
DURATION=60
CONCURRENCY=5
RATE=10
SERVER="happ-web-01"
BACKEND="app_django"
URL="https://newsblur.com/_haproxychk"

while [[ $# -gt 0 ]]; do
    case $1 in
        --server)
            SERVER="$2"
            shift 2
            ;;
        --backend)
            BACKEND="$2"
            shift 2
            ;;
        --staging)
            URL="https://staging.newsblur.com/_haproxychk"
            shift
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --concurrency)
            CONCURRENCY="$2"
            shift 2
            ;;
        --rate)
            RATE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--server SERVER] [--backend BACKEND] [--staging] [--duration SECONDS] [--concurrency N] [--rate N]"
            echo ""
            echo "Common backends: app_django, app_refresh, app_count, app_push"
            echo "Example: $0 --server happ-web-01 --backend app_django"
            exit 1
            ;;
    esac
done

# Create temp file for hey output
HEY_OUTPUT=$(mktemp)

cleanup() {
    rm -f "$HEY_OUTPUT"
}
trap cleanup EXIT

echo ""
echo "🔧 Testing HAProxy enable/disable for $SERVER in backend $BACKEND"
echo ""
echo "Starting load testing: $URL"
echo "  Duration: ${DURATION}s, Concurrency: $CONCURRENCY, Rate: $RATE req/s/worker"
echo ""
echo "Watch HAProxy stats at: http://newsblur.com:1936/"
echo ""

# Start hey in background
hey -z=${DURATION}s -c=$CONCURRENCY -q=$RATE "$URL" > "$HEY_OUTPUT" 2>&1 &
HEY_PID=$!

# Wait for load testing to start
sleep 3

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏸  DISABLING server $SERVER in HAProxy..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd /Users/sclay/projects/newsblur
./utils/ssh_hz.sh -n hwww "echo 'disable server $BACKEND/$SERVER' | docker exec -i haproxy socat stdio /var/run/haproxy.sock" || {
    echo "Failed to disable server. Stopping hey..."
    kill -INT $HEY_PID 2>/dev/null
    wait $HEY_PID 2>/dev/null
    exit 1
}

echo ""
echo "✓ Server disabled. Verifying state..."
./utils/ssh_hz.sh -n hwww "echo 'show servers state $BACKEND' | docker exec -i haproxy socat stdio /var/run/haproxy.sock | grep '$SERVER' | awk '{print \"  State: srv_admin_state=\" \$7 \" (1=MAINT/disabled, 0=enabled)\"}'"
echo ""
echo "Waiting 10 seconds..."
sleep 10

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "▶  RE-ENABLING server $SERVER in HAProxy..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

./utils/ssh_hz.sh -n hwww "echo 'enable server $BACKEND/$SERVER' | docker exec -i haproxy socat stdio /var/run/haproxy.sock" || {
    echo "Failed to re-enable server!"
    kill -INT $HEY_PID 2>/dev/null
    wait $HEY_PID 2>/dev/null
    exit 1
}

echo ""
echo "✓ Server re-enabled. Verifying state..."
./utils/ssh_hz.sh -n hwww "echo 'show servers state $BACKEND' | docker exec -i haproxy socat stdio /var/run/haproxy.sock | grep '$SERVER' | awk '{print \"  State: srv_admin_state=\" \$7 \" (1=MAINT/disabled, 0=enabled)\"}'"
echo ""

# Stop hey gracefully
if kill -0 $HEY_PID 2>/dev/null; then
    echo "Stopping load test..."
    kill -INT $HEY_PID 2>/dev/null
fi
wait $HEY_PID 2>/dev/null

# Display results
echo ""
echo "================================================================================"
echo "LOAD TEST RESULTS"
echo "================================================================================"
echo ""
cat "$HEY_OUTPUT"

# Check for non-200 responses
if grep -E '^\s*\[[^2]' "$HEY_OUTPUT" | grep -v '\[200\]' > /dev/null; then
    echo ""
    echo "================================================================================"
    echo "!!! FOUND NON-200 RESPONSES !!!"
    echo "================================================================================"
    echo ""
    grep -E '^\s*\[' "$HEY_OUTPUT" | grep -v '\[200\]'
else
    echo ""
    echo "✓ All requests returned 200 OK"
fi
echo ""
