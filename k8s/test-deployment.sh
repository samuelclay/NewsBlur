#!/bin/bash
set -e

# NewsBlur Kubernetes Deployment Test Script
# This script validates the Kubernetes manifests can be built properly

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

ERRORS=0

# Test 1: Check YAML syntax
echo_test "Validating YAML syntax..."
if python3 -c "
import yaml
import sys
from pathlib import Path

errors = []
for yaml_file in Path('base').rglob('*.yaml'):
    try:
        with open(yaml_file, 'r') as f:
            yaml.safe_load_all(f.read())
    except Exception as e:
        print(f'Error in {yaml_file}: {e}')
        errors.append(yaml_file)
        
for yaml_file in Path('overlays').rglob('*.yaml'):
    try:
        with open(yaml_file, 'r') as f:
            yaml.safe_load_all(f.read())
    except Exception as e:
        print(f'Error in {yaml_file}: {e}')
        errors.append(yaml_file)
        
sys.exit(len(errors))
"; then
    echo_info "✓ All YAML files are valid"
else
    echo_error "✗ YAML syntax validation failed"
    ERRORS=$((ERRORS + 1))
fi

# Test 2: Check if kustomize can build
echo_test "Testing kustomize build for development overlay..."
if kubectl kustomize overlays/development > /dev/null 2>&1; then
    echo_info "✓ Development overlay builds successfully"
else
    echo_error "✗ Development overlay build failed"
    ERRORS=$((ERRORS + 1))
fi

echo_test "Testing kustomize build for production overlay..."
if kubectl kustomize overlays/production > /dev/null 2>&1; then
    echo_info "✓ Production overlay builds successfully"
else
    echo_error "✗ Production overlay build failed"
    ERRORS=$((ERRORS + 1))
fi

# Test 3: Verify all required resources are defined
echo_test "Checking for required resources..."

REQUIRED_RESOURCES=(
    "namespace"
    "configmap"
    "secret"
    "service"
    "deployment"
    "statefulset"
    "persistentvolumeclaim"
    "ingress"
)

DEV_OUTPUT=$(kubectl kustomize overlays/development 2>/dev/null)

for resource in "${REQUIRED_RESOURCES[@]}"; do
    # Convert to proper case (e.g., "namespace" -> "Namespace", "persistentvolumeclaim" -> "PersistentVolumeClaim")
    resource_kind=""
    case "$resource" in
        "namespace") resource_kind="Namespace" ;;
        "configmap") resource_kind="ConfigMap" ;;
        "secret") resource_kind="Secret" ;;
        "service") resource_kind="Service" ;;
        "deployment") resource_kind="Deployment" ;;
        "statefulset") resource_kind="StatefulSet" ;;
        "persistentvolumeclaim") resource_kind="PersistentVolumeClaim" ;;
        "ingress") resource_kind="Ingress" ;;
    esac
    
    if echo "$DEV_OUTPUT" | grep -q "kind: $resource_kind"; then
        echo_info "✓ Found $resource definition"
    else
        echo_error "✗ Missing $resource definition"
        ERRORS=$((ERRORS + 1))
    fi
done

# Test 4: Check for required services
echo_test "Checking for required services..."

REQUIRED_SERVICES=(
    "postgres"
    "mongo"
    "redis"
    "elasticsearch"
    "newsblur-web"
    "newsblur-node"
    "imageproxy"
    "nginx"
)

for service in "${REQUIRED_SERVICES[@]}"; do
    # Check if service exists by looking for metadata.name in a Service resource
    if echo "$DEV_OUTPUT" | grep -B 3 "name: $service" | grep -q "kind: Service"; then
        echo_info "✓ Found $service service"
    else
        # Could be defined as part of a StatefulSet, check that too
        if echo "$DEV_OUTPUT" | grep -B 3 "name: $service" | grep -q "kind: StatefulSet"; then
            echo_info "✓ Found $service as StatefulSet with service"
        else
            echo_warn "⚠ Service $service may not be defined correctly"
        fi
    fi
done

# Test 5: Verify deployment scripts exist and are executable
echo_test "Checking deployment scripts..."

if [ -f "deploy.sh" ] && [ -x "deploy.sh" ]; then
    echo_info "✓ deploy.sh exists and is executable"
else
    echo_error "✗ deploy.sh is missing or not executable"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "cleanup.sh" ] && [ -x "cleanup.sh" ]; then
    echo_info "✓ cleanup.sh exists and is executable"
else
    echo_error "✗ cleanup.sh is missing or not executable"
    ERRORS=$((ERRORS + 1))
fi

# Test 6: Verify documentation exists
echo_test "Checking documentation..."

REQUIRED_DOCS=(
    "README.md"
    "QUICKSTART.md"
    "EXAMPLES.md"
)

for doc in "${REQUIRED_DOCS[@]}"; do
    if [ -f "$doc" ]; then
        echo_info "✓ $doc exists"
    else
        echo_error "✗ $doc is missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# Summary
echo ""
echo "================================"
if [ $ERRORS -eq 0 ]; then
    echo_info "All tests passed! ✓"
    echo_info "Kubernetes manifests are ready for deployment."
    exit 0
else
    echo_error "Tests failed with $ERRORS error(s) ✗"
    echo_error "Please fix the errors above before deploying."
    exit 1
fi
