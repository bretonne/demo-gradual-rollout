#!/bin/bash
set -e

APP_NAME="hello"
VERSION=$1
if [ -z "$VERSION" ]; then
  echo "Usage: ./deploy.sh <version>"
  exit 1
fi

# Tag docker image with version
docker build -t ${APP_NAME}:${VERSION} . --build-arg VERSION=${VERSION}
kind load docker-image ${APP_NAME}:${VERSION} --name demo-cluster

# Export variables for envsubst
export VERSION=${VERSION}
export IMAGE_TAG=${VERSION}

# Apply manifests with substituted values
envsubst < k8s/hello-app.yaml | kubectl apply -n kubecon-demo -f -
kubectl apply -f k8s/istio.yaml
