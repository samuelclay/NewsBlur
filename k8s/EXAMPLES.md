# NewsBlur Kubernetes Examples

This document contains practical examples for common operations with NewsBlur on Kubernetes.

## Deployment Examples

### Deploy to Local Minikube

```bash
# Start minikube
minikube start --memory 8192 --cpus 4

# Enable ingress
minikube addons enable ingress

# Deploy NewsBlur
kubectl apply -k overlays/development

# Wait for pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=newsblur -n newsblur --timeout=600s

# Initialize database
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py migrate
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py loaddata config/fixtures/bootstrap.json

# Access via port forward
kubectl port-forward -n newsblur service/nginx 8080:81

# Open in browser
minikube service nginx -n newsblur
```

### Deploy to Kind (Kubernetes in Docker)

```bash
# Create kind cluster
kind create cluster --name newsblur

# Install ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Deploy NewsBlur
kubectl apply -k overlays/development

# Port forward to access
kubectl port-forward -n newsblur service/nginx 8080:81
```

### Deploy to GKE (Google Kubernetes Engine)

```bash
# Create GKE cluster
gcloud container clusters create newsblur-cluster \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-2

# Get credentials
gcloud container clusters get-credentials newsblur-cluster --zone us-central1-a

# Install ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Deploy NewsBlur
kubectl apply -k overlays/production

# Get external IP
kubectl get ingress -n newsblur
```

## Configuration Examples

### Custom Domain Configuration

```bash
# Edit configmap
kubectl edit configmap newsblur-config -n newsblur

# Change:
data:
  NEWSBLUR_URL: "https://newsblur.example.com"
  SESSION_COOKIE_DOMAIN: "newsblur.example.com"

# Update ingress
kubectl edit ingress newsblur-ingress -n newsblur

# Change:
spec:
  rules:
  - host: newsblur.example.com  # instead of localhost

# Restart web pods
kubectl rollout restart deployment/newsblur-web -n newsblur
```

### Enable HTTPS with Let's Encrypt

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Update ingress with TLS
kubectl patch ingress newsblur-ingress -n newsblur --type=json -p='[
  {
    "op": "add",
    "path": "/metadata/annotations/cert-manager.io~1cluster-issuer",
    "value": "letsencrypt-prod"
  },
  {
    "op": "add",
    "path": "/spec/tls",
    "value": [
      {
        "hosts": ["newsblur.example.com"],
        "secretName": "newsblur-tls"
      }
    ]
  }
]'
```

### External PostgreSQL Database

```bash
# Create secret with external database credentials
kubectl create secret generic external-postgres -n newsblur \
  --from-literal=host=postgres.example.com \
  --from-literal=port=5432 \
  --from-literal=database=newsblur \
  --from-literal=username=newsblur \
  --from-literal=password=your-secure-password

# Update configmap
kubectl patch configmap newsblur-config -n newsblur --type=merge -p='
{
  "data": {
    "POSTGRES_HOST": "postgres.example.com"
  }
}'

# Delete internal postgres
kubectl delete statefulset postgres -n newsblur
kubectl delete service postgres -n newsblur
kubectl delete pvc postgres-pvc -n newsblur
```

## Scaling Examples

### Manual Scaling

```bash
# Scale web application
kubectl scale deployment newsblur-web -n newsblur --replicas=5

# Scale node service
kubectl scale deployment newsblur-node -n newsblur --replicas=3

# Scale celery workers
kubectl scale deployment task-celery -n newsblur --replicas=4

# Check status
kubectl get deployments -n newsblur
```

### Horizontal Pod Autoscaler

```bash
# Enable metrics-server (if not already installed)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Create HPA for web
kubectl autoscale deployment newsblur-web -n newsblur \
  --cpu-percent=70 \
  --min=2 \
  --max=10

# Create HPA for node
kubectl autoscale deployment newsblur-node -n newsblur \
  --cpu-percent=70 \
  --min=2 \
  --max=5

# Check HPA status
kubectl get hpa -n newsblur

# Describe HPA
kubectl describe hpa newsblur-web -n newsblur
```

### Vertical Pod Autoscaler

```bash
# Install VPA
kubectl apply -f https://github.com/kubernetes/autoscaler/releases/download/vertical-pod-autoscaler-0.13.0/vpa-v0.13.0.yaml

# Create VPA for web
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: newsblur-web-vpa
  namespace: newsblur
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: newsblur-web
  updatePolicy:
    updateMode: "Auto"
EOF

# Check VPA recommendations
kubectl describe vpa newsblur-web-vpa -n newsblur
```

## Backup and Restore Examples

### Backup All Databases

```bash
# Create backup directory
mkdir -p newsblur-backup/$(date +%Y%m%d)

# Backup PostgreSQL
kubectl exec -n newsblur postgres-0 -- pg_dump -U newsblur newsblur > \
  newsblur-backup/$(date +%Y%m%d)/postgres.sql

# Backup MongoDB
kubectl exec -n newsblur mongo-0 -- mongodump --port 29019 --archive > \
  newsblur-backup/$(date +%Y%m%d)/mongo.archive

# Backup Redis
kubectl exec -n newsblur redis-0 -- redis-cli -p 6579 --rdb - > \
  newsblur-backup/$(date +%Y%m%d)/redis.rdb

# Create tarball
tar czf newsblur-backup-$(date +%Y%m%d).tar.gz newsblur-backup/$(date +%Y%m%d)
```

### Restore from Backup

```bash
# Restore PostgreSQL
kubectl exec -i -n newsblur postgres-0 -- psql -U newsblur newsblur < \
  newsblur-backup/20231201/postgres.sql

# Restore MongoDB
kubectl exec -i -n newsblur mongo-0 -- mongorestore --port 29019 --archive < \
  newsblur-backup/20231201/mongo.archive

# Restart applications
kubectl rollout restart deployment/newsblur-web -n newsblur
kubectl rollout restart deployment/newsblur-node -n newsblur
kubectl rollout restart deployment/task-celery -n newsblur
```

### Automated Backups with CronJob

```bash
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: newsblur-backup
  namespace: newsblur
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:13.1
            command:
            - /bin/sh
            - -c
            - |
              pg_dump -h postgres -U newsblur newsblur > /backup/postgres-\$(date +%Y%m%d-%H%M%S).sql
            volumeMounts:
            - name: backup
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: backup-pvc
EOF
```

## Monitoring Examples

### Deploy Prometheus and Grafana

```bash
# Add Prometheus helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Access Grafana
kubectl port-forward -n monitoring service/prometheus-grafana 3000:80

# Default credentials: admin / prom-operator
```

### Custom Metrics Dashboard

```bash
# Port forward to Grafana
kubectl port-forward -n monitoring service/prometheus-grafana 3000:80

# Login and create dashboard with these queries:

# Request rate
sum(rate(nginx_http_requests_total{namespace="newsblur"}[5m])) by (pod)

# CPU usage
sum(rate(container_cpu_usage_seconds_total{namespace="newsblur"}[5m])) by (pod)

# Memory usage
sum(container_memory_working_set_bytes{namespace="newsblur"}) by (pod)

# Database connections
sum(pg_stat_database_numbackends{namespace="newsblur"})
```

## Debugging Examples

### Debug Networking Issues

```bash
# Deploy debug pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -n newsblur

# Inside debug pod:
# Test DNS resolution
nslookup postgres.newsblur.svc.cluster.local
nslookup mongo.newsblur.svc.cluster.local

# Test connectivity
curl http://newsblur-web:8000
curl http://nginx:81
nc -zv postgres 5432
nc -zv mongo 29019
nc -zv redis 6579

# Check routes
traceroute newsblur-web
```

### Debug Application Issues

```bash
# Check all resources
kubectl get all -n newsblur

# Describe problematic pod
kubectl describe pod -n newsblur newsblur-web-xxx

# Get events
kubectl get events -n newsblur --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n newsblur
kubectl top nodes

# Exec into pod
kubectl exec -it -n newsblur deployment/newsblur-web -- bash

# Inside pod:
# Check environment
env | grep -i postgres
env | grep -i mongo
env | grep -i redis

# Test database connections
nc -zv postgres 5432
nc -zv mongo 29019
nc -zv redis 6579

# Run Django checks
./manage.py check
./manage.py showmigrations
```

### Debug Storage Issues

```bash
# Check PVCs
kubectl get pvc -n newsblur

# Check PVs
kubectl get pv

# Describe PVC
kubectl describe pvc postgres-pvc -n newsblur

# Check storage class
kubectl get storageclass

# Create test PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: newsblur
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Check if it binds
kubectl get pvc test-pvc -n newsblur -w
```

## Migration Examples

### Migrate from Docker Compose

```bash
# 1. Backup docker-compose data
cd /path/to/newsblur
docker-compose exec db_postgres pg_dump -U newsblur newsblur > postgres-backup.sql
docker-compose exec db_mongo mongodump --port 29019 --archive > mongo-backup.archive

# 2. Deploy to Kubernetes
kubectl apply -k k8s/overlays/development

# 3. Wait for databases
kubectl wait --for=condition=ready pod -l app=postgres -n newsblur --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongo -n newsblur --timeout=300s

# 4. Restore data
kubectl exec -i -n newsblur postgres-0 -- psql -U newsblur newsblur < postgres-backup.sql
kubectl exec -i -n newsblur mongo-0 -- mongorestore --port 29019 --archive < mongo-backup.archive

# 5. Run migrations (if needed)
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py migrate

# 6. Restart apps
kubectl rollout restart deployment -n newsblur
```

### Blue-Green Deployment

```bash
# Label current deployment as "blue"
kubectl label deployment newsblur-web -n newsblur version=blue

# Create green deployment (with new image)
kubectl create deployment newsblur-web-green -n newsblur --image=newsblur/newsblur_python3:v2

# Scale green
kubectl scale deployment newsblur-web-green -n newsblur --replicas=3

# Wait for green to be ready
kubectl wait --for=condition=ready pod -l app=newsblur-web-green -n newsblur

# Switch service to green
kubectl patch service newsblur-web -n newsblur -p '{"spec":{"selector":{"app":"newsblur-web-green"}}}'

# Verify traffic is working
# If issues, rollback:
kubectl patch service newsblur-web -n newsblur -p '{"spec":{"selector":{"app":"newsblur-web"}}}'

# If all good, delete blue:
kubectl delete deployment newsblur-web -n newsblur
kubectl label deployment newsblur-web-green -n newsblur version=blue app=newsblur-web
```

## Performance Tuning Examples

### Optimize Resource Limits

```bash
# Check current resource usage
kubectl top pods -n newsblur

# Update resources for web
kubectl set resources deployment newsblur-web -n newsblur \
  --requests=cpu=500m,memory=512Mi \
  --limits=cpu=2000m,memory=2Gi

# Update resources for celery
kubectl set resources deployment task-celery -n newsblur \
  --requests=cpu=250m,memory=512Mi \
  --limits=cpu=1000m,memory=2Gi
```

### Configure Pod Disruption Budget

```bash
# Ensure at least 1 web pod is always available
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: newsblur-web-pdb
  namespace: newsblur
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: newsblur-web
EOF

# Ensure at least 50% of pods are available during updates
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: newsblur-node-pdb
  namespace: newsblur
spec:
  maxUnavailable: 50%
  selector:
    matchLabels:
      app: newsblur-node
EOF
```

### Configure Resource Quotas

```bash
# Set namespace resource quotas
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: newsblur-quota
  namespace: newsblur
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    persistentvolumeclaims: "10"
EOF

# Check quota usage
kubectl describe resourcequota newsblur-quota -n newsblur
```

This collection of examples should help you get started with common operations. For more details, see the main [README.md](README.md).
