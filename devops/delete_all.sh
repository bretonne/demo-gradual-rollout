#!/bin/bash
kubectl delete deploy/hello-v1 -n kubecon-demo
kubectl delete deploy/hello-v2 -n kubecon-demo
kubectl delete svc/hello -n kubecon-demo
kubectl delete vs/hello -n kubecon-demo
kubectl delete gateway/hello-gateway -n kubecon-demo
kubectl delete destinationrule/hello-dest -n kubecon-demo
