#!/usr/bin/env bash
set -euo pipefail

# check_fdroid_dependencies.sh checks Gradle's resolved graph, including transitive SDKs.
cd "$(dirname "$0")/.."
report=$(mktemp)
trap 'rm -f "$report"' EXIT
./gradlew --console=plain -Pfdroid -Pci :app:dependencies --configuration releaseRuntimeClasspath > "$report"
if grep -E '(com\.google\.(mlkit|android\.gms|android\.play)|com\.android\.billingclient):' "$report"; then
    echo 'F-Droid runtime includes proprietary Google SDKs.' >&2
    exit 1
fi
if grep -E 'FAILED|Could not resolve' "$report"; then
    echo 'F-Droid dependency resolution failed.' >&2
    exit 1
fi
echo 'F-Droid runtime contains no ML Kit, Play Services, Play Review or Play Billing SDKs.'
