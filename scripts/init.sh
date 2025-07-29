#!/bin/bash

set -euo pipefail

# --- CONFIGURABLE VALUES ---
CLUSTER_NAME="cellint"
GITHUB_REPO_URL="https://github.com/victorswed/cellit.git"
GITHUB_REPO_PATH="infra/"        # Path ArgoCD should watch
GITHUB_REVISION="HEAD"           # Can be 'main', 'master', or a commit
ARGOCD_NAMESPACE="argocd"
ARGOCD_APPS_NAMESPACE="argocd"
# ---------------------------





# if ! command -v k3d >/dev/null 2>&1; then
#   echo "⏬ Installing k3d..."
#   brew install k3d
# fi


# echo "🚀 creating k3d ."
# k3d cluster create $CLUSTER_NAME --api-port 6443 -p "8080:80@loadbalancer" -p "8443:443@loadbalancer" --agents 2

# echo "✅ k3d cluster created!"
kubectl get nodes

echo "📦 Ensuring Helm is installed..."
if ! command -v helm >/dev/null 2>&1; then
  echo "⏬ Installing Helm..."
  brew install helm
fi

echo "📦 Adding Argo Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "📦 Creating Argo CD namespace..."
kubectl create namespace ${ARGOCD_NAMESPACE} || true

echo "🛠️ Installing Argo CD via Helm..."
helm upgrade --install argocd argo/argo-cd \
  --namespace ${ARGOCD_NAMESPACE} \
  --set server.service.type=ClusterIP \
  --set configs.params."server\.insecure"="true"

echo "⏳ Waiting for Argo CD to be ready..."
kubectl rollout status deployment/argocd-server -n ${ARGOCD_NAMESPACE} --timeout=180s

echo "🔐 Fetching Argo CD admin password:"
ARGO_PASS=$(kubectl get secret argocd-initial-admin-secret -n ${ARGOCD_NAMESPACE} -o jsonpath="{.data.password}" | base64 --decode)
echo "🔑 ArgoCD UI Password: $ARGO_PASS"
echo "📡 Port-forward UI: kubectl port-forward svc/argocd-server -n ${ARGOCD_NAMESPACE} 8080:80"

echo ""
echo "🌱 Creating ArgoCD bootstrap Application pointing to GitHub..."

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bootstrap
  namespace: ${ARGOCD_NAMESPACE}
spec:
  project: default
  source:
    repoURL: ${GITHUB_REPO_URL}
    targetRevision: ${GITHUB_REVISION}
    path: ${GITHUB_REPO_PATH}
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

echo "✅ Done! Argo CD is now watching your GitHub repo: ${GITHUB_REPO_URL}, path: ${GITHUB_REPO_PATH}"

echo ""
echo "🎯 Next Steps:"
echo "- Push your Helm charts and Argo Application manifests to ${GITHUB_REPO_PATH}"
echo "- Open Argo UI at http://localhost:8080 (after running: kubectl port-forward svc/argocd-server -n argocd 8080:80)"
echo "- Login with username 'admin' and password above"
