# NewsBlur Kubernetes Documentation Index

Welcome to the NewsBlur Kubernetes deployment documentation. This index helps you navigate all available resources.

## 📚 Documentation

### Getting Started
- **[QUICKSTART.md](QUICKSTART.md)** - Get NewsBlur running on Kubernetes in 5 minutes
- **[README.md](README.md)** - Comprehensive deployment guide and reference

### Advanced Topics
- **[EXAMPLES.md](EXAMPLES.md)** - Common operations and real-world examples
- **[MIGRATION.md](MIGRATION.md)** - Migrating from Docker Compose to Kubernetes
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Debugging and fixing common issues

### Deployment Files
- **[deploy.sh](deploy.sh)** - Automated deployment script
- **[cleanup.sh](cleanup.sh)** - Cleanup script for removing deployment
- **[test-deployment.sh](test-deployment.sh)** - Validation and testing script

## 🗂️ Directory Structure

```
k8s/
├── base/                          # Base Kubernetes manifests
│   ├── apps/                      # Application deployments
│   │   ├── newsblur-web.yaml     # Django web application
│   │   ├── newsblur-node.yaml    # Node.js services
│   │   ├── celery.yaml            # Celery task workers
│   │   ├── imageproxy.yaml        # Image proxy service
│   │   └── nginx.yaml             # Nginx static file server
│   ├── databases/                 # Database StatefulSets
│   │   ├── postgres.yaml          # PostgreSQL database
│   │   ├── mongodb.yaml           # MongoDB database
│   │   ├── redis.yaml             # Redis cache
│   │   └── elasticsearch.yaml     # Elasticsearch search
│   ├── config/                    # Configuration resources
│   │   ├── configmap.yaml         # Application configuration
│   │   └── secrets.yaml           # Sensitive data (passwords, keys)
│   ├── namespace.yaml             # Namespace definition
│   ├── ingress.yaml               # External access configuration
│   └── kustomization.yaml         # Base kustomization file
├── overlays/                      # Environment-specific configs
│   ├── development/               # Development environment
│   │   ├── kustomization.yaml     # Dev overlay config
│   │   ├── configmap-patch.yaml   # Dev config overrides
│   │   └── resources-patch.yaml   # Dev resource limits
│   └── production/                # Production environment
│       ├── kustomization.yaml     # Prod overlay config
│       └── replicas-patch.yaml    # Prod replica counts
└── helm/                          # Helm chart (future)
    ├── README.md                  # Helm documentation
    └── newsblur/                  # Chart structure
        ├── Chart.yaml             # Chart metadata
        └── templates/             # Template directory
```

## 🚀 Quick Reference

### Essential Commands

```bash
# Deploy
./deploy.sh development

# Initialize database
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py migrate
kubectl exec -n newsblur -it deployment/newsblur-web -- ./manage.py loaddata config/fixtures/bootstrap.json

# Access application
kubectl port-forward -n newsblur service/nginx 8080:81

# View logs
kubectl logs -n newsblur -l app=newsblur-web -f

# Shell access
kubectl exec -n newsblur -it deployment/newsblur-web -- bash

# Cleanup
./cleanup.sh development
```

## 📋 Resource Overview

### Applications (Deployments)

| Name | Purpose | Port | Replicas (Dev) | Replicas (Prod) |
|------|---------|------|----------------|-----------------|
| newsblur-web | Django web app | 8000 | 1 | 3 |
| newsblur-node | Node.js services | 8008 | 1 | 2 |
| task-celery | Background tasks | - | 1 | 2 |
| imageproxy | Image proxying | 8088 | 1 | 1 |
| nginx | Static files | 81 | 1 | 2 |

### Databases (StatefulSets)

| Name | Type | Port | Storage |
|------|------|------|---------|
| postgres | PostgreSQL 13.1 | 5432 | 10Gi |
| mongo | MongoDB 4.0 | 29019 | 20Gi |
| redis | Redis Latest | 6579 | 5Gi |
| elasticsearch | Elasticsearch 8.17.0 | 9200 | 10Gi |

### Configuration

| Name | Type | Purpose |
|------|------|---------|
| newsblur-config | ConfigMap | Application settings |
| newsblur-secrets | Secret | Passwords and API keys |
| redis-config | ConfigMap | Redis configuration |
| nginx-config | ConfigMap | Nginx configuration |

## 🎯 Use Cases

### I want to...

- **Deploy for the first time**
  → Read [QUICKSTART.md](QUICKSTART.md)

- **Understand the architecture**
  → Read [README.md](README.md) § Architecture

- **Migrate from Docker Compose**
  → Read [MIGRATION.md](MIGRATION.md)

- **Scale the application**
  → Read [EXAMPLES.md](EXAMPLES.md) § Scaling

- **Debug a problem**
  → Read [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

- **Set up monitoring**
  → Read [EXAMPLES.md](EXAMPLES.md) § Monitoring

- **Configure HTTPS**
  → Read [EXAMPLES.md](EXAMPLES.md) § HTTPS with Let's Encrypt

- **Back up data**
  → Read [EXAMPLES.md](EXAMPLES.md) § Backup and Restore

- **Deploy to production**
  → Read [README.md](README.md) § Production Deployment

- **Customize configuration**
  → Read [README.md](README.md) § Configuration

## 🔧 Troubleshooting Quick Links

### Common Issues

- [Pods Not Starting](TROUBLESHOOTING.md#pods-stuck-in-pending)
- [Database Connection Issues](TROUBLESHOOTING.md#database-connection-issues)
- [Ingress Not Working](TROUBLESHOOTING.md#ingress-not-working)
- [Storage Issues](TROUBLESHOOTING.md#pvc-stuck-in-pending)
- [Performance Problems](TROUBLESHOOTING.md#high-cpu-usage)

## 📊 Comparison Tables

### vs Docker Compose

| Feature | Docker Compose | Kubernetes |
|---------|----------------|------------|
| Setup Complexity | Low | Medium |
| Scalability | Limited | Excellent |
| High Availability | No | Yes |
| Resource Management | Basic | Advanced |
| Multi-environment | Manual | Native |
| Production Ready | No | Yes |

See [MIGRATION.md](MIGRATION.md) for detailed comparison.

## 🌟 Features

✅ **StatefulSets** for databases with persistent storage  
✅ **PersistentVolumeClaims** for data persistence  
✅ **ConfigMaps & Secrets** for configuration management  
✅ **Services** for internal communication  
✅ **Ingress** for external access with path-based routing  
✅ **Health Checks** with liveness and readiness probes  
✅ **Resource Limits** for CPU and memory  
✅ **Init Containers** for dependency management  
✅ **Multiple Environments** (development and production overlays)  
✅ **Kustomize Support** for easy customization  
✅ **Helm Ready** structure for future chart development  

## 📖 External Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [Helm Documentation](https://helm.sh/docs/)
- [NewsBlur Repository](https://github.com/samuelclay/NewsBlur)
- [Docker Compose Setup](../docker-compose.yml)

## 🤝 Contributing

When contributing to the Kubernetes deployment:

1. Test changes with `./test-deployment.sh`
2. Update relevant documentation
3. Test both development and production overlays
4. Ensure backward compatibility
5. Document breaking changes

## 📝 Version History

- **v1.0.0** (Current) - Initial Kubernetes deployment based on docker-compose.yml
  - Complete deployment manifests
  - Development and production overlays
  - Comprehensive documentation
  - Automated deployment scripts

## 💬 Support

For help with Kubernetes deployment:

1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review [EXAMPLES.md](EXAMPLES.md) for similar use cases
3. Search existing [GitHub Issues](https://github.com/samuelclay/NewsBlur/issues)
4. Open a new issue with:
   - Kubernetes version (`kubectl version`)
   - Cluster type (minikube, GKE, EKS, etc.)
   - Relevant logs and error messages
   - Steps to reproduce

---

**Last Updated:** 2025-10-20  
**Kubernetes Version:** 1.19+  
**Maintained by:** NewsBlur Contributors
