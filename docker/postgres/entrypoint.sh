#!/bin/bash
# entrypoint.sh

# Create a user with the specified UID/GID
usermod -u 1000 postgres
groupmod -g 1001 postgres

# Execute the original entrypoint of the image
exec docker-entrypoint.sh postgres
