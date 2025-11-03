# Getting Started with NewsBlur on Kubernetes

Welcome! This guide will help you get NewsBlur running on your Kubernetes cluster.

## What You'll Need

- **Kubernetes Cluster** - Any Kubernetes 1.19+ cluster:
  - Local: Minikube, Kind, Docker Desktop, or K3s
  - Cloud: GKE, EKS, AKS, DigitalOcean, Linode, etc.
  - Self-hosted: Any Kubernetes distribution

- **kubectl** - Command-line tool for Kubernetes
  - Install: https://kubernetes.io/docs/tasks/tools/

- **8GB RAM and 4 CPUs minimum** - For running all services

## Quick Start (5 Minutes)

### 1. Deploy NewsBlur

```bash
# Navigate to the k8s directory
cd k8s

# Deploy everything with one command
./deploy.sh development

# This will:
# - Create the newsblur namespace
# - Deploy all databases (postgres, mongo, redis, elasticsearch)
# - Deploy all applications (web, node, celery, nginx, imageproxy)
# - Wait for everything to be ready
```

### 2. Initialize the Database

```bash
# Run Django migrations
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py migrate

# Load initial data (creates default site and settings)
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py loaddata config/fixtures/bootstrap.json

# Optional: Create a superuser account
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py createsuperuser
```

### 3. Access NewsBlur

```bash
# Port forward to access the application
kubectl port-forward -n newsblur service/nginx 8080:81

# Open in your browser
open http://localhost:8080
```

That's it! NewsBlur is now running on Kubernetes! 🎉

## What Just Happened?

The deployment script created:

- **Namespace**: `newsblur` - Isolated environment for all resources
- **4 Databases**: PostgreSQL, MongoDB, Redis, Elasticsearch (with persistent storage)
- **5 Applications**: Web app, Node services, Celery workers, Nginx, Imageproxy
- **9 Services**: For internal communication between pods
- **1 Ingress**: For external access routing
- **Storage**: 45GB of persistent volumes for databases

## Next Steps

### View Your Deployment

```bash
# See all pods
kubectl get pods -n newsblur

# See all services
kubectl get services -n newsblur

# See persistent volumes
kubectl get pvc -n newsblur
```

### Check Logs

```bash
# View web application logs
kubectl logs -n newsblur -l app=newsblur-web -f

# View node service logs
kubectl logs -n newsblur -l app=newsblur-node -f

# View celery worker logs
kubectl logs -n newsblur -l app=task-celery -f
```

### Scale Your Deployment

```bash
# Scale the web application to 3 replicas
kubectl scale deployment newsblur-web -n newsblur --replicas=3

# Scale the node service to 2 replicas
kubectl scale deployment newsblur-node -n newsblur --replicas=2

# Check the new pods
kubectl get pods -n newsblur
```

### Access Different Services

```bash
# Access Django shell
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py shell_plus

# Access PostgreSQL
kubectl exec -n newsblur -it postgres-0 -- psql -U newsblur

# Access MongoDB
kubectl exec -n newsblur -it mongo-0 -- mongo --port 29019

# Access Redis
kubectl exec -n newsblur -it redis-0 -- redis-cli -p 6579

# Bash shell in web container
kubectl exec -n newsblur -it deployment/newsblur-web -- bash
```

## Common Tasks

### Update Configuration

```bash
# Edit ConfigMap (application settings)
kubectl edit configmap newsblur-config -n newsblur

# Edit Secrets (passwords, API keys)
kubectl edit secret newsblur-secrets -n newsblur

# Restart pods to pick up changes
kubectl rollout restart deployment -n newsblur
```

### Restart a Service

```bash
# Restart web application
kubectl rollout restart deployment/newsblur-web -n newsblur

# Restart all applications
kubectl rollout restart deployment -n newsblur
```

### View Resource Usage

```bash
# See CPU and memory usage
kubectl top pods -n newsblur

# See node resources
kubectl top nodes
```

### Backup Data

```bash
# Backup PostgreSQL
kubectl exec -n newsblur postgres-0 -- pg_dump -U newsblur newsblur > newsblur-backup.sql

# Backup MongoDB
kubectl exec -n newsblur mongo-0 -- mongodump --port 29019 --archive > newsblur-mongo-backup.archive
```

## Troubleshooting

### Pods Not Starting?

```bash
# Check what's wrong
kubectl describe pod -n newsblur <pod-name>

# View events
kubectl get events -n newsblur --sort-by='.lastTimestamp'
```

### Can't Access the Application?

```bash
# Make sure port-forward is running
kubectl port-forward -n newsblur service/nginx 8080:81

# Or try direct web service
kubectl port-forward -n newsblur service/newsblur-web 8000:8000
```

### Need to Start Over?

```bash
# Remove everything (but keep data)
./cleanup.sh development

# Redeploy
./deploy.sh development
```

For more troubleshooting help, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Environment Comparison

### Development (default)

- **Purpose**: Local testing and development
- **Replicas**: 1 of each service
- **Resources**: Lower limits for resource-constrained environments
- **Access**: Port forwarding

```bash
./deploy.sh development
```

### Production

- **Purpose**: Production deployment
- **Replicas**: 3 web, 2 node, 2 celery workers
- **Resources**: Higher limits for better performance
- **Access**: Through Ingress with proper domain

```bash
./deploy.sh production
```

## Cleaning Up

### Remove Everything (Keep Data)

```bash
./cleanup.sh development
```

### Remove Everything (Including Data)

```bash
# Delete namespace (deletes everything)
kubectl delete namespace newsblur

# This will delete:
# - All pods
# - All services
# - All persistent volumes and data
```

## Learn More

Now that you have NewsBlur running, explore more advanced topics:

- **[README.md](README.md)** - Complete deployment guide with all options
- **[EXAMPLES.md](EXAMPLES.md)** - Real-world examples and operations
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Fix common problems
- **[MIGRATION.md](MIGRATION.md)** - Migrate from Docker Compose
- **[INDEX.md](INDEX.md)** - Documentation hub

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Your Browser                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ HTTP/HTTPS
                         │
┌────────────────────────▼────────────────────────────────────┐
│                      Ingress Controller                      │
│              (Path-based routing to services)                │
└────┬─────────────────────┬──────────────────────────────────┘
     │                     │
     │ /static, /media     │ /api, /, etc
     │                     │
┌────▼─────┐         ┌────▼──────────────────────────────────┐
│  Nginx   │         │     NewsBlur Web (Django)             │
│  (Port   │         │          (Port 8000)                  │
│   81)    │         └───────────────┬───────────────────────┘
└──────────┘                         │
                                     │ Talks to:
                    ┌────────────────┼────────────────┐
                    │                │                │
            ┌───────▼──────┐  ┌─────▼─────┐  ┌──────▼──────┐
            │ NewsBlur Node│  │   Celery  │  │ Imageproxy  │
            │  (Port 8008) │  │  Workers  │  │ (Port 8088) │
            └──────┬───────┘  └─────┬─────┘  └─────────────┘
                   │                │
                   │ Uses databases │
       ┌───────────┴────────────────┴───────────────┐
       │                                             │
┌──────▼──────┐  ┌──────────┐  ┌────────┐  ┌───────▼────────┐
│ PostgreSQL  │  │ MongoDB  │  │ Redis  │  │ Elasticsearch  │
│  (5432)     │  │ (29019)  │  │ (6579) │  │    (9200)      │
│  10Gi PVC   │  │ 20Gi PVC │  │ 5Gi PVC│  │   10Gi PVC     │
└─────────────┘  └──────────┘  └────────┘  └────────────────┘
```

## Getting Help

- **Issues**: https://github.com/samuelclay/NewsBlur/issues
- **Documentation**: Start with [INDEX.md](INDEX.md)
- **Quick Help**: [QUICKSTART.md](QUICKSTART.md)

## Success! 🎉

You now have NewsBlur running on Kubernetes! Enjoy your self-hosted RSS reader with the power of Kubernetes scalability and reliability.

Happy reading! 📰
