#!/bin/bash
set -euo pipefail

APP_NAME="hello"
VERSION=$1
if [ -z "$VERSION" ]; then
  echo "Usage: ./rollout.sh <version>"
  exit 1
fi

# namespace and templates
NAMESPACE="kubecon-demo"
APP_TEMPLATE="k8s/hello-app.yaml"
VS_TEMPLATE="k8s/istio-virtual-service-rollout.yaml"

# Tag docker image with version
docker build -t ${APP_NAME}:${VERSION} . --build-arg VERSION=${VERSION}
kind load docker-image ${APP_NAME}:${VERSION} --name demo-cluster

# Export variables for envsubst
export VERSION=${VERSION}
# ROUTE is used in the Deployment name and labels (hello-${ROUTE})
export ROUTE=${VERSION}
# IMAGE_TAG should be full image name used in the Deployment
export IMAGE_TAG="${APP_NAME}:${VERSION}"
# timestamp for annotation
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
export TIMESTAMP

# Apply manifests with substituted values
envsubst < "${APP_TEMPLATE}" | kubectl apply -n "${NAMESPACE}" -f -
kubectl apply -f k8s/istio.yaml

# --- rollout logic: gradually shift traffic to the deployed version ---
# apply virtualservice using envsubst (expects ${V1_WEIGHT} and ${V2_WEIGHT})

apply_vs() {
  local v1_weight=$1
  local v2_weight=$((100 - v1_weight))
  export V1_WEIGHT=${v1_weight}
  export V2_WEIGHT=${v2_weight}

  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) Applying VirtualService: v2=${V2_WEIGHT}% v1=${V1_WEIGHT}%"

  # generate the VirtualService manifest to a temp file so we can print it before applying
  tmpfile=$(mktemp)
  envsubst < "${VS_TEMPLATE}" > "${tmpfile}"
  echo "--- Generated VirtualService manifest ---"
  sed -n '1,200p' "${tmpfile}"
  echo "--- end manifest ---"

  kubectl apply -n "${NAMESPACE}" -f "${tmpfile}"
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
HOLD_FIRST_SECONDS=$((1 * 60)) # 30 minutes
HOLD_AFTER_SECONDS=$((30)) # 15 minutes

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

# After successful rollout, scale down other version deployments to 0
scale_down_others() {
  echo "Scaling down other 'hello-*' deployments (route != ${ROUTE}) in namespace ${NAMESPACE}..."
  # list deployments with app=hello and their route label
  kubectl get deploy -n "${NAMESPACE}" -l app=hello -o custom-columns=NAME:.metadata.name,ROUTE:.metadata.labels.route --no-headers | \
  while read -r name route; do
    # if route is empty or different from current ROUTE, scale it down
    if [ "${route}" != "${ROUTE}" ]; then
      echo "Scaling ${name} (route=${route:-<none>}) to 0 replicas"
      kubectl scale deployment "${name}" -n "${NAMESPACE}" --replicas=0 || echo "Failed to scale ${name}; continuing"
    fi
  done
}

scale_down_others
