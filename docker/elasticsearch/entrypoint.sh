#!/bin/bash
# entrypoint.sh
#
# -XX:UseSVE=0 disables an ARM SVE optimization and is only a valid JVM flag
# on arm64; passing it unconditionally crashes Elasticsearch's startup on
# x86_64 with "Unrecognized VM option". Only add it when actually running on
# arm64/aarch64, checking the container's own architecture (not the host's)
# so this also works correctly for emulated containers.

arch="$(uname -m)"
if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
  export ES_JAVA_OPTS="$ES_JAVA_OPTS -XX:UseSVE=0"
  export CLI_JAVA_OPTS="$CLI_JAVA_OPTS -XX:UseSVE=0"
fi

exec /bin/tini -- /usr/local/bin/docker-entrypoint.sh eswrapper
