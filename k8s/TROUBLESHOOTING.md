# NewsBlur Kubernetes Troubleshooting Guide

This guide helps diagnose and fix common issues when deploying NewsBlur on Kubernetes.

## Table of Contents

- [Deployment Issues](#deployment-issues)
- [Pod Issues](#pod-issues)
- [Database Issues](#database-issues)
- [Network Issues](#network-issues)
- [Storage Issues](#storage-issues)
- [Application Issues](#application-issues)
- [Performance Issues](#performance-issues)

## Deployment Issues

### Manifests Won't Apply

**Symptom:** `kubectl apply` fails with validation errors

**Solutions:**

```bash
# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('base/namespace.yaml'))"

# Check kustomize build
kubectl kustomize overlays/development

# Apply with debug output
kubectl apply -k overlays/development --dry-run=client -v=9
```

### Namespace Already Exists

**Symptom:** Error: namespace "newsblur" already exists

**Solutions:**

```bash
# Delete existing namespace (WARNING: deletes all data)
kubectl delete namespace newsblur

# Or use a different namespace
kubectl kustomize overlays/development | sed 's/namespace: newsblur/namespace: newsblur-test/g' | kubectl apply -f -
```

## Pod Issues

### Pods Stuck in Pending

**Symptom:** Pods show status `Pending` for extended time

**Diagnosis:**

```bash
# Check pod events
kubectl describe pod -n newsblur <pod-name>

# Check node resources
kubectl top nodes

# Check PVC status
kubectl get pvc -n newsblur
```

**Common Causes & Solutions:**

1. **Insufficient Resources**
   ```bash
   # Check node capacity
   kubectl describe nodes | grep -A 5 "Allocated resources"
   
   # Reduce resource requests
   kubectl set resources deployment newsblur-web -n newsblur \
     --requests=cpu=100m,memory=256Mi
   ```

2. **No Storage Provisioner**
   ```bash
   # Check storage classes
   kubectl get storageclass
   
   # Install local-path provisioner (for local testing)
   kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
   ```

3. **Node Affinity/Taints**
   ```bash
   # Check node taints
   kubectl get nodes -o json | jq '.items[].spec.taints'
   
   # Add tolerations to deployments if needed
   ```

### Pods Stuck in ImagePullBackOff

**Symptom:** Pods can't pull container images

**Diagnosis:**

```bash
kubectl describe pod -n newsblur <pod-name> | grep -A 10 "Events:"
```

**Solutions:**

```bash
# Check if images exist
docker pull newsblur/newsblur_python3:latest
docker pull newsblur/newsblur_node:latest

# Use locally built images (for development)
# Build images first
cd /path/to/newsblur
docker build -t newsblur/newsblur_python3:latest -f docker/newsblur_base_image.Dockerfile .

# For minikube, load into minikube's docker
minikube image load newsblur/newsblur_python3:latest

# For kind, load into kind cluster
kind load docker-image newsblur/newsblur_python3:latest --name newsblur
```

### Pods CrashLoopBackOff

**Symptom:** Pods repeatedly crash and restart

**Diagnosis:**

```bash
# Check logs
kubectl logs -n newsblur <pod-name> --previous

# Check recent events
kubectl get events -n newsblur --sort-by='.lastTimestamp' | tail -20

# Describe pod
kubectl describe pod -n newsblur <pod-name>
```

**Common Causes:**

1. **Database Connection Failure**
   ```bash
   # Check if databases are ready
   kubectl get pods -n newsblur -l app=postgres
   kubectl get pods -n newsblur -l app=mongo
   kubectl get pods -n newsblur -l app=redis
   
   # Test connectivity from web pod
   kubectl exec -n newsblur -it deployment/newsblur-web -- nc -zv postgres 5432
   ```

2. **Missing Environment Variables**
   ```bash
   # Check configmap
   kubectl get configmap newsblur-config -n newsblur -o yaml
   
   # Check secrets
   kubectl get secret newsblur-secrets -n newsblur -o yaml
   ```

3. **Application Errors**
   ```bash
   # Check Django logs
   kubectl logs -n newsblur -l app=newsblur-web -f
   
   # Check for migrations
   kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py showmigrations
   ```

### Init Containers Failing

**Symptom:** Init containers can't complete

**Diagnosis:**

```bash
# Check init container logs
kubectl logs -n newsblur <pod-name> -c init-db
kubectl logs -n newsblur <pod-name> -c init-mongo

# Check if services are accessible
kubectl get endpoints -n newsblur
```

**Solutions:**

```bash
# Wait longer for databases to be ready
# Or remove init containers temporarily
kubectl edit deployment newsblur-web -n newsblur
# Delete the initContainers section
```

## Database Issues

### PostgreSQL Won't Start

**Symptom:** PostgreSQL pod fails to start or crashes

**Diagnosis:**

```bash
# Check logs
kubectl logs -n newsblur postgres-0

# Check PVC
kubectl describe pvc postgres-pvc -n newsblur

# Check permissions
kubectl exec -n newsblur -it postgres-0 -- ls -la /var/lib/postgresql/data
```

**Solutions:**

```bash
# Clear corrupted data (WARNING: data loss)
kubectl delete statefulset postgres -n newsblur
kubectl delete pvc postgres-pvc -n newsblur
kubectl apply -k overlays/development

# Or fix permissions
kubectl exec -n newsblur -it postgres-0 -- chown -R postgres:postgres /var/lib/postgresql/data
```

### MongoDB Connection Refused

**Symptom:** Applications can't connect to MongoDB

**Diagnosis:**

```bash
# Check MongoDB logs
kubectl logs -n newsblur mongo-0

# Check service
kubectl get svc mongo -n newsblur

# Test connection
kubectl run -it --rm mongo-test --image=mongo:4.0 --restart=Never -n newsblur -- \
  mongo --host mongo --port 29019
```

**Solutions:**

```bash
# Restart MongoDB
kubectl delete pod mongo-0 -n newsblur

# Check MongoDB status
kubectl exec -n newsblur -it mongo-0 -- mongo --port 29019 --eval "db.adminCommand('ping')"
```

### Redis Not Responding

**Symptom:** Redis doesn't respond to connections

**Diagnosis:**

```bash
# Check Redis logs
kubectl logs -n newsblur redis-0

# Test connection
kubectl exec -n newsblur -it redis-0 -- redis-cli -p 6579 ping
```

**Solutions:**

```bash
# Restart Redis
kubectl delete pod redis-0 -n newsblur

# Clear Redis data if corrupted
kubectl delete pvc redis-pvc -n newsblur
kubectl delete statefulset redis -n newsblur
kubectl apply -k overlays/development
```

### Elasticsearch Yellow/Red Health

**Symptom:** Elasticsearch cluster health is not green

**Diagnosis:**

```bash
# Check cluster health
kubectl exec -n newsblur -it elasticsearch-0 -- curl -s localhost:9200/_cluster/health?pretty

# Check indices
kubectl exec -n newsblur -it elasticsearch-0 -- curl -s localhost:9200/_cat/indices?v
```

**Solutions:**

```bash
# Increase memory limit
kubectl set resources statefulset elasticsearch -n newsblur \
  --limits=memory=2Gi

# Clear old indices
kubectl exec -n newsblur -it elasticsearch-0 -- curl -X DELETE localhost:9200/old-index-name
```

## Network Issues

### Services Not Reachable

**Symptom:** Services can't communicate with each other

**Diagnosis:**

```bash
# Check services
kubectl get svc -n newsblur

# Check endpoints
kubectl get endpoints -n newsblur

# Check DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -n newsblur -- \
  nslookup newsblur-web.newsblur.svc.cluster.local
```

**Solutions:**

```bash
# Verify service selectors match pod labels
kubectl get svc newsblur-web -n newsblur -o yaml | grep selector -A 2
kubectl get pods -n newsblur -l app=newsblur-web --show-labels

# Restart CoreDNS if DNS issues
kubectl rollout restart deployment coredns -n kube-system
```

### Ingress Not Working

**Symptom:** Can't access application through ingress

**Diagnosis:**

```bash
# Check ingress status
kubectl get ingress -n newsblur

# Describe ingress
kubectl describe ingress newsblur-ingress -n newsblur

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

**Solutions:**

```bash
# Ensure ingress controller is installed
kubectl get pods -n ingress-nginx

# For minikube
minikube addons enable ingress

# For other clusters
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Update host in /etc/hosts
echo "$(kubectl get ingress -n newsblur newsblur-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}') localhost" | sudo tee -a /etc/hosts
```

### Port Forwarding Fails

**Symptom:** `kubectl port-forward` doesn't work

**Solutions:**

```bash
# Check if pod is running
kubectl get pods -n newsblur

# Try different service
kubectl port-forward -n newsblur service/newsblur-web 8000:8000

# Check firewall rules
sudo iptables -L | grep 8000

# Use specific pod instead of service
kubectl port-forward -n newsblur $(kubectl get pod -n newsblur -l app=newsblur-web -o jsonpath='{.items[0].metadata.name}') 8000:8000
```

## Storage Issues

### PVC Stuck in Pending

**Symptom:** PersistentVolumeClaims won't bind

**Diagnosis:**

```bash
# Check PVC status
kubectl describe pvc postgres-pvc -n newsblur

# Check available PVs
kubectl get pv

# Check storage classes
kubectl get storageclass
```

**Solutions:**

```bash
# Create storage class (if missing)
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

# Use default storage class
kubectl patch storageclass local-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Or specify storage class in PVC
kubectl patch pvc postgres-pvc -n newsblur -p '{"spec":{"storageClassName":"local-storage"}}'
```

### Disk Space Full

**Symptom:** Pods fail due to disk space issues

**Diagnosis:**

```bash
# Check disk usage in pods
kubectl exec -n newsblur -it postgres-0 -- df -h

# Check node disk usage
kubectl describe node | grep -A 5 "Allocated resources"
```

**Solutions:**

```bash
# Clean up old data
kubectl exec -n newsblur -it postgres-0 -- du -sh /var/lib/postgresql/data/*

# Increase PVC size (if supported)
kubectl patch pvc postgres-pvc -n newsblur -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Or create new PVC and migrate data
```

## Application Issues

### Django Migrations Not Applied

**Symptom:** Application errors about database tables

**Solution:**

```bash
# Run migrations
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py migrate

# Check migration status
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py showmigrations

# Create missing migrations
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py makemigrations
```

### Static Files Not Loading

**Symptom:** CSS/JS files return 404

**Solution:**

```bash
# Collect static files
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py collectstatic --noinput

# Check nginx configuration
kubectl exec -n newsblur -it deployment/nginx -- nginx -t

# Verify static files volume
kubectl exec -n newsblur -it deployment/nginx -- ls -la /srv/newsblur/static/
```

### Celery Tasks Not Running

**Symptom:** Background tasks don't execute

**Diagnosis:**

```bash
# Check celery logs
kubectl logs -n newsblur -l app=task-celery -f

# Check celery status
kubectl exec -n newsblur -it deployment/task-celery -- celery -A newsblur_web inspect active

# Check Redis connection
kubectl exec -n newsblur -it deployment/task-celery -- redis-cli -h redis -p 6579 ping
```

**Solutions:**

```bash
# Restart celery workers
kubectl rollout restart deployment/task-celery -n newsblur

# Scale up workers
kubectl scale deployment task-celery -n newsblur --replicas=3
```

### Session/Login Issues

**Symptom:** Can't log in or sessions don't persist

**Diagnosis:**

```bash
# Check Redis sessions
kubectl exec -n newsblur -it redis-0 -- redis-cli -p 6579 keys "django.contrib.sessions*"

# Check session configuration
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py shell -c "from django.conf import settings; print(settings.SESSION_ENGINE)"
```

**Solutions:**

```bash
# Clear sessions
kubectl exec -n newsblur -it redis-0 -- redis-cli -p 6579 flushdb

# Check cookie domain setting
kubectl get configmap newsblur-config -n newsblur -o yaml | grep SESSION_COOKIE_DOMAIN

# Update domain if needed
kubectl edit configmap newsblur-config -n newsblur
```

## Performance Issues

### High CPU Usage

**Diagnosis:**

```bash
# Check resource usage
kubectl top pods -n newsblur

# Check detailed metrics
kubectl exec -n newsblur -it deployment/newsblur-web -- top -b -n 1
```

**Solutions:**

```bash
# Scale horizontally
kubectl scale deployment newsblur-web -n newsblur --replicas=3

# Increase CPU limits
kubectl set resources deployment newsblur-web -n newsblur \
  --limits=cpu=2000m

# Enable HPA
kubectl autoscale deployment newsblur-web -n newsblur \
  --cpu-percent=70 --min=2 --max=10
```

### High Memory Usage

**Diagnosis:**

```bash
# Check memory usage
kubectl top pods -n newsblur

# Check for memory leaks
kubectl exec -n newsblur -it deployment/newsblur-web -- ps aux --sort=-%mem | head -10
```

**Solutions:**

```bash
# Increase memory limits
kubectl set resources deployment newsblur-web -n newsblur \
  --limits=memory=2Gi

# Restart pods periodically
kubectl rollout restart deployment/newsblur-web -n newsblur
```

### Slow Database Queries

**Diagnosis:**

```bash
# Check PostgreSQL slow queries
kubectl exec -n newsblur -it postgres-0 -- psql -U newsblur -c "
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;"

# Check MongoDB slow queries
kubectl exec -n newsblur -it mongo-0 -- mongo --port 29019 --eval "db.setProfilingLevel(2)"
```

**Solutions:**

```bash
# Add database indices
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py dbshell

# Scale database resources
kubectl set resources statefulset postgres -n newsblur \
  --limits=cpu=2000m,memory=4Gi
```

## Getting More Help

If issues persist:

1. **Check logs in detail:**
   ```bash
   kubectl logs -n newsblur <pod-name> --previous
   kubectl logs -n newsblur <pod-name> -c <container-name>
   ```

2. **Enable debug mode:**
   Edit ConfigMap and set `DEBUG: "True"`, then restart pods

3. **Use kubectl debug:**
   ```bash
   kubectl debug -n newsblur <pod-name> -it --image=busybox
   ```

4. **Check Kubernetes events:**
   ```bash
   kubectl get events -n newsblur --sort-by='.lastTimestamp'
   ```

5. **Review main documentation:**
   - [README.md](README.md) - Main setup guide
   - [QUICKSTART.md](QUICKSTART.md) - Quick start commands
   - [EXAMPLES.md](EXAMPLES.md) - Common operations

6. **Open an issue:**
   - GitHub Issues: https://github.com/samuelclay/NewsBlur/issues
   - Include: kubectl version, cluster info, relevant logs
