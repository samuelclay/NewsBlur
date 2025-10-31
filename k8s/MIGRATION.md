# Migrating from Docker Compose to Kubernetes

This guide helps you understand the differences between the Docker Compose setup and the Kubernetes deployment, and how to migrate your data.

## Architecture Comparison

### Docker Compose
```
docker-compose.yml
├── Services (containers)
├── Volumes (bind mounts)
├── Networks (docker network)
└── Environment variables
```

### Kubernetes
```
k8s/
├── Deployments/StatefulSets (pods)
├── PersistentVolumeClaims (storage)
├── Services (networking)
├── ConfigMaps/Secrets (configuration)
└── Ingress (external access)
```

## Service Mapping

| Docker Compose Service | Kubernetes Resource | Type |
|------------------------|---------------------|------|
| `newsblur_web` | `newsblur-web` Deployment | Application |
| `newsblur_node` | `newsblur-node` Deployment | Application |
| `task_celery` | `task-celery` Deployment | Worker |
| `imageproxy` | `imageproxy` Deployment | Service |
| `nginx` | `nginx` Deployment | Proxy |
| `db_postgres` | `postgres` StatefulSet | Database |
| `db_mongo` | `mongo` StatefulSet | Database |
| `db_redis` | `redis` StatefulSet | Database |
| `db_elasticsearch` | `elasticsearch` StatefulSet | Database |
| `haproxy` | Ingress Controller | Load Balancer |

## Key Differences

### 1. Service Discovery

**Docker Compose:**
```yaml
services:
  newsblur_web:
    depends_on:
      - db_postgres
```
Services reference each other by container name.

**Kubernetes:**
```yaml
env:
  - name: POSTGRES_HOST
    value: postgres  # Service name
```
Services reference each other through Kubernetes DNS (`service-name.namespace.svc.cluster.local`).

### 2. Storage

**Docker Compose:**
```yaml
volumes:
  - ./docker/volumes/postgres:/var/lib/postgresql/data
```
Direct bind mounts to host filesystem.

**Kubernetes:**
```yaml
volumeMounts:
  - name: postgres-storage
    mountPath: /var/lib/postgresql/data
volumes:
  - name: postgres-storage
    persistentVolumeClaim:
      claimName: postgres-pvc
```
PersistentVolumeClaims managed by Kubernetes storage provisioner.

### 3. Configuration

**Docker Compose:**
```yaml
environment:
  - POSTGRES_USER=newsblur
  - POSTGRES_PASSWORD=newsblur
```
Environment variables defined inline.

**Kubernetes:**
```yaml
env:
  - name: POSTGRES_USER
    valueFrom:
      configMapKeyRef:
        name: newsblur-config
        key: POSTGRES_USER
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: newsblur-secrets
        key: POSTGRES_PASSWORD
```
ConfigMaps and Secrets for centralized configuration.

### 4. Networking

**Docker Compose:**
```yaml
ports:
  - 8000:8000
```
Direct port mapping to host.

**Kubernetes:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: newsblur-web
spec:
  ports:
    - port: 8000
      targetPort: 8000
```
Services expose ports within cluster; Ingress for external access.

### 5. Scaling

**Docker Compose:**
```bash
docker-compose up --scale newsblur_web=3
```
Manual scaling, no built-in load balancing.

**Kubernetes:**
```bash
kubectl scale deployment newsblur-web -n newsblur --replicas=3
```
Native scaling with automatic load balancing.

## Migration Steps

### Prerequisites

- Running Docker Compose deployment
- Access to Kubernetes cluster
- `kubectl` installed and configured
- Sufficient cluster resources (8GB RAM, 4 CPUs minimum)

### Step 1: Backup Data

First, backup all data from your Docker Compose deployment:

```bash
# Navigate to NewsBlur directory
cd /path/to/newsblur

# Backup PostgreSQL
docker-compose exec db_postgres pg_dump -U newsblur newsblur > backup-postgres.sql

# Backup MongoDB
docker-compose exec db_mongo mongodump --port 29019 --archive > backup-mongo.archive

# Backup Redis (optional, mostly cache data)
docker-compose exec db_redis redis-cli -p 6579 --rdb - > backup-redis.rdb

# Backup Elasticsearch indices (optional)
docker-compose exec db_elasticsearch curl -X GET "localhost:9200/_snapshot/my_backup" > backup-elasticsearch.json

# Backup media files
tar czf backup-media.tar.gz media/
```

### Step 2: Deploy to Kubernetes

```bash
# Clone repository (if not already)
git clone https://github.com/samuelclay/NewsBlur.git
cd NewsBlur/k8s

# Deploy base infrastructure
kubectl apply -k overlays/development

# Wait for databases to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n newsblur --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongo -n newsblur --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n newsblur --timeout=300s
kubectl wait --for=condition=ready pod -l app=elasticsearch -n newsblur --timeout=300s
```

### Step 3: Restore Data

#### PostgreSQL

```bash
# Copy backup to pod
kubectl cp backup-postgres.sql newsblur/postgres-0:/tmp/backup.sql

# Restore database
kubectl exec -n newsblur -it postgres-0 -- psql -U newsblur newsblur -f /tmp/backup.sql

# Verify
kubectl exec -n newsblur -it postgres-0 -- psql -U newsblur -d newsblur -c "SELECT COUNT(*) FROM django_migrations;"
```

#### MongoDB

```bash
# Restore from archive
kubectl exec -i -n newsblur mongo-0 -- mongorestore --port 29019 --archive < backup-mongo.archive

# Verify
kubectl exec -n newsblur -it mongo-0 -- mongo --port 29019 --eval "db.stories.count()"
```

#### Redis (if needed)

```bash
# Copy RDB file to pod
kubectl cp backup-redis.rdb newsblur/redis-0:/data/dump.rdb

# Restart Redis to load data
kubectl delete pod redis-0 -n newsblur

# Wait for restart
kubectl wait --for=condition=ready pod redis-0 -n newsblur --timeout=60s
```

#### Media Files

```bash
# Create a temporary pod with media volume
kubectl run -n newsblur media-restore --image=busybox --restart=Never --command -- sleep 3600

# Copy media files
kubectl cp backup-media.tar.gz newsblur/media-restore:/tmp/backup.tar.gz

# Extract (if you have a media PVC mounted)
kubectl exec -n newsblur -it media-restore -- tar xzf /tmp/backup.tar.gz -C /media/

# Cleanup
kubectl delete pod media-restore -n newsblur
```

### Step 4: Run Migrations

```bash
# Wait for web pods to be ready
kubectl wait --for=condition=ready pod -l app=newsblur-web -n newsblur --timeout=300s

# Run Django migrations (in case of version differences)
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py migrate

# Verify migrations
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py showmigrations
```

### Step 5: Verify Application

```bash
# Check all pods are running
kubectl get pods -n newsblur

# Check logs for errors
kubectl logs -n newsblur -l app=newsblur-web --tail=50

# Port forward to test
kubectl port-forward -n newsblur service/nginx 8080:81

# Test in browser
open http://localhost:8080

# Test login with existing credentials
```

### Step 6: Update Configuration

If you have custom configuration in Docker Compose:

```bash
# Review current Docker Compose environment
docker-compose config | grep -A 50 environment

# Update Kubernetes ConfigMap
kubectl edit configmap newsblur-config -n newsblur

# Update Kubernetes Secrets
kubectl edit secret newsblur-secrets -n newsblur

# Restart pods to pick up changes
kubectl rollout restart deployment -n newsblur
```

### Step 7: Switch DNS/Traffic

Once verified, update your DNS to point to the Kubernetes cluster:

```bash
# Get Ingress IP
kubectl get ingress -n newsblur newsblur-ingress

# Update DNS records to point to Ingress IP
# (This depends on your DNS provider)
```

### Step 8: Cleanup Old Docker Compose

After confirming Kubernetes is working:

```bash
# Stop Docker Compose (but keep data)
docker-compose stop

# Or completely remove (WARNING: deletes data)
docker-compose down -v
```

## Common Migration Issues

### Issue: Database Connection Errors

**Cause:** Service names are different between Docker Compose and Kubernetes.

**Solution:**
```bash
# Check service names
kubectl get svc -n newsblur

# Update application configuration
kubectl edit configmap newsblur-config -n newsblur

# Ensure services use correct names:
# - postgres (not db_postgres)
# - mongo (not db_mongo)
# - redis (not db_redis)
# - elasticsearch (not db_elasticsearch)
```

### Issue: Volume Permissions

**Cause:** Kubernetes runs containers with different UIDs than Docker Compose.

**Solution:**
```bash
# Check current ownership
kubectl exec -n newsblur -it postgres-0 -- ls -la /var/lib/postgresql/data

# Fix permissions if needed
kubectl exec -n newsblur -it postgres-0 -- chown -R postgres:postgres /var/lib/postgresql/data

# Or use initContainer to fix permissions
```

### Issue: Missing Environment Variables

**Cause:** Not all Docker Compose environment variables are in ConfigMap/Secret.

**Solution:**
```bash
# Compare configurations
docker-compose config | grep -A 100 environment > compose-env.txt
kubectl get configmap newsblur-config -n newsblur -o yaml > k8s-config.yaml

# Add missing variables to ConfigMap
kubectl edit configmap newsblur-config -n newsblur
```

### Issue: Static Files Not Loading

**Cause:** Static files volume not properly mounted.

**Solution:**
```bash
# Run collectstatic in Kubernetes
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py collectstatic --noinput

# Verify files exist
kubectl exec -n newsblur -it deployment/nginx -- ls -la /srv/newsblur/static/
```

## Rollback Plan

If you need to rollback to Docker Compose:

```bash
# 1. Backup Kubernetes data (same as Step 1 above)

# 2. Start Docker Compose
cd /path/to/newsblur
docker-compose up -d

# 3. Restore data to Docker Compose
docker-compose exec -T db_postgres psql -U newsblur newsblur < backup-postgres.sql
docker-compose exec -T db_mongo mongorestore --port 29019 --archive < backup-mongo.archive

# 4. Update DNS back to original server
```

## Performance Comparison

### Resource Usage

| Component | Docker Compose | Kubernetes | Notes |
|-----------|----------------|------------|-------|
| PostgreSQL | 256MB | 256MB-1GB | Same |
| MongoDB | 512MB | 512MB-2GB | Kubernetes allows better limits |
| Redis | 256MB | 256MB-1GB | Same |
| Elasticsearch | 384MB | 512MB-1.2GB | Slightly higher in K8s |
| Web App | 512MB | 512MB-2GB | Can scale horizontally |
| Node Service | 256MB | 256MB-1GB | Same |
| Celery | 512MB | 512MB-2GB | Can scale horizontally |

### Scaling Capabilities

**Docker Compose:**
- Manual scaling with `--scale` flag
- No automatic load balancing
- Limited to single host

**Kubernetes:**
- Horizontal Pod Autoscaler (HPA)
- Vertical Pod Autoscaler (VPA)
- Native load balancing
- Multi-node cluster support

## Benefits of Kubernetes

1. **Scalability**: Horizontal scaling with automatic load balancing
2. **High Availability**: Pod rescheduling, health checks, self-healing
3. **Resource Management**: CPU/memory limits and requests
4. **Rolling Updates**: Zero-downtime deployments
5. **Configuration Management**: Centralized ConfigMaps and Secrets
6. **Monitoring**: Native integration with Prometheus/Grafana
7. **Multi-environment**: Easy development/staging/production isolation
8. **Cloud Portability**: Run anywhere Kubernetes is available

## When to Stay on Docker Compose

- Single server deployment
- Simple development environment
- No scaling requirements
- Limited resources (< 8GB RAM)
- Prefer simplicity over features

## Additional Resources

- [Kubernetes Documentation](README.md)
- [Quick Start Guide](QUICKSTART.md)
- [Common Examples](EXAMPLES.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Official Kubernetes Docs](https://kubernetes.io/docs/)

## Getting Help

For migration-specific questions:
- GitHub Issues: https://github.com/samuelclay/NewsBlur/issues
- Include: Docker Compose version, Kubernetes version, error logs
