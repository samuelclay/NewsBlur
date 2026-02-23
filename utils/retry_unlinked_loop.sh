#!/bin/bash
# retry_unlinked_loop.sh - Auto-restart wrapper for --retry-unlinked
#
# Processes unlinked PopularFeeds in small batches to avoid OOM kills.
# Since --retry-unlinked only processes feed__isnull=True, each run
# naturally picks up where the last left off (no offset tracking needed).
#
# Usage:
#   ./utils/retry_unlinked_loop.sh
#   CONTAINER=newsblur_web WORKERS=3 BATCH=500 ./utils/retry_unlinked_loop.sh

CONTAINER="${CONTAINER:-newsblur_web}"
WORKERS="${WORKERS:-3}"
BATCH="${BATCH:-500}"

attempt=0
while true; do
    attempt=$((attempt + 1))

    echo ""
    echo "=========================================="
    echo "  Attempt #${attempt} - batch=${BATCH}, workers=${WORKERS}"
    echo "  $(date)"
    echo "=========================================="
    echo ""

    OUTPUT=$(docker exec -t "$CONTAINER" python manage.py bootstrap_popular_feeds \
        --retry-unlinked --limit "$BATCH" --workers "$WORKERS" 2>&1)

    echo "$OUTPUT"
    EXIT_CODE=$?

    # Check if there are no more unlinked feeds
    if echo "$OUTPUT" | grep -q "Found 0 unlinked"; then
        echo ""
        echo "All PopularFeeds have been linked!"
        break
    fi

    # Check for completion message
    if echo "$OUTPUT" | grep -q "^Done:"; then
        echo ""
        echo "Batch completed successfully."
        echo "Continuing in 5 seconds... (Ctrl+C to stop)"
        sleep 5
        continue
    fi

    # OOM or other failure
    echo ""
    echo "Process exited with code $EXIT_CODE"
    echo "Restarting in 10 seconds... (Ctrl+C to stop)"
    sleep 10
done
