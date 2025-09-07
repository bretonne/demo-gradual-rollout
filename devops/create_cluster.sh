#!/bin/bash
set -e

# Create kind cluster
echo "[1/6] Creating kind cluster..."
kind create cluster --name demo-cluster || echo "Kind cluster already exists. Skipping."

# Set kubectl context
echo "[2/6] Setting kubectl context..."
kubectl cluster-info --context kind-demo-cluster

# Install Istio
echo "[3/6] Installing Istio..."
if [ ! -d "istio-1."* ]; then
  curl -L https://istio.io/downloadIstio | sh -
fi
cd istio-1.*
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo -y
cd ..

# Create and label namespace
echo "[4/6] Creating and labeling namespace kubecon-demo..."
kubectl create namespace kubecon-demo || echo "Namespace kubecon-demo already exists. Skipping."
kubectl label namespace kubecon-demo istio-injection=enabled --overwrite

# Install Kiali and Prometheus
echo "[5/6] Installing Kiali and Prometheus..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/addons/kiali.yaml

# Install Kubernetes Dashboard
echo "[6/6] Installing Kubernetes Dashboard..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl apply -f k8s/dashboard-admin.yaml

echo "\nCluster setup complete!"

