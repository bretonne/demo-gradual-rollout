#!/usr/bin/env bash
set -euo pipefail

APP_NAME="hello"
CLUSTER_NAME="demo-cluster"
NAMESPACE="kubecon-demo"

# Base dir (repo/frontend)
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="${BASEDIR}/VERSION"
K8S_MANIFEST="${BASEDIR}/k8s/hello-app.yaml"

usage() {
  cat <<EOF
Usage: $(basename "$0") ROUTE

ROUTE must be provided as the single positional argument (example: ./$(basename "$0") v1).
This script does not support bump/version commands or reading ROUTE from the environment.
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

# ROUTE must be provided as the first (and only) positional argument
if [[ -z "${1:-}" ]]; then
  echo "ERROR: ROUTE is required. Example: ./$(basename "$0") v1"
  usage
  exit 1
fi

ROUTE="${1}"
# basic validation: must start with 'v' (e.g. v1, v2)
if [[ ! ${ROUTE} =~ ^v[0-9A-Za-z._-]*$ ]]; then
  echo "ERROR: ROUTE must start with 'v' (e.g. v1). Provided: ${ROUTE}"
  exit 1
fi

# Read VERSION from file (no bump behavior)
if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "ERROR: missing version file: ${VERSION_FILE}"
  exit 1
fi
VERSION="$(cat "${VERSION_FILE}")"

IMAGE_TAG="${APP_NAME}:${VERSION}"

echo "Building Docker image ${IMAGE_TAG} from ${BASEDIR}..."
docker build -t "${IMAGE_TAG}" "${BASEDIR}"

echo "Loading image into kind cluster ${CLUSTER_NAME}..."
kind load docker-image "${IMAGE_TAG}" --name "${CLUSTER_NAME}"

# Export for envsubst
export VERSION IMAGE_TAG ROUTE TIMESTAMP=$(date +%Y%m%d%H%M%S)

echo "Rendering manifest and applying to namespace ${NAMESPACE}..."
apply_output=$(envsubst '$VERSION $IMAGE_TAG $ROUTE $TIMESTAMP' < "${K8S_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f - 2>&1 || true)

echo "$apply_output"

# If unchanged, explicitly set image and label so pods pick up the new image
if echo "$apply_output" | grep -q -i "unchanged"; then
  echo "Manifest reported 'unchanged' — updating deployment image and label explicitly..."
  kubectl set image deployment/hello-${ROUTE} hello="${IMAGE_TAG}" -n "${NAMESPACE}"
  kubectl label deployment/hello-${ROUTE} version="${VERSION}" route="${ROUTE}" -n "${NAMESPACE}" --overwrite
  kubectl rollout restart deployment/hello-${ROUTE} -n "${NAMESPACE}"
fi

# Apply ALL Istio configuration (Gateway, DestinationRule, VirtualService)
echo "Applying Istio configuration..."
kubectl apply -f "${BASEDIR}/k8s/istio.yaml" -n "${NAMESPACE}"
kubectl apply -f "${BASEDIR}/k8s/istio-virtual-service-traffic-control.yaml" -n "${NAMESPACE}"

# Wait for rollout
echo "Waiting for deployment rollout to finish..."
kubectl rollout status deployment/hello-${ROUTE} -n "${NAMESPACE}" --timeout=120s

echo "Deployment complete! Image used: ${IMAGE_TAG}"