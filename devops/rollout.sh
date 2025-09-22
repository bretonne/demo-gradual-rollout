#!/bin/bash
set -e

APP_NAME="hello"
VERSION=$1
if [ -z "$VERSION" ]; then
  echo "Usage: ./deploy.sh <version>"
  exit 1
fi

# namespace and virtualservice template (ensure defined before use)
NAMESPACE="kubecon-demo"
VS_TEMPLATE="k8s/istio-virtual-service-rollout.yaml"

# Tag docker image with version
docker build -t ${APP_NAME}:${VERSION} . --build-arg VERSION=${VERSION}
kind load docker-image ${APP_NAME}:${VERSION} --name demo-cluster

# Export variables for envsubst
export VERSION=${VERSION}
export IMAGE_TAG=${VERSION}

# Apply manifests with substituted values
envsubst < k8s/hello-app.yaml | kubectl apply -n kubecon-demo -f -
kubectl apply -f k8s/istio.yaml

# --- rollout logic: gradually shift traffic to the deployed version ---
# apply virtualservice using envsubst (expects ${V1_WEIGHT} and ${V2_WEIGHT})

apply_vs() {
  local v2_weight=$1
  local v1_weight=$((100 - v2_weight))
  export V1_WEIGHT=${v1_weight}
  export V2_WEIGHT=${v2_weight}

  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) Applying VirtualService: v2=${V2_WEIGHT}% v1=${V1_WEIGHT}%"

  # generate the VirtualService manifest to a temp file so we can print it before applying
  tmpfile=$(mktemp)
  envsubst < "${VS_TEMPLATE}" > "${tmpfile}"
  sed -n '1,200p' "${tmpfile}"

  kubectl apply -n ${NAMESPACE} -f "${tmpfile}"
  rm -f "${tmpfile}"

  # Optional: Here should run automated functional tests
  # if passed; then continue; else rollback and exit 1; fi
}

# handle Ctrl-C to stop the rollout script safely
on_interrupt() {
  echo "Interrupted. Exiting rollout loop."
  exit 1
}
trap on_interrupt SIGINT SIGTERM

# Start rollout: initial 10% for 30 minutes, then increment by 10% every 15 minutes
START=10
STEP=10
HOLD_FIRST_SECONDS=$((60)) #seconds
HOLD_AFTER_SECONDS=$((15))

# Apply initial step
apply_vs ${START}

echo "Holding at ${START}% for $((HOLD_FIRST_SECONDS/60)) minutes..."
sleep ${HOLD_FIRST_SECONDS}

# Continue from next step up to 100%
current=$((START + STEP))
while [ ${current} -le 100 ]; do
  apply_vs ${current}
  if [ ${current} -eq 100 ]; then
    echo "Reached 100% for ${VERSION}. Rollout complete."
    break
  fi
  echo "Holding at ${current}% for $((HOLD_AFTER_SECONDS/60)) minutes..."
  sleep ${HOLD_AFTER_SECONDS}
  current=$((current + STEP))
done
