#!/bin/bash
set -e

# NewsBlur Kubernetes Cleanup Script
# This script helps clean up NewsBlur from a Kubernetes cluster

NAMESPACE="newsblur"
OVERLAY="${1:-development}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

echo_warn "This will delete all NewsBlur resources from the '${NAMESPACE}' namespace."
echo_warn "Persistent data (databases) will be preserved unless you explicitly delete PVCs."
read -p "Are you sure you want to continue? (yes/no) " -n 3 -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo_info "Cleanup cancelled."
    exit 0
fi

echo_info "Cleaning up NewsBlur from Kubernetes (overlay: ${OVERLAY})"

# Delete resources
echo_info "Deleting Kubernetes resources..."
kubectl delete -k "overlays/${OVERLAY}" --ignore-not-found=true

echo_info "Cleanup complete!"
echo_info ""
echo_info "Persistent volumes and data have been preserved."
echo_info "To delete all data (WARNING: this is irreversible):"
echo_info "   kubectl delete pvc -n ${NAMESPACE} --all"
echo_info "   kubectl delete pv -l app.kubernetes.io/name=newsblur"
echo_info ""
echo_info "To completely remove the namespace:"
echo_info "   kubectl delete namespace ${NAMESPACE}"
