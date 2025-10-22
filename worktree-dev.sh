#!/bin/bash
set -e

# Parse arguments
SETUP_ONLY=false
if [ "$1" = "--setup-only" ]; then
    SETUP_ONLY=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get workspace name from directory
WORKSPACE_NAME=$(basename "$(pwd)")

# Detect if we're in the main repo or a worktree
# In the main repo, .git is a directory. In a worktree, .git is a file.
IS_MAIN_REPO=false
if [ -d ".git" ]; then
    IS_MAIN_REPO=true
fi

# Calculate ports based on whether we're in main repo or worktree
if [ "$IS_MAIN_REPO" = true ]; then
    # Standard ports from docker-compose.yml
    WEB_PORT=8000
    NODE_PORT=8008
    NGINX_PORT=81
    HAPROXY_HTTP_PORT=80
    HAPROXY_HTTPS_PORT=443
    HAPROXY_STATS_PORT=1936
else
    # Worktree-specific ports calculated from directory name hash
    HASH=$(echo -n "$WORKSPACE_NAME" | md5 | head -c 4)
    PORT_OFFSET=$((0x$HASH % 900 + 100))

    WEB_PORT=$((8000 + PORT_OFFSET))
    NODE_PORT=$((8008 + PORT_OFFSET))
    NGINX_PORT=$((8100 + PORT_OFFSET))
    HAPROXY_HTTP_PORT=$((8200 + PORT_OFFSET))
    HAPROXY_HTTPS_PORT=$((8443 + PORT_OFFSET))
    HAPROXY_STATS_PORT=$((1936 + PORT_OFFSET))
fi

# Helper function to render Jinja2 templates
render_template() {
    local template_file=$1
    local output_file=$2

    python3 << EOF
import sys
from jinja2 import Template

template_path = "${template_file}"
output_path = "${output_file}"

with open(template_path, 'r') as f:
    template = Template(f.read())

rendered = template.render(
    workspace_name="${WORKSPACE_NAME}",
    web_port=${WEB_PORT},
    node_port=${NODE_PORT},
    nginx_port=${NGINX_PORT},
    haproxy_http_port=${HAPROXY_HTTP_PORT},
    haproxy_https_port=${HAPROXY_HTTPS_PORT},
    haproxy_stats_port=${HAPROXY_STATS_PORT}
)

# Ensure file ends with newline
if not rendered.endswith('\n'):
    rendered += '\n'

with open(output_path, 'w') as f:
    f.write(rendered)

print(f"✓ Rendered {template_path} -> {output_path}")
EOF
}

# Check if setup has been run
NEEDS_SETUP=false
if [ ! -f ".worktree/docker-compose.${WORKSPACE_NAME}.yml" ]; then
    NEEDS_SETUP=true
fi

# Run setup if needed
if [ "$NEEDS_SETUP" = true ]; then
    echo -e "${GREEN}=== NewsBlur Worktree Development Setup ===${NC}"
    echo ""
    echo -e "${GREEN}Workspace: ${WORKSPACE_NAME}${NC}"

    if [ "$IS_MAIN_REPO" = true ]; then
        echo -e "${GREEN}Detected: Main repository (will use standard Docker Compose ports)${NC}"
    else
        echo -e "${GREEN}Detected: Git worktree (will use unique ports to avoid conflicts)${NC}"
    fi

    # Fail fast checks
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    if ! command -v docker &> /dev/null; then
        echo -e "${RED}ERROR: Docker is not installed or not in PATH${NC}"
        echo "Please install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        echo -e "${RED}ERROR: Docker daemon is not running${NC}"
        echo "Please start Docker Desktop or the Docker daemon"
        exit 1
    fi

    if ! command -v docker compose &> /dev/null; then
        echo -e "${RED}ERROR: Docker Compose is not available${NC}"
        echo "Please install Docker Compose v2"
        exit 1
    fi

    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}ERROR: Python 3 is not installed${NC}"
        exit 1
    fi

    # Check for Jinja2
    if ! python3 -c "import jinja2" 2>/dev/null; then
        echo -e "${RED}ERROR: Python Jinja2 module is not installed${NC}"
        echo "Install with: pip3 install jinja2"
        exit 1
    fi

    echo -e "${GREEN}✓ Docker and Docker Compose are available${NC}"

    # Copy local_settings.py from parent repo if it exists and we don't have it
    if [ ! -f "newsblur_web/local_settings.py" ] && [ -f "../../../newsblur_web/local_settings.py" ]; then
        echo -e "${YELLOW}Copying local_settings.py from parent repo...${NC}"
        cp ../../../newsblur_web/local_settings.py newsblur_web/local_settings.py
        echo -e "${GREEN}✓ Copied local_settings.py${NC}"
    elif [ -f "newsblur_web/local_settings.py" ]; then
        echo -e "${GREEN}✓ local_settings.py already exists${NC}"
    fi

    echo -e "${BLUE}Port assignments:${NC}"
    echo "  - Web (Django):      $WEB_PORT"
    echo "  - Node:              $NODE_PORT"
    echo "  - Nginx:             $NGINX_PORT"
    echo "  - HAProxy HTTP:      $HAPROXY_HTTP_PORT"
    echo "  - HAProxy HTTPS:     $HAPROXY_HTTPS_PORT"
    echo "  - HAProxy Stats:     $HAPROXY_STATS_PORT"
    echo ""

    # Create directories
    mkdir -p .worktree/haproxy

    # Render docker-compose template
    echo -e "${YELLOW}Generating docker-compose configuration from template...${NC}"
    render_template \
        "docker/compose/worktree.yml.j2" \
        ".worktree/docker-compose.${WORKSPACE_NAME}.yml"

    # Render HAProxy template
    echo -e "${YELLOW}Generating HAProxy configuration from template...${NC}"
    render_template \
        "docker/haproxy/haproxy.worktree.cfg.j2" \
        ".worktree/haproxy/haproxy.${WORKSPACE_NAME}.cfg"

    # Create SSL certificates if needed
    if [ ! -f "config/certificates/localhost.pem" ]; then
        # Check if we can copy from parent repo (handle both regular repo and worktree)
        PARENT_CERTS=""
        if [ -d "../../../config/certificates" ] && [ -f "../../../config/certificates/localhost.pem" ]; then
            PARENT_CERTS="../../../config/certificates"
        elif [ -d "/srv/newsblur/config/certificates" ] && [ -f "/srv/newsblur/config/certificates/localhost.pem" ]; then
            PARENT_CERTS="/srv/newsblur/config/certificates"
        fi

        if [ -n "$PARENT_CERTS" ]; then
            echo -e "${YELLOW}Copying SSL certificates from parent repo...${NC}"
            mkdir -p config/certificates
            cp "$PARENT_CERTS"/* config/certificates/
            echo -e "${GREEN}✓ SSL certificates copied${NC}"
        else
            echo -e "${YELLOW}Creating SSL certificates (this may take a moment)...${NC}"
            # Use make keys but suppress the sudo error at the end
            make keys 2>&1 | grep -v "sudo:" || true
            if [ -f "config/certificates/localhost.pem" ]; then
                echo -e "${GREEN}✓ SSL certificates created${NC}"
            else
                echo -e "${RED}ERROR: Failed to create SSL certificates${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${GREEN}✓ SSL certificates already exist${NC}"
    fi

    # Check if shared services are already running (using original container names)
    echo -e "${YELLOW}Checking for shared service containers...${NC}"

    SHARED_SERVICES_RUNNING=true

    if ! docker ps --filter "name=db_postgres" --filter "status=running" --format "{{.Names}}" | grep -q "db_postgres"; then
        SHARED_SERVICES_RUNNING=false
    fi

    if ! docker ps --filter "name=db_mongo" --filter "status=running" --format "{{.Names}}" | grep -q "db_mongo"; then
        SHARED_SERVICES_RUNNING=false
    fi

    if ! docker ps --filter "name=db_redis" --filter "status=running" --format "{{.Names}}" | grep -q "db_redis"; then
        SHARED_SERVICES_RUNNING=false
    fi

    if ! docker ps --filter "name=db_elasticsearch" --filter "status=running" --format "{{.Names}}" | grep -q "db_elasticsearch"; then
        SHARED_SERVICES_RUNNING=false
    fi

    if [ "$SHARED_SERVICES_RUNNING" = false ]; then
        echo -e "${YELLOW}Shared services not running. Starting them...${NC}"

        # Start only the shared services (databases and imageproxy)
        # Using the standard docker-compose.yml which already has the correct names and ports
        docker compose -f docker-compose.yml up -d db_postgres db_mongo db_redis db_elasticsearch imageproxy dejavu

        echo -e "${YELLOW}Waiting for shared services to be ready...${NC}"

        echo "  - Waiting for PostgreSQL..."
        for i in {1..30}; do
            if docker exec db_postgres pg_isready -U newsblur &>/dev/null; then
                break
            fi
            if [ $i -eq 30 ]; then
                echo -e "${RED}ERROR: PostgreSQL failed to start${NC}"
                docker compose -f docker-compose.yml logs db_postgres
                exit 1
            fi
            sleep 2
        done

        echo "  - Waiting for MongoDB..."
        for i in {1..30}; do
            if docker exec db_mongo mongo --port 29019 --eval 'db.adminCommand({ping: 1})' --quiet &>/dev/null; then
                break
            fi
            if [ $i -eq 30 ]; then
                echo -e "${RED}ERROR: MongoDB failed to start${NC}"
                docker compose -f docker-compose.yml logs db_mongo
                exit 1
            fi
            sleep 2
        done

        echo "  - Waiting for Redis..."
        for i in {1..30}; do
            if docker exec db_redis redis-cli -p 6579 ping &>/dev/null; then
                break
            fi
            if [ $i -eq 30 ]; then
                echo -e "${RED}ERROR: Redis failed to start${NC}"
                docker compose -f docker-compose.yml logs db_redis
                exit 1
            fi
            sleep 2
        done

        echo -e "${GREEN}✓ Shared services are ready${NC}"
    else
        echo -e "${GREEN}✓ Shared services already running${NC}"
    fi

    # Start workspace-specific services
    echo -e "${YELLOW}Starting workspace services...${NC}"

    # Set environment variables for the workspace
    export COMPOSE_PROJECT_NAME="${WORKSPACE_NAME}"

    # Stop any existing containers first to avoid name conflicts
    docker compose -f ".worktree/docker-compose.${WORKSPACE_NAME}.yml" down 2>/dev/null || true

    # Start workspace containers using the standalone compose file
    docker compose -f ".worktree/docker-compose.${WORKSPACE_NAME}.yml" up -d --remove-orphans

    # Wait for workspace web container
    echo -e "${YELLOW}Waiting for workspace web container...${NC}"
    for i in {1..30}; do
        if docker ps --filter name=newsblur_web_${WORKSPACE_NAME} --filter status=running --format '{{.Names}}' | grep -q newsblur_web; then
            echo -e "${GREEN}✓ Web container is ready${NC}"
            break
        fi
        if [ $i -eq 30 ]; then
            echo -e "${RED}ERROR: Web container failed to start${NC}"
            docker compose -f ".worktree/docker-compose.${WORKSPACE_NAME}.yml" logs newsblur_web
            exit 1
        fi
        sleep 2
    done

    # Run database migrations (only needed once, but idempotent)
    echo -e "${YELLOW}Running database migrations...${NC}"
    docker exec "newsblur_web_${WORKSPACE_NAME}" python3 manage.py migrate --noinput || {
        echo -e "${YELLOW}Note: Migrations may have already been run${NC}"
    }

    # Collect static files (without compression, just file collection)
    echo -e "${YELLOW}Collecting static files...${NC}"
    docker exec "newsblur_web_${WORKSPACE_NAME}" python3 manage.py collectstatic --noinput --no-post-process || {
        echo -e "${YELLOW}Note: Static files may have already been collected${NC}"
    }

    # Load bootstrap fixtures (only needed once, but idempotent)
    echo -e "${YELLOW}Loading bootstrap fixtures...${NC}"
    docker exec "newsblur_web_${WORKSPACE_NAME}" python3 manage.py loaddata config/fixtures/bootstrap.json || {
        echo -e "${YELLOW}Note: Bootstrap fixtures may have already been loaded${NC}"
    }

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Workspace '${WORKSPACE_NAME}' is ready!                   ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Access your workspace at:${NC}"
    echo -e "  ${BLUE}https://localhost:${HAPROXY_HTTPS_PORT}${NC}"
    echo ""
    echo -e "${GREEN}Workspace services (unique to this workspace):${NC}"
    echo "  - HAProxy HTTPS:   https://localhost:${HAPROXY_HTTPS_PORT}"
    echo "  - HAProxy HTTP:    http://localhost:${HAPROXY_HTTP_PORT}"
    echo "  - HAProxy Stats:   https://localhost:${HAPROXY_STATS_PORT}"
    echo "  - Django (direct): http://localhost:${WEB_PORT}"
    echo "  - Node (direct):   http://localhost:${NODE_PORT}"
    echo "  - Nginx (direct):  http://localhost:${NGINX_PORT}"
    echo ""
    echo -e "${GREEN}Shared services (same across all workspaces):${NC}"
    echo "  - PostgreSQL:      localhost:5434"
    echo "  - MongoDB:         localhost:29019"
    echo "  - Redis:           localhost:6579"
    echo "  - Elasticsearch:   localhost:9200"
    echo "  - ImageProxy:      localhost:8088"
    echo "  - Dejavu (ES UI):  localhost:1358"
    echo ""
    echo -e "${YELLOW}Note:${NC} You'll need to accept the self-signed SSL certificate."
    echo "In Chrome, type 'thisisunsafe' when you see the warning."
    echo ""
    echo -e "${GREEN}Development workflow:${NC}"
    echo "  - Python/JS/CSS auto-reload (no restart needed)"
    echo "  - Add packages to requirements.txt, run 'make deps'"
    echo "  - Use 'make log' to follow logs"
    echo "  - Use 'make shell' for Django shell"
    echo "  - Use 'make test' to run tests"
    echo ""

    # If running with --setup-only flag, exit here
    if [ "$SETUP_ONLY" = true ]; then
        exit 0
    fi
fi

# Print banner
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}          NewsBlur Workspace: ${WORKSPACE_NAME}${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}🌐 Access your workspace at:${NC}"
echo -e "   ${YELLOW}→ https://localhost:${HAPROXY_HTTPS_PORT}${NC}"
echo ""
echo -e "${BLUE}📊 Service URLs:${NC}"
echo "   • HAProxy Stats:   https://localhost:${HAPROXY_STATS_PORT}"
echo "   • Django (direct): http://localhost:${WEB_PORT}"
echo "   • Node (direct):   http://localhost:${NODE_PORT}"
echo "   • Nginx (direct):  http://localhost:${NGINX_PORT}"
echo ""
echo -e "${YELLOW}💡 Tip: Type 'thisisunsafe' in Chrome to bypass SSL certificate warning${NC}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 Starting containers...${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Set environment for docker compose
export COMPOSE_PROJECT_NAME="${WORKSPACE_NAME}"

# Stop any existing containers first to avoid name conflicts
docker compose -f ".worktree/docker-compose.${WORKSPACE_NAME}.yml" down 2>/dev/null || true

# Start the containers
docker compose -f ".worktree/docker-compose.${WORKSPACE_NAME}.yml" up -d --remove-orphans

echo ""
echo -e "${GREEN}✓ Workspace is running!${NC}"
echo ""
echo -e "${YELLOW}View logs:${NC} make worktree-log"
echo ""
