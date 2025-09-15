# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a GitOps-based DevOps platform with the following architecture:

- **Core Application**: DevHub - a simple developer portal for submitting and tracking mock dev environment orders
  - Frontend: Static HTML/CSS/JS served from nginx
  - Backend: FastAPI Python service with MongoDB persistence
  - Deployment: Containerized and deployed via Helm charts

- **Infrastructure**: Kubernetes-native GitOps setup
  - ArgoCD for continuous deployment watching GitHub repo
  - Istio service mesh for traffic management and ingress
  - Argo Workflows for CI/CD automation
  - Monitoring stack with Grafana, Loki, Victoria Metrics, OpenTelemetry

## Key Commands

### Cluster Setup
```bash
# Initialize cluster with ArgoCD and bootstrap GitOps
./scripts/init.sh
```

### DevHub Application Development
```bash
# Backend (FastAPI)
cd apps/devhub/backend
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Frontend (Static)
cd apps/devhub/frontend
# Serve with any HTTP server, e.g.:
python -m http.server 3000
```

### Container Management
```bash
# Build and push backend
docker build -t docker.io/victor1721swed/cellit-backend:latest apps/devhub/backend/
docker push docker.io/victor1721swed/cellit-backend:latest

# Build and push frontend  
docker build -t docker.io/victor1721swed/cellit-frontend:latest apps/devhub/frontend/
docker push docker.io/victor1721swed/cellit-frontend:latest
```

### ArgoCD Management
```bash
# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode
```

## Deployment Flow

1. Code changes pushed to GitHub trigger ArgoCD sync
2. ArgoCD deploys Helm charts from `apps/devhub/charts/devhub/`
3. Applications are deployed to `devhub` namespace
4. Istio provides ingress and traffic routing
5. Monitoring observes application health

## Configuration

- Helm values: `apps/devhub/charts/devhub/values.yaml`
- ArgoCD app definition: `infra/apps/devhub.yaml`
- Container images stored in Docker Hub under `victor1721swed/` namespace
- MongoDB connection configured via environment variables in deployment