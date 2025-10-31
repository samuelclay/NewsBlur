# NewsBlur Kubernetes Quick Start

Get NewsBlur running on Kubernetes in 5 minutes.

## Prerequisites

- Kubernetes cluster (Minikube, Kind, Docker Desktop, GKE, EKS, etc.)
- `kubectl` installed and configured
- Ingress controller (for local: `minikube addons enable ingress`)

## 1. Deploy

```bash
cd k8s

# Deploy everything
./deploy.sh development

# Or manually:
kubectl apply -k overlays/development
```

## 2. Initialize Database

```bash
# Run migrations
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py migrate

# Load initial data
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py loaddata config/fixtures/bootstrap.json

# Create admin user (optional)
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py createsuperuser
```

## 3. Access

```bash
# Port forward to nginx
kubectl port-forward -n newsblur service/nginx 8080:81

# Open in browser
open http://localhost:8080
```

## Common Commands

```bash
# View all pods
kubectl get pods -n newsblur

# View logs
kubectl logs -n newsblur -l app=newsblur-web -f

# Django shell
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py shell_plus

# Bash shell
kubectl exec -n newsblur -it deployment/newsblur-web -- bash

# Scale web app
kubectl scale deployment newsblur-web -n newsblur --replicas=3

# Restart a deployment
kubectl rollout restart deployment/newsblur-web -n newsblur
```

## Cleanup

```bash
# Remove all resources
./cleanup.sh development

# Or manually:
kubectl delete -k overlays/development

# Delete data (WARNING: permanent)
kubectl delete namespace newsblur
```

## Troubleshooting

### Pods not starting?

```bash
# Check pod status
kubectl get pods -n newsblur

# See what's wrong
kubectl describe pod -n newsblur <pod-name>

# Check logs
kubectl logs -n newsblur <pod-name>
```

### Can't connect to databases?

```bash
# Test from web pod
kubectl exec -n newsblur -it deployment/newsblur-web -- bash
nc -zv postgres 5432
nc -zv mongo 29019
nc -zv redis 6579
```

### Need to reset everything?

```bash
# Delete and recreate
kubectl delete namespace newsblur
./deploy.sh development
```

## Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Configure custom domain in `base/config/configmap.yaml`
- Set up production deployment with `overlays/production`
- Enable monitoring and metrics
- Configure SSL/TLS certificates

## Architecture Overview

```
                    ┌─────────────┐
                    │   Ingress   │
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              │                         │
         ┌────▼────┐              ┌────▼──────┐
         │  Nginx  │              │   Apps    │
         │  (81)   │              │           │
         └────┬────┘              ├───────────┤
              │                   │ Web:8000  │
              └──────────────────►│ Node:8008 │
                                  │ Proxy:8088│
                                  └─────┬─────┘
                                        │
                    ┌───────────────────┴────────────────┐
                    │                                    │
              ┌─────▼─────┐  ┌────────┐  ┌────────┐  ┌──▼────┐
              │ PostgreSQL│  │  Mongo │  │ Redis  │  │ Elastic│
              │   (5432)  │  │ (29019)│  │ (6579) │  │ (9200) │
              └───────────┘  └────────┘  └────────┘  └────────┘
```

For more details, see the [full README](README.md).
