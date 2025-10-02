#!/bin/bash

# Run load testing during deployment to verify zero downtime

set -e

# Parse arguments
DURATION=120
CONCURRENCY=5
RATE=10
TARGET=""

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

# Create temp files
HEY_OUTPUT=$(mktemp)
DEPLOY_OUTPUT=$(mktemp)

cleanup() {
    rm -f "$HEY_OUTPUT" "$DEPLOY_OUTPUT"
}
trap cleanup EXIT

echo ""
echo "🚀 Starting load test deployment to $TARGET..."
echo ""
echo "Starting load testing: $URL"
echo "  Duration: ${DURATION}s, Concurrency: $CONCURRENCY, Rate: $RATE req/s/worker"
echo ""

# Start hey in background
hey -z=${DURATION}s -c=$CONCURRENCY -q=$RATE "$URL" > "$HEY_OUTPUT" 2>&1 &
HEY_PID=$!

# Wait for load testing to start
sleep 3

# Trigger deployment
echo "Triggering deployment: make $TARGET"
echo ""

cd /Users/sclay/projects/newsblur
make $TARGET > "$DEPLOY_OUTPUT" 2>&1
DEPLOY_EXIT=$?

# Wait for hey to finish
wait $HEY_PID

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
