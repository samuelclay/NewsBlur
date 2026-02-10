#!/bin/bash
# bootstrap_loop.sh - Auto-restart wrapper for bootstrap_popular_feeds
#
# Tracks progress via offset file so OOM kills don't lose progress.
# Parses the "[restart with --offset N]" output from the management command.
#
# Usage:
#   ./utils/bootstrap_loop.sh                    # Start from last saved offset (or 0)
#   ./utils/bootstrap_loop.sh --reset            # Start from 0
#   ./utils/bootstrap_loop.sh --offset 5000      # Start from specific offset
#   CONTAINER=newsblur_web_add-site ./utils/bootstrap_loop.sh  # Use specific container

OFFSET_FILE="/tmp/bootstrap_popular_feeds_offset.txt"
CONTAINER="${CONTAINER:-newsblur_web}"
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
    echo "  Attempt #${attempt} - offset=${OFFSET}"
    echo "  $(date)"
    echo "=========================================="
    echo ""

    # Run bootstrap, tee to log, and parse offset from output
    docker exec -t "$CONTAINER" python manage.py bootstrap_popular_feeds \
        --offset "$OFFSET" $EXTRA_ARGS 2>&1 | while IFS= read -r line; do
        echo "$line"
        if [[ "$line" =~ \[restart\ with\ --offset\ ([0-9]+)\] ]]; then
            echo "${BASH_REMATCH[1]}" > "$OFFSET_FILE"
        fi
    done

    EXIT_CODE=${PIPESTATUS[0]}

    if [[ $EXIT_CODE -eq 0 ]]; then
        echo ""
        echo "Bootstrap completed successfully!"
        break
    fi

    NEW_OFFSET=$(cat "$OFFSET_FILE")
    echo ""
    echo "Process exited with code $EXIT_CODE (137=OOM killed)"
    echo "Last saved offset: $NEW_OFFSET (was $OFFSET)"
    echo "Restarting in 10 seconds... (Ctrl+C to stop)"
    sleep 10
done
