#!/bin/bash

# Get workspace name
WORKSPACE_NAME=$(basename "$(pwd)")

# Check if setup has been run
if [ ! -f ".conductor/docker-compose.${WORKSPACE_NAME}.yml" ]; then
    echo "Docker compose file not found. Running setup first..."
    ./.conductor/conductor-setup.sh
fi

# Calculate ports (same logic as setup script)
HASH=$(echo -n "$WORKSPACE_NAME" | md5 | head -c 4)
PORT_OFFSET=$((0x$HASH % 900 + 100))

WEB_PORT=$((8000 + PORT_OFFSET))
NODE_PORT=$((8008 + PORT_OFFSET))
NGINX_PORT=$((8100 + PORT_OFFSET))
HAPROXY_HTTP_PORT=$((8200 + PORT_OFFSET))
HAPROXY_HTTPS_PORT=$((8443 + PORT_OFFSET))
HAPROXY_STATS_PORT=$((1936 + PORT_OFFSET))

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Start the containers
docker compose -f ".conductor/docker-compose.${WORKSPACE_NAME}.yml" up -d

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📋 Container Logs:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Follow logs
docker compose -p "${WORKSPACE_NAME}" -f ".conductor/docker-compose.${WORKSPACE_NAME}.yml" logs -f newsblur_web newsblur_node
