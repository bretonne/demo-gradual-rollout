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
  devops/create-cluster.sh
```

It does the following
 - create a cluster named demo-cluster
 - install istio
 - create namespace
 - Enable automatic sidecar injection for the demo namespace 
 - Install kiali
 - Install kubectl dashboard and create a service account

# Deploy
## Deploy the application
Verify that index.html says v1 text and use lightble background color.  Then deploy it.
```bash
 devops/deploy.sh v1
```
Then change index.html to v2 text and lightgreen background color.  Then deploy it.
```bash
 devops/deploy.sh v2
```

## Test the application

### Confirm Istio ingress gateway is running
```bash
kubectl get pods -n istio-system
```
### Port-forward the ingress gateway

Forward the gateway’s HTTP port (80) to your localhost:
```bash
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
```
### Update /etc/hosts to map hello.local to localhost
add the following line to /etc/hosts
```
127.0.0.1 hello.local
```
Keep this running in a terminal. Now your browser traffic to http://hello.local:8080 will hit the Istio ingress gateway.

# Access kiali dashboard
```bash
  istioctl dashboard kiali
```

# Rollout
```bash
  devops/rollout.sh v1
```

# Access kubernetes dashboard If Preferred
### Get the token
```bash
kubectl -n kubernetes-dashboard create token admin-user
```
Copy the token — you’ll need it for login.

### Access the Dashboard
```bash
kubectl proxy
```

Then open in browser:
👉 http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

Log in using the token you copied.

# Verify Deployment Version:
```bash
kubectl port-forward -n kubecon-demo pod/hello-v1-xxxxx 8081:80
```
In browser go to http://localhost:8081 and you should see "Hello World! v1"

# Troubleshooting with following to bypass istio to see content of pod directly
```bash
kubectl exec -n kubecon-demo hello-v1-abc123 -- cat /usr/share/nginx/html/index.html
```
## Port-forward to a v2 pod
kubectl port-forward -n kubecon-demo pod/hello-v2-abc123 8081:80 &

## Test the v1 pod directly
curl http://localhost:8081

# Other tips
## Make sure Docker Desktop is running

