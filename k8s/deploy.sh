#!/bin/bash
set -e

# NewsBlur Kubernetes Deployment Script
# This script helps deploy NewsBlur to a Kubernetes cluster

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

echo_info "Deploying NewsBlur to Kubernetes (overlay: ${OVERLAY})"
echo_info "Target namespace: ${NAMESPACE}"

# Validate overlay exists
if [ ! -d "overlays/${OVERLAY}" ]; then
    echo_error "Overlay '${OVERLAY}' does not exist. Available overlays: development, production"
    exit 1
fi

# Deploy resources
echo_info "Applying Kubernetes manifests..."
kubectl apply -k "overlays/${OVERLAY}"

# Wait for namespace to be created
echo_info "Waiting for namespace to be ready..."
kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/${NAMESPACE} --timeout=30s

# Wait for databases to be ready
echo_info "Waiting for databases to be ready (this may take a few minutes)..."
kubectl wait --for=condition=ready pod -l app=postgres -n ${NAMESPACE} --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongo -n ${NAMESPACE} --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n ${NAMESPACE} --timeout=300s
kubectl wait --for=condition=ready pod -l app=elasticsearch -n ${NAMESPACE} --timeout=300s

# Wait for applications to be ready
echo_info "Waiting for applications to be ready..."
kubectl wait --for=condition=ready pod -l app=newsblur-web -n ${NAMESPACE} --timeout=300s || echo_warn "NewsBlur Web took longer than expected"
kubectl wait --for=condition=ready pod -l app=newsblur-node -n ${NAMESPACE} --timeout=300s || echo_warn "NewsBlur Node took longer than expected"
kubectl wait --for=condition=ready pod -l app=imageproxy -n ${NAMESPACE} --timeout=300s || echo_warn "Imageproxy took longer than expected"
kubectl wait --for=condition=ready pod -l app=nginx -n ${NAMESPACE} --timeout=300s || echo_warn "Nginx took longer than expected"

echo_info "Deployment complete!"
echo_info ""
echo_info "Next steps:"
echo_info "1. Run database migrations:"
echo_info "   kubectl exec -n ${NAMESPACE} -it deployment/newsblur-web -- ./manage.py migrate"
echo_info ""
echo_info "2. Load bootstrap data:"
echo_info "   kubectl exec -n ${NAMESPACE} -it deployment/newsblur-web -- ./manage.py loaddata config/fixtures/bootstrap.json"
echo_info ""
echo_info "3. (Optional) Create a superuser:"
echo_info "   kubectl exec -n ${NAMESPACE} -it deployment/newsblur-web -- ./manage.py createsuperuser"
echo_info ""
echo_info "4. Access NewsBlur:"
echo_info "   kubectl port-forward -n ${NAMESPACE} service/nginx 8080:81"
echo_info "   Then open: http://localhost:8080"
echo_info ""
echo_info "Check deployment status:"
echo_info "   kubectl get pods -n ${NAMESPACE}"
echo_info ""
echo_info "View logs:"
echo_info "   kubectl logs -n ${NAMESPACE} -l app=newsblur-web -f"
