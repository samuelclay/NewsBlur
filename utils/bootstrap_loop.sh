#!/bin/bash
# bootstrap_loop.sh - Auto-restart wrapper for bootstrap_popular_feeds
#
# Tracks progress via offset file so OOM kills don't lose progress.
# Parses the "[restart with --offset N]" output from Phase 2.
# Processes in batches (--limit) to keep memory usage bounded.
#
# Usage:
#   ./utils/bootstrap_loop.sh                    # Start from last saved offset (or 0)
#   ./utils/bootstrap_loop.sh --reset            # Start from 0
#   ./utils/bootstrap_loop.sh --offset 5000      # Start from specific offset
#   CONTAINER=newsblur_web ./utils/bootstrap_loop.sh
#   WORKERS=3 BATCH=2000 ./utils/bootstrap_loop.sh

OFFSET_FILE="/tmp/bootstrap_popular_feeds_offset.txt"
CONTAINER="${CONTAINER:-newsblur_web}"
WORKERS="${WORKERS:-3}"
BATCH="${BATCH:-2000}"
EXTRA_ARGS="${EXTRA_ARGS:-}"

if [[ "$1" == "--reset" ]]; then
    echo "0" > "$OFFSET_FILE"
    echo "Reset offset to 0"
elif [[ "$1" == "--offset" && -n "$2" ]]; then
    echo "$2" > "$OFFSET_FILE"
    echo "Set offset to $2"
fi

# Initialize offset file if missing
if [[ ! -f "$OFFSET_FILE" ]]; then
    echo "0" > "$OFFSET_FILE"
fi

attempt=0
while true; do
    OFFSET=$(cat "$OFFSET_FILE")
    attempt=$((attempt + 1))

    echo ""
    echo "=========================================="
    echo "  Attempt #${attempt} - offset=${OFFSET}, limit=${BATCH}, workers=${WORKERS}"
    echo "  $(date)"
    echo "=========================================="
    echo ""

    # Track whether this batch processed any entries
    PROCESSED_ZERO=false

    # Run bootstrap with --limit for batching and reduced workers
    # Only Phase 2 output contains [restart with --offset N]
    docker exec -t "$CONTAINER" python manage.py bootstrap_popular_feeds \
        --offset "$OFFSET" --limit "$BATCH" --workers "$WORKERS" \
        $EXTRA_ARGS 2>&1 | while IFS= read -r line; do
        echo "$line"
        if [[ "$line" =~ \[restart\ with\ --offset\ ([0-9]+)\] ]]; then
            echo "${BASH_REMATCH[1]}" > "$OFFSET_FILE"
        fi
        if [[ "$line" =~ Processing\ 0\ feed\ entries ]]; then
            echo "DONE" > "${OFFSET_FILE}.done"
        fi
    done

    EXIT_CODE=${PIPESTATUS[0]}

    # Check if we've processed all entries
    if [[ -f "${OFFSET_FILE}.done" ]]; then
        rm -f "${OFFSET_FILE}.done"
        echo ""
        echo "All feed entries have been processed!"
        break
    fi

    if [[ $EXIT_CODE -eq 0 ]]; then
        # Batch completed successfully - advance offset for next batch
        NEW_OFFSET=$(cat "$OFFSET_FILE")
        if [[ "$NEW_OFFSET" -le "$OFFSET" ]]; then
            # Phase 2 didn't update offset (no feeds to fetch in this batch)
            NEW_OFFSET=$((OFFSET + BATCH))
            echo "$NEW_OFFSET" > "$OFFSET_FILE"
        fi
        echo ""
        echo "Batch completed. Next offset: $NEW_OFFSET"
        echo "Continuing in 5 seconds... (Ctrl+C to stop)"
        sleep 5
        continue
    fi

    NEW_OFFSET=$(cat "$OFFSET_FILE")
    echo ""
    echo "Process exited with code $EXIT_CODE (137=OOM killed)"
    echo "Last saved offset: $NEW_OFFSET (was $OFFSET)"
    echo "Restarting in 10 seconds... (Ctrl+C to stop)"
    sleep 10
done
