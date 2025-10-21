#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== NewsBlur Conductor Workspace Setup ===${NC}"
echo ""

# Get workspace name from directory
WORKSPACE_NAME=$(basename "$(pwd)")
echo -e "${GREEN}Workspace: ${WORKSPACE_NAME}${NC}"

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

echo -e "${GREEN}✓ Docker and Docker Compose are available${NC}"

# Copy local_settings.py from parent repo if it exists and we don't have it
if [ ! -f "newsblur_web/local_settings.py" ] && [ -f "../../../newsblur_web/local_settings.py" ]; then
    echo -e "${YELLOW}Copying local_settings.py from parent repo...${NC}"
    cp ../../../newsblur_web/local_settings.py newsblur_web/local_settings.py
    echo -e "${GREEN}✓ Copied local_settings.py${NC}"
elif [ -f "newsblur_web/local_settings.py" ]; then
    echo -e "${GREEN}✓ local_settings.py already exists${NC}"
fi

# Calculate unique ports based on workspace name hash
echo -e "${YELLOW}Calculating workspace-specific ports...${NC}"
HASH=$(echo -n "$WORKSPACE_NAME" | md5 | head -c 4)
PORT_OFFSET=$((0x$HASH % 900 + 100))  # Offset between 100-999

WEB_PORT=$((8000 + PORT_OFFSET))
NODE_PORT=$((8008 + PORT_OFFSET))
NGINX_PORT=$((8100 + PORT_OFFSET))
HAPROXY_HTTP_PORT=$((8200 + PORT_OFFSET))
HAPROXY_HTTPS_PORT=$((8443 + PORT_OFFSET))
HAPROXY_STATS_PORT=$((1936 + PORT_OFFSET))

echo -e "${BLUE}Workspace ports:${NC}"
echo "  - Web (Django):      $WEB_PORT"
echo "  - Node:              $NODE_PORT"
echo "  - Nginx:             $NGINX_PORT"
echo "  - HAProxy HTTP:      $HAPROXY_HTTP_PORT"
echo "  - HAProxy HTTPS:     $HAPROXY_HTTPS_PORT"
echo "  - HAProxy Stats:     $HAPROXY_STATS_PORT"
echo ""

# Generate workspace-specific docker-compose file (standalone, not override)
echo -e "${YELLOW}Generating .conductor/docker-compose.${WORKSPACE_NAME}.yml...${NC}"

cat > ".conductor/docker-compose.${WORKSPACE_NAME}.yml" <<EOF
# Auto-generated workspace-specific docker-compose file
# Workspace: $WORKSPACE_NAME
# Standalone compose file for workspace services only

services:
  newsblur_web:
    container_name: newsblur_web_${WORKSPACE_NAME}
    hostname: nb-${WORKSPACE_NAME}.com
    image: newsblur/newsblur_python3:latest
    environment:
      - DOCKERBUILD=True
      - RUNWITHMAKEBUILD=\${RUNWITHMAKEBUILD:-True}
    stdin_open: true
    tty: true
    restart: unless-stopped
    ulimits:
      nproc: 10000
      nofile:
        soft: 10000
        hard: 10000
    ports:
      - ${WEB_PORT}:8000
    entrypoint: /bin/sh -c newsblur_web/entrypoint.sh
    volumes:
      - \${PWD}:/srv/newsblur
    networks:
      - default
      - newsblur_default

  newsblur_node:
    container_name: node_${WORKSPACE_NAME}
    image: newsblur/newsblur_node:latest
    user: "\${CURRENT_UID:-1000}:\${CURRENT_GID:-1000}"
    environment:
      - NODE_ENV=docker
      - MONGODB_PORT=29019
    command: node newsblur.js
    restart: unless-stopped
    stop_signal: HUP
    ports:
      - ${NODE_PORT}:8008
    volumes:
      - \${PWD}/node:/srv
      - \${PWD}/node/originals:/srv/originals
    networks:
      - default
      - newsblur_default

  nginx:
    container_name: nginx_${WORKSPACE_NAME}
    image: nginx:1.19.6
    restart: unless-stopped
    ports:
      - ${NGINX_PORT}:81
    depends_on:
      - newsblur_web
      - newsblur_node
    environment:
      - DOCKERBUILD=True
    volumes:
      - \${PWD}/docker/nginx/nginx.local.conf:/etc/nginx/conf.d/nginx.conf
      - \${PWD}:/srv/newsblur

  haproxy:
    container_name: haproxy_${WORKSPACE_NAME}
    image: haproxy:latest
    restart: unless-stopped
    depends_on:
      - nginx
      - newsblur_web
      - newsblur_node
    ports:
      - ${HAPROXY_HTTP_PORT}:80
      - ${HAPROXY_HTTPS_PORT}:443
      - ${HAPROXY_STATS_PORT}:1936
    volumes:
      - \${PWD}/.conductor/haproxy/haproxy.${WORKSPACE_NAME}.cfg:/usr/local/etc/haproxy/haproxy.cfg
      - \${PWD}:/srv/newsblur
    networks:
      - default
      - newsblur_default

  task_celery:
    container_name: task_celery_${WORKSPACE_NAME}
    image: newsblur/newsblur_python3
    user: "\${CURRENT_UID:-1000}:\${CURRENT_GID:-1000}"
    command: "celery worker -A newsblur_web -B --loglevel=INFO"
    restart: unless-stopped
    volumes:
      - \${PWD}:/srv/newsblur
    environment:
      - DOCKERBUILD=True
    networks:
      - default
      - newsblur_default

networks:
  newsblur_default:
    external: true
    name: newsblur_default
EOF

echo -e "${GREEN}✓ Created docker-compose.${WORKSPACE_NAME}.yml${NC}"

# Create workspace-specific HAProxy config
echo -e "${YELLOW}Creating HAProxy configuration...${NC}"

mkdir -p .conductor/haproxy

cat > ".conductor/haproxy/haproxy.${WORKSPACE_NAME}.cfg" <<EOF
# Auto-generated workspace-specific HAProxy config
# Workspace: $WORKSPACE_NAME

global
    maxconn 100000
    daemon
    ca-base /srv/newsblur/config/certificates
    crt-base /srv/newsblur/config/certificates
    tune.bufsize 32000
    tune.maxrewrite 8196
    tune.ssl.default-dh-param 2048
    log 127.0.0.1 local0 notice

defaults
    log global
    maxconn 100000
    mode http
    option forwardfor
    option http-server-close
    option httpclose
    option log-health-checks
    option log-separate-errors
    option httplog
    option redispatch
    option abortonclose
    timeout connect 10s
    timeout client 10s
    timeout server 30s
    timeout tunnel 1h
    retries 3
    errorfile 502 /srv/newsblur/templates/502.http
    errorfile 503 /srv/newsblur/templates/502.http
    errorfile 504 /srv/newsblur/templates/502.http

frontend public
    bind :80
    bind :443 ssl crt /srv/newsblur/config/certificates/localhost.pem
    http-response add-header Strict-Transport-Security max-age=0;\\ includeSubDomains
    option http-server-close

    acl is_root path /
    redirect scheme https if is_root !{ ssl_fc }

    acl gunicorn_dead nbsrv(gunicorn) lt 1
    acl nginx_dead nbsrv(nginx) lt 1

    monitor-uri /status
    monitor fail if gunicorn_dead
    monitor fail if nginx_dead

    use_backend node_socket if { path_beg /v3/socket.io/ }
    use_backend node_favicon if { path_beg /rss_feeds/icon/ }
    use_backend node_text if { path_beg /rss_feeds/original_text_fetcher }
    use_backend node_page if { path_beg /original_page/ }
    use_backend node_images if { path_beg /imageproxy/ }
    use_backend nginx if { path_beg /media/ }
    use_backend nginx if { path_beg /static/ }
    use_backend nginx if { path_beg /favicon }
    use_backend nginx if { path_beg /crossdomain/ }
    use_backend nginx if { path_beg /robots }
    use_backend nginx if { hdr_sub(host) -i blog.localhost }

    use_backend gunicorn unless gunicorn_dead || nginx_dead

backend node_images
    option httpchk HEAD /sc,seLJDaKBog3LLEMDe8cjBefMhnVSibO4RA5boZhWcVZ0=/https://samuelclay.com/static/images/2019%20-%20Cuba.jpg
    http-check expect rstatus 200|301
    http-request replace-path /imageproxy(.*)     \\1
    server node_images imageproxy:8088 check inter 600000ms

backend node_socket
    http-check expect rstatus 200|503
    balance roundrobin
    server node_socket node_${WORKSPACE_NAME}:8008 check inter 3000ms

backend node_favicon
    http-check expect rstatus 200|301|503
    balance roundrobin
    server node_favicon node_${WORKSPACE_NAME}:8008 check inter 3000ms

backend node_text
    http-check expect rstatus 200|503
    option httpchk GET /rss_feeds/original_text_fetcher?test=1
    balance roundrobin
    server node_text node_${WORKSPACE_NAME}:8008 check inter 3000ms

backend node_page
    http-check expect rstatus 200|503
    option httpchk GET /rss_feeds/original_text_fetcher?test=1
    balance roundrobin
    server node_page node_${WORKSPACE_NAME}:8008 check inter 3000ms

backend nginx
    balance roundrobin
    http-check expect rstatus 200|503
    server nginx nginx_${WORKSPACE_NAME}:81 check inter 60000ms

backend gunicorn
    balance roundrobin
    server app_django nb-${WORKSPACE_NAME}.com:8000 check inter 3000ms

listen stats
    bind :1936 ssl crt /srv/newsblur/config/certificates/localhost.pem
    stats enable
    stats hide-version
    stats realm Haproxy\\ Statistics
    stats uri /
    stats auth gimmiestats:StatsGiver
    stats refresh 15s
EOF

echo -e "${GREEN}✓ Created haproxy.${WORKSPACE_NAME}.cfg${NC}"

# Create SSL certificates if needed
if [ ! -d "config/certificates" ] || [ ! -f "config/certificates/localhost.pem" ]; then
    echo -e "${YELLOW}Creating SSL certificates...${NC}"
    mkdir -p config/certificates
    cd config/certificates
    openssl dhparam -out dhparam-2048.pem 2048 2>&1 | grep -v "^\."
    openssl req -x509 -nodes -new -sha256 -days 1024 -newkey rsa:2048 -keyout RootCA.key -out RootCA.pem -subj "/C=US/CN=Example-Root-CA" 2>&1 | grep -v "^\."
    openssl x509 -outform pem -in RootCA.pem -out RootCA.crt 2>&1 | grep -v "^\."
    openssl req -new -nodes -newkey rsa:2048 -keyout localhost.key -out localhost.csr -subj "/C=US/ST=YourState/L=YourCity/O=Example-Certificates/CN=localhost" 2>&1 | grep -v "^\."
    openssl x509 -req -sha256 -days 1024 -in localhost.csr -CA RootCA.pem -CAkey RootCA.key -CAcreateserial -out localhost.crt 2>&1 | grep -v "^\."
    cat localhost.crt localhost.key > localhost.pem
    cd ../..
    echo -e "${GREEN}✓ SSL certificates created${NC}"
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

# Start workspace containers using the standalone compose file
docker compose -f ".conductor/docker-compose.${WORKSPACE_NAME}.yml" up -d

# Wait for workspace web container
echo -e "${YELLOW}Waiting for workspace web container...${NC}"
for i in {1..30}; do
    if docker ps --filter name=newsblur_web_${WORKSPACE_NAME} --filter status=running --format '{{.Names}}' | grep -q newsblur_web; then
        echo -e "${GREEN}✓ Web container is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}ERROR: Web container failed to start${NC}"
        docker compose -f ".conductor/docker-compose.${WORKSPACE_NAME}.yml" logs newsblur_web
        exit 1
    fi
    sleep 2
done

# Run database migrations (only needed once, but idempotent)
echo -e "${YELLOW}Running database migrations...${NC}"
docker exec "newsblur_web_${WORKSPACE_NAME}" python3 manage.py migrate --noinput || {
    echo -e "${YELLOW}Note: Migrations may have already been run${NC}"
}

# Collect static files (copy from media to static without post-processing)
# This ensures glob patterns in assets.yml can find all files
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
