# NewsBlur Helm Chart

This directory contains a Helm chart structure for deploying NewsBlur on Kubernetes.

> **Note:** This is a placeholder for future Helm chart development. For now, please use the Kustomize-based deployment in the parent directory (`k8s/`).

## Current Status

The Helm chart structure is provided as a starting point. To use NewsBlur on Kubernetes today:

1. Use the Kustomize-based deployment: `kubectl apply -k overlays/development`
2. Follow the [k8s/README.md](../README.md) for detailed instructions
3. Use the [k8s/QUICKSTART.md](../QUICKSTART.md) for a quick start

## Future Development

A complete Helm chart with templates and values is planned for a future release. Contributions are welcome!

To contribute:
1. Create templates in `newsblur/templates/`
2. Define values in `newsblur/values.yaml`
3. Test with `helm template` and `helm lint`
4. Submit a pull request

## Why Kustomize First?

We've prioritized Kustomize because:
- Native kubectl integration
- Simpler for getting started
- More transparent YAML patches
- Based directly on docker-compose.yml

Helm will be added later for users who prefer package management features.
