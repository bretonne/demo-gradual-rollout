# demo-gradual-rollout

This project can be set up locally

# Prerequisites
This project installs kind, istio, kiali.  It also needs to have Docker.

## Install kind
```bash
  brew install kind
```

Verify kind installation
```bash
  kind version
```
## Create a cluster
```bash
  kind create cluster --name demo-cluster
```

## Set context to the new cluster
```bash
  kubectl cluster-info --context kind-demo-cluster
```


## Install Istio
```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.*
export PATH=$PWD/bin:$PATH
```

Verify istioctl installation
```bash
  istioctl version
```

```bash
  istioctl install --set profile=demo -y
```

## Enable automatic sidecar injection for the demo namespace

Create a namespace
```bash
  kubectl create namespace demo
```

```bash
kubectl label namespace demo istio-injection=enabled
```

## Install kiali
```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/addons/kiali.yaml
```

Verify kiali installation
```bash
  kubectl get pods -n istio-system
```
You should see kiali and prometheus pods running.

## Access kiali dashboard
```bash
  istioctl dashboard kiali
```

# Initial Setup
## Deploy the initial version of the application
```bash
    cd devops
    ./build-and-deploy.sh
