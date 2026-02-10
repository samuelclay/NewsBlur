#!/bin/bash
#
# check_health.sh - Check health of all NewsBlur production infrastructure
#
# Usage:
#   ./utils/check_health.sh              # Full check (HAProxy + all components)
#   ./utils/check_health.sh --haproxy    # HAProxy backend status only
#   ./utils/check_health.sh --group web  # Only check one group
#   ./utils/check_health.sh --quick      # HAProxy + just one server per group
#
# Runs from local machine, SSHes into production servers via ssh_hz.sh

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SSH_HZ="$SCRIPT_DIR/ssh_hz.sh"
HAPROXY_AUTH="gimmiestats:StatsGiver"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

# Parse arguments
MODE="full"
GROUP_FILTER=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --haproxy) MODE="haproxy"; shift ;;
        --quick) MODE="quick"; shift ;;
        --group) GROUP_FILTER="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--haproxy|--quick|--group <name>]"
            echo "  --haproxy   Only show HAProxy backend status"
            echo "  --quick     HAProxy + one server per group (fast)"
            echo "  --group     Only check: web, postgres, mongo, redis, node, task, consul"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Helper: run command on remote server, capture output and timing
ssh_check() {
    local server="$1"
    local cmd="$2"
    local timeout="${3:-10}"
    local start=$(python3 -c "import time; print(f'{time.time():.3f}')")
    local output
    output=$(cd "$PROJECT_DIR" && timeout "$timeout" "$SSH_HZ" -n "$server" "$cmd" 2>&1)
    local rc=$?
    local end=$(python3 -c "import time; print(f'{time.time():.3f}')")
    local ms=$(python3 -c "print(int(($end - $start) * 1000))")
    echo "$rc|$ms|$output"
}

# =====================
# HAProxy Stats Check
# =====================
check_haproxy() {
    echo -e "${BOLD}=== HAProxy Backend Status ===${NC}"
    echo ""

    local result
    # Get HAProxy stats CSV via socat on the admin socket
    local start_ha=$(python3 -c "import time; print(f'{time.time():.3f}')")
    local csv
    csv=$(cd "$PROJECT_DIR" && timeout 15 "$SSH_HZ" -n hwww "echo 'show stat' | docker exec -i haproxy socat stdio /var/run/haproxy.sock" 2>&1)
    local rc=$?
    local end_ha=$(python3 -c "import time; print(f'{time.time():.3f}')")
    local ms=$(python3 -c "print(int(($end_ha - $start_ha) * 1000))")

    if [ "$rc" != "0" ] || [ -z "$csv" ]; then
        echo -e "${RED}Failed to get HAProxy stats (rc=$rc, ${ms}ms)${NC}"
        return 1
    fi

    local down_count=0
    local total_count=0
    local current_backend=""

    while IFS= read -r line; do
        # Skip header and empty lines
        [[ "$line" == \#* ]] && continue
        [[ -z "$line" ]] && continue

        local pxname=$(echo "$line" | cut -d',' -f1)
        local svname=$(echo "$line" | cut -d',' -f2)
        local status=$(echo "$line" | cut -d',' -f18)
        local check_status=$(echo "$line" | cut -d',' -f37)
        local lastchg=$(echo "$line" | cut -d',' -f24)

        # Skip FRONTEND/BACKEND summary rows and stats
        [[ "$svname" == "FRONTEND" || "$svname" == "BACKEND" || "$pxname" == "stats" ]] && continue

        total_count=$((total_count + 1))

        # Format last change duration
        local since=""
        if [[ "$lastchg" =~ ^[0-9]+$ ]] && [ "$lastchg" -gt 0 ]; then
            if [ "$lastchg" -gt 86400 ]; then
                since="$(($lastchg / 86400))d"
            elif [ "$lastchg" -gt 3600 ]; then
                since="$(($lastchg / 3600))h"
            elif [ "$lastchg" -gt 60 ]; then
                since="$(($lastchg / 60))m"
            else
                since="${lastchg}s"
            fi
        fi

        if [ "$pxname" != "$current_backend" ]; then
            current_backend="$pxname"
            echo -e "  ${BOLD}${pxname}:${NC}"
        fi

        local icon color
        if [ "$status" = "UP" ]; then
            icon="UP"; color="$GREEN"
        elif [ "$status" = "OPEN" ]; then
            icon="OPEN"; color="$GREEN"
        elif [[ "$status" == *"DOWN"* ]]; then
            icon="DOWN"; color="$RED"
            down_count=$((down_count + 1))
        elif [ "$status" = "MAINT" ]; then
            icon="MAINT"; color="$YELLOW"
            down_count=$((down_count + 1))
        else
            icon="$status"; color="$YELLOW"
        fi

        printf "    ${color}[%-5s]${NC} %-45s check=%-6s since=%s\n" "$icon" "$svname" "$check_status" "$since"
    done <<< "$csv"

    echo ""
    if [ "$down_count" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}$down_count of $total_count backends DOWN${NC}"
    else
        echo -e "  ${GREEN}All $total_count backends UP${NC} (${ms}ms)"
    fi
}

# =====================
# Component Checks
# =====================

# Each check outputs: GROUP|SERVER|STATUS|DETAIL|MS
# Run in background, collect results

RESULTS_DIR=$(mktemp -d)
trap "rm -rf $RESULTS_DIR" EXIT

run_check() {
    local group="$1"
    local server="$2"
    local cmd="$3"
    local expect="${4:-200}"  # "200" for HTTP checks, "up" for docker checks

    local result
    result=$(ssh_check "$server" "$cmd" 10)
    local rc=$(echo "$result" | cut -d'|' -f1)
    local ms=$(echo "$result" | cut -d'|' -f2)
    local output=$(echo "$result" | cut -d'|' -f3-)

    local status="up"
    local detail=""

    if [ "$expect" = "up" ]; then
        # Docker container check
        if echo "$output" | grep -q "Up"; then
            detail=$(echo "$output" | head -1 | cut -c1-30)
        else
            status="down"
            detail="container not running"
        fi
    else
        # HTTP status check
        if [ "$rc" != "0" ]; then
            status="down"
            detail="SSH failed (rc=$rc)"
        elif [ "$output" = "200" ]; then
            detail="HTTP 200"
        else
            status="down"
            detail="HTTP $output"
        fi
    fi

    echo "${group}|${server}|${status}|${detail}|${ms}" >> "$RESULTS_DIR/results.txt"
}

check_components() {
    local pids=()

    # Web servers
    if [ -z "$GROUP_FILTER" ] || [ "$GROUP_FILTER" = "web" ]; then
        local web_servers=(happ-web-01 happ-web-02 happ-web-03 happ-web-04 happ-web-05 happ-web-06)
        [ "$MODE" = "quick" ] && web_servers=(happ-web-01)
        for s in "${web_servers[@]}"; do
            run_check "Web App" "$s" "curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:8000/_haproxychk" &
            pids+=($!)
        done
    fi

    # PostgreSQL
    if [ -z "$GROUP_FILTER" ] || [ "$GROUP_FILTER" = "postgres" ]; then
        run_check "PostgreSQL" "hdb-postgres-1" "curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:5579/db_check/postgres" &
        pids+=($!)
    fi

    # MongoDB
    if [ -z "$GROUP_FILTER" ] || [ "$GROUP_FILTER" = "mongo" ]; then
        run_check "MongoDB" "hdb-mongo-primary-2" "curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:5579/db_check/mongo" &
        pids+=($!)
        local quick_skip=""
        [ "$MODE" = "quick" ] && quick_skip="yes"
        if [ -z "$quick_skip" ]; then
            run_check "MongoDB Analytics" "hdb-mongo-analytics-1" "curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:5579/db_check/mongo_analytics" &
            pids+=($!)
        fi
    fi

    # Redis
    if [ -z "$GROUP_FILTER" ] || [ "$GROUP_FILTER" = "redis" ]; then
        local redis_checks=(
            "Redis Story|hdb-redis-story-1|redis_story"
            "Redis User|hdb-redis-user-1|redis_user"
            "Redis Session|hdb-redis-session-1|redis_sessions"
            "Redis PubSub|hdb-redis-pubsub|redis_pubsub"
        )
        if [ "$MODE" != "quick" ]; then
            redis_checks+=(
                "Redis Story|hdb-redis-story-2|redis_story"
                "Redis User|hdb-redis-user-2|redis_user"
                "Redis Session|hdb-redis-session-2|redis_sessions"
            )
        fi
        for entry in "${redis_checks[@]}"; do
            local group=$(echo "$entry" | cut -d'|' -f1)
            local server=$(echo "$entry" | cut -d'|' -f2)
            local endpoint=$(echo "$entry" | cut -d'|' -f3)
            run_check "$group" "$server" "curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:5579/db_check/${endpoint}" &
            pids+=($!)
        done
    fi

    # Elasticsearch
    if [ -z "$GROUP_FILTER" ] || [ "$GROUP_FILTER" = "elasticsearch" ]; then
        run_check "Elasticsearch" "hdb-elasticsearch-2" "curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:5579/db_check/elasticsearch" &
        pids+=($!)
    fi

    # Node services (check container status since they don't expose a health check port directly)
    if [ -z "$GROUP_FILTER" ] || [ "$GROUP_FILTER" = "node" ]; then
        local node_servers=(
            "Node Page|hnode-page-1"
            "Node Text|hnode-text-1"
            "Node Favicons|hnode-favicons-1"
            "Node Socket|hnode-socket-1"
        )
        if [ "$MODE" != "quick" ]; then
            node_servers+=(
                "Node Text|hnode-text-2"
                "Node Favicons|hnode-favicons-2"
                "Node Images|hnode-images-1"
                "Node Images|hnode-images-2"
            )
        fi
        for entry in "${node_servers[@]}"; do
            local group=$(echo "$entry" | cut -d'|' -f1)
            local server=$(echo "$entry" | cut -d'|' -f2)
            local container="node"
            [[ "$server" == *"images"* ]] && container="imageproxy"
            run_check "$group" "$server" "docker ps --format '{{.Status}}' --filter name=^${container}$" "up" &
            pids+=($!)
        done
    fi

    # Task workers
    if [ -z "$GROUP_FILTER" ] || [ "$GROUP_FILTER" = "task" ]; then
        local task_servers=()
        if [ "$MODE" = "quick" ]; then
            task_servers=(htask-celery-01 htask-work-1)
        else
            for i in $(seq -w 1 14); do
                task_servers+=("htask-celery-$i")
            done
            task_servers+=(htask-work-1 htask-work-2 htask-work-3)
        fi
        for s in "${task_servers[@]}"; do
            local container="task-celery"
            [[ "$s" == *"work"* ]] && container="task-work"
            run_check "Task Workers" "$s" "docker ps --format '{{.Status}}' --filter name=$container" "up" &
            pids+=($!)
        done
    fi

    # Consul
    if [ -z "$GROUP_FILTER" ] || [ "$GROUP_FILTER" = "consul" ]; then
        local consul_servers=(hdb-consul-1 hdb-consul-2 hdb-consul-3)
        [ "$MODE" = "quick" ] && consul_servers=(hdb-consul-1)
        for s in "${consul_servers[@]}"; do
            run_check "Consul" "$s" "curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:8500/v1/status/leader" &
            pids+=($!)
        done
    fi

    # Wait for all background checks
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null
    done
}

print_results() {
    echo ""
    echo -e "${BOLD}=== Component Health Checks ===${NC}"
    echo ""

    if [ ! -f "$RESULTS_DIR/results.txt" ]; then
        echo "  No results collected"
        return
    fi

    local down_count=0
    local total_count=0
    local current_group=""
    local down_list=""

    # Sort by group then server
    sort -t'|' -k1,1 -k2,2 "$RESULTS_DIR/results.txt" | while IFS='|' read -r group server status detail ms; do
        total_count=$((total_count + 1))

        if [ "$group" != "$current_group" ]; then
            current_group="$group"
            echo -e "  ${BOLD}${group}:${NC}"
        fi

        if [ "$status" = "up" ]; then
            printf "    ${GREEN}[OK]${NC}   %-30s %-25s (%sms)\n" "$server" "$detail" "$ms"
        else
            printf "    ${RED}[DOWN]${NC} %-30s %-25s (%sms)\n" "$server" "$detail" "$ms"
        fi
    done

    # Count downs for summary
    local total=$(wc -l < "$RESULTS_DIR/results.txt" | tr -d ' ')
    local downs=$(grep -c '|down|' "$RESULTS_DIR/results.txt" 2>/dev/null || true)
    downs=${downs:-0}
    downs=$(echo "$downs" | tr -d '[:space:]')

    echo ""
    if [ "$downs" -gt 0 ] 2>/dev/null; then
        echo -e "${RED}${BOLD}$downs of $total components UNHEALTHY:${NC}"
        grep '|down|' "$RESULTS_DIR/results.txt" | while IFS='|' read -r group server status detail ms; do
            echo -e "  ${RED}- $server ($group): $detail${NC}"
        done
    else
        echo -e "${GREEN}${BOLD}All $total components healthy.${NC}"
    fi
}

# =====================
# Main
# =====================

start_time=$(python3 -c "import time; print(f'{time.time():.3f}')")

if [ "$MODE" = "haproxy" ]; then
    check_haproxy
else
    check_haproxy
    check_components
    print_results
fi

end_time=$(python3 -c "import time; print(f'{time.time():.3f}')")
total_ms=$(python3 -c "print(int(($end_time - $start_time) * 1000))")
echo ""
echo "Completed in ${total_ms}ms"
