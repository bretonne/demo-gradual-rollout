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

# Deploy
## Deploy the application
```bash
 devops/deploy.sh v1
 devops/deploy.sh v2
```

## Apply Istio VirtualService for Traffic Routing
```bash
 kubectl apply -f k8s/istio-virtual-service-rollout.yaml
```

# Test the application
## Confirm Istio ingress gateway is running
```bash
kubectl get pods -n istio-system
```
## Port-forward the ingress gateway

Forward the gateway’s HTTP port (80) to your localhost:
```bash
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
```

Keep this running in a terminal. Now your browser traffic to http://localhost:8080 will hit the Istio ingress gateway.


# Optional - Set up kubernetes dashboard
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

### Create a service account
```bash
 kubectl apply -f k8s/dashboard-admin.yaml
```
### Get the token
```bash
kubectl -n kubernetes-dashboard create token admin-user
```
Copy the token — you’ll need it for login.

### Access the Dashboard

kubectl proxy
```bash
kubectl proxy
```

Then open in browser:
👉 http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

Log in using the token you copied.