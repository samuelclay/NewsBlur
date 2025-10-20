# NewsBlur on Kubernetes

This directory contains Kubernetes manifests for deploying NewsBlur on Kubernetes clusters. The configuration is based on the `docker-compose.yml` setup and provides a production-ready deployment with persistent storage, service discovery, and scaling capabilities.

## Architecture

The NewsBlur Kubernetes deployment consists of the following components:

### Databases (StatefulSets with Persistent Storage)
- **PostgreSQL** (port 5432) - Stores feeds, subscriptions, and user accounts
- **MongoDB** (port 29019) - Stores stories, read stories, feed/page fetch histories
- **Redis** (port 6579) - Story assembly, caching, feed fetching schedules
- **Elasticsearch** (port 9200/9300) - Search functionality (optional but recommended)

### Applications (Deployments)
- **NewsBlur Web** (port 8000) - Django application serving web pages and API
- **NewsBlur Node** (port 8008) - Node.js services for sockets, favicons, text extraction, and pages
- **Celery Worker** - Background task processor for feed fetching and updates
- **Imageproxy** (port 8088) - Image proxy service
- **Nginx** (port 81) - Static file serving and reverse proxy

### Networking
- **Services** - ClusterIP services for internal communication
- **Ingress** - External access with path-based routing

## Prerequisites

1. **Kubernetes Cluster** (v1.19+)
   - Local: Minikube, Kind, Docker Desktop, or K3s
   - Cloud: GKE, EKS, AKS, or any managed Kubernetes service

2. **kubectl** - Kubernetes CLI tool
   ```bash
   # Install kubectl
   # https://kubernetes.io/docs/tasks/tools/
   ```

3. **kustomize** (optional, but recommended)
   ```bash
   # kustomize is built into kubectl 1.14+
   kubectl kustomize --help
   ```

4. **Ingress Controller** - For external access
   ```bash
   # For local development with minikube:
   minikube addons enable ingress
   
   # For other clusters, install nginx-ingress:
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
   ```

5. **Storage** - Persistent Volume provisioner (most clusters have this by default)

## Quick Start

### 1. Deploy to Development Environment

```bash
# From the repository root
cd k8s

# Create namespace and deploy all resources
kubectl apply -k overlays/development

# Watch deployment progress
kubectl get pods -n newsblur -w
```

### 2. Wait for Pods to Be Ready

All pods should reach the `Running` state. This may take 5-10 minutes on first deployment:

```bash
kubectl get pods -n newsblur

# Expected output:
# NAME                              READY   STATUS    RESTARTS   AGE
# elasticsearch-0                   1/1     Running   0          5m
# imageproxy-xxx                    1/1     Running   0          5m
# mongo-0                           1/1     Running   0          5m
# newsblur-node-xxx                 1/1     Running   0          5m
# newsblur-web-xxx                  1/1     Running   0          5m
# nginx-xxx                         1/1     Running   0          5m
# postgres-0                        1/1     Running   0          5m
# redis-0                           1/1     Running   0          5m
# task-celery-xxx                   1/1     Running   0          5m
```

### 3. Initialize the Database

Run Django migrations and load initial data:

```bash
# Run migrations
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py migrate

# Load bootstrap data (creates default site and user)
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py loaddata config/fixtures/bootstrap.json

# Create a superuser (optional)
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py createsuperuser
```

### 4. Access NewsBlur

#### Option A: Port Forwarding (simplest for testing)

```bash
# Forward the nginx service to localhost
kubectl port-forward -n newsblur service/nginx 8080:81

# Access at: http://localhost:8080
```

#### Option B: Through Ingress (recommended)

```bash
# Get the ingress IP/hostname
kubectl get ingress -n newsblur

# For local development, add to /etc/hosts:
echo "127.0.0.1 localhost" | sudo tee -a /etc/hosts

# Access at: http://localhost
```

#### Option C: Direct Service Access (for debugging)

```bash
# Access the web service directly
kubectl port-forward -n newsblur service/newsblur-web 8000:8000

# Access at: http://localhost:8000
```

## Configuration

### Customizing Settings

Edit the ConfigMap and Secret before deploying:

```bash
# Edit configuration
kubectl edit configmap newsblur-config -n newsblur

# Edit secrets (passwords, API keys)
kubectl edit secret newsblur-secrets -n newsblur
```

Important settings to customize:
- `NEWSBLUR_URL` - Your domain name
- `SESSION_COOKIE_DOMAIN` - Your domain name
- `POSTGRES_PASSWORD` - Database password (in secrets)
- `SECRET_KEY` - Django secret key (in secrets)

### Using a Custom Domain

1. Update the ConfigMap:
```yaml
data:
  NEWSBLUR_URL: "https://newsblur.example.com"
  SESSION_COOKIE_DOMAIN: "newsblur.example.com"
```

2. Update the Ingress:
```yaml
spec:
  rules:
  - host: newsblur.example.com  # Change from 'localhost'
    http:
      paths:
      # ... rest of the configuration
```

3. Apply changes:
```bash
kubectl apply -k overlays/development
```

## Scaling

### Manual Scaling

```bash
# Scale web application
kubectl scale deployment newsblur-web -n newsblur --replicas=3

# Scale node service
kubectl scale deployment newsblur-node -n newsblur --replicas=2

# Scale celery workers
kubectl scale deployment task-celery -n newsblur --replicas=2
```

### Auto-scaling with HPA

Create a Horizontal Pod Autoscaler:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: newsblur-web-hpa
  namespace: newsblur
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: newsblur-web
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Storage

### Persistent Volumes

The deployment uses PersistentVolumeClaims (PVCs) for database storage:

- `postgres-pvc` - PostgreSQL data (10Gi)
- `mongodb-pvc` - MongoDB data (20Gi)
- `redis-pvc` - Redis data (5Gi)
- `elasticsearch-pvc` - Elasticsearch data (10Gi)

```bash
# View PVCs
kubectl get pvc -n newsblur

# View PVs (actual storage)
kubectl get pv
```

### Backup and Restore

#### PostgreSQL Backup

```bash
# Backup
kubectl exec -n newsblur postgres-0 -- pg_dump -U newsblur newsblur > newsblur-backup.sql

# Restore
kubectl exec -i -n newsblur postgres-0 -- psql -U newsblur newsblur < newsblur-backup.sql
```

#### MongoDB Backup

```bash
# Backup
kubectl exec -n newsblur mongo-0 -- mongodump --port 29019 --out /tmp/backup
kubectl cp newsblur/mongo-0:/tmp/backup ./mongo-backup

# Restore
kubectl cp ./mongo-backup newsblur/mongo-0:/tmp/restore
kubectl exec -n newsblur mongo-0 -- mongorestore --port 29019 /tmp/restore
```

## Monitoring and Debugging

### View Logs

```bash
# All pods
kubectl logs -n newsblur -l app.kubernetes.io/name=newsblur --tail=50 -f

# Specific service
kubectl logs -n newsblur -l app=newsblur-web --tail=50 -f
kubectl logs -n newsblur -l app=newsblur-node --tail=50 -f
kubectl logs -n newsblur -l app=task-celery --tail=50 -f

# Database logs
kubectl logs -n newsblur postgres-0 --tail=50 -f
kubectl logs -n newsblur mongo-0 --tail=50 -f
kubectl logs -n newsblur redis-0 --tail=50 -f
```

### Shell Access

```bash
# Django shell
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py shell_plus

# Bash shell in web container
kubectl exec -n newsblur -it deployment/newsblur-web -- bash

# MongoDB shell
kubectl exec -n newsblur -it mongo-0 -- mongo --port 29019

# Redis CLI
kubectl exec -n newsblur -it redis-0 -- redis-cli -p 6579

# PostgreSQL shell
kubectl exec -n newsblur -it postgres-0 -- psql -U newsblur
```

### Check Service Health

```bash
# Get all resources
kubectl get all -n newsblur

# Check endpoints (service discovery)
kubectl get endpoints -n newsblur

# Describe a problematic pod
kubectl describe pod -n newsblur <pod-name>

# Check events
kubectl get events -n newsblur --sort-by='.lastTimestamp'
```

## Production Deployment

For production, use the production overlay:

```bash
# Deploy with production settings
kubectl apply -k overlays/production
```

Production changes:
- **Higher replica counts** - 3 web, 2 node, 2 celery workers
- **Resource limits** - Enforced memory and CPU limits
- **Multiple replicas** - Better availability and load distribution

Additional production recommendations:

1. **Use a proper domain and TLS**
   - Configure TLS certificates in Ingress
   - Use cert-manager for automatic certificate management

2. **External Databases** (optional)
   - For larger deployments, use managed database services
   - Update ConfigMap with external database URLs

3. **Persistent Volume Classes**
   - Use SSD-backed storage for databases
   - Configure backup policies for PVs

4. **Monitoring**
   - Deploy Prometheus and Grafana for metrics
   - Use the included `docker-compose.metrics.yml` as reference

5. **Security**
   - Rotate secrets regularly
   - Use Pod Security Policies/Standards
   - Enable network policies for pod-to-pod communication

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n newsblur

# Check pod details
kubectl describe pod -n newsblur <pod-name>

# Check logs for errors
kubectl logs -n newsblur <pod-name>
```

### Database Connection Issues

```bash
# Test database connectivity from web pod
kubectl exec -n newsblur -it deployment/newsblur-web -- bash
# Inside container:
nc -zv postgres 5432
nc -zv mongo 29019
nc -zv redis 6579
nc -zv elasticsearch 9200
```

### Service Not Accessible

```bash
# Check service endpoints
kubectl get endpoints -n newsblur

# Check ingress
kubectl describe ingress -n newsblur newsblur-ingress

# Test service internally
kubectl run -it --rm debug --image=alpine --restart=Never -n newsblur -- sh
# Inside container:
apk add curl
curl http://newsblur-web:8000
curl http://nginx:81
```

### Persistent Storage Issues

```bash
# Check PVC status
kubectl get pvc -n newsblur

# Check PV status
kubectl get pv

# If PVC is pending, check storage classes
kubectl get storageclass
```

## Uninstalling

### Remove All Resources

```bash
# Delete everything in the namespace
kubectl delete -k overlays/development

# Or delete the namespace (this will delete everything)
kubectl delete namespace newsblur
```

### Preserve Data

To delete resources but keep persistent volumes:

```bash
# Delete deployments and services first
kubectl delete deployment,service,ingress -n newsblur --all

# Keep StatefulSets and PVCs for data preservation
# Later you can delete them manually:
kubectl delete statefulset -n newsblur --all
kubectl delete pvc -n newsblur --all
```

## Differences from Docker Compose

This Kubernetes setup is based on `docker-compose.yml` with the following changes:

1. **Service Discovery** - Uses Kubernetes DNS instead of Docker networking
2. **Persistent Storage** - Uses PVCs instead of bind mounts
3. **Load Balancing** - Uses Kubernetes Services and Ingress
4. **Scaling** - Native horizontal scaling with replicas
5. **Health Checks** - Liveness and readiness probes
6. **Resource Management** - CPU and memory limits/requests
7. **Configuration** - ConfigMaps and Secrets instead of environment variables
8. **Volumes** - EmptyDir for temporary storage instead of host bind mounts

## Contributing

When updating the Kubernetes manifests:

1. Test changes in development overlay first
2. Update this README with any new features or changes
3. Ensure all resources have proper labels and annotations
4. Test scaling and upgrade scenarios
5. Document any new configuration options

## Support

For issues specific to Kubernetes deployment:
- Check this README's Troubleshooting section
- Review Kubernetes logs and events
- Ensure your cluster meets the prerequisites

For general NewsBlur issues:
- See main repository README.md
- Check docker-compose.yml for reference configuration
- Review ansible/ directory for production setup examples
