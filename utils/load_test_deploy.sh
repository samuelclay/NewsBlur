#!/bin/bash

# Run load testing during deployment to verify zero downtime

set -e

# Parse arguments
DURATION=120
CONCURRENCY=5
RATE=10
TARGET=""
STATIC=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --staging)
            TARGET="staging"
            URL="https://staging.newsblur.com/_haproxychk"
            shift
            ;;
        --app)
            TARGET="app"
            URL="https://newsblur.com/_haproxychk"
            shift
            ;;
        --static)
            STATIC="_static"
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
            exit 1
            ;;
    esac
done

if [ -z "$TARGET" ]; then
    echo "Error: Must specify --staging or --app"
    exit 1
fi

# Determine deploy target based on static flag
if [ -n "$STATIC" ]; then
    if [ "$TARGET" = "app" ]; then
        DEPLOY_TARGET="static"
    else
        DEPLOY_TARGET="${TARGET}${STATIC}"
    fi
else
    DEPLOY_TARGET="$TARGET"
fi

# Create temp files
HEY_OUTPUT=$(mktemp)
DEPLOY_OUTPUT=$(mktemp)

cleanup() {
    rm -f "$HEY_OUTPUT" "$DEPLOY_OUTPUT"
}
trap cleanup EXIT

STATS_URL="http://newsblur.com:1936/"
if [ "$TARGET" = "staging" ]; then
    STATS_URL="http://staging.newsblur.com:1936/"
fi

echo ""
echo "🚀 Starting load test deployment to $DEPLOY_TARGET..."
echo ""
echo "Starting load testing: $URL"
echo "  Duration: ${DURATION}s, Concurrency: $CONCURRENCY, Rate: $RATE req/s/worker"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Watch HAProxy stats at: $STATS_URL"
echo "    Look for servers in app_django, app_refresh, app_count, app_push backends"
echo "    Disabled servers will show yellow/orange with 'MAINT' status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Start hey in background
hey -z=${DURATION}s -c=$CONCURRENCY -q=$RATE "$URL" > "$HEY_OUTPUT" 2>&1 &
HEY_PID=$!

# Wait for load testing to start
sleep 3

# Trigger deployment
echo "Triggering deployment: make $DEPLOY_TARGET"
echo ""

cd /Users/sclay/projects/newsblur
ANSIBLE_FORCE_COLOR=1 make $DEPLOY_TARGET 2>&1 | tee "$DEPLOY_OUTPUT"
DEPLOY_EXIT=${PIPESTATUS[0]}

# Stop hey gracefully so it outputs stats
if kill -0 $HEY_PID 2>/dev/null; then
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

echo ""
echo "================================================================================"
echo "DEPLOYMENT STATUS"
echo "================================================================================"
echo ""

if [ $DEPLOY_EXIT -eq 0 ]; then
    echo "✓ Deployment completed successfully"
else
    echo "✗ Deployment failed with exit code: $DEPLOY_EXIT"
    echo ""
    echo "Last 50 lines of deployment output:"
    tail -50 "$DEPLOY_OUTPUT"
fi

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

exit $DEPLOY_EXIT
