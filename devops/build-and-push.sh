#!/usr/bin/env bash
set -e

DOCKER_USER=bretonne
IMAGE_NAME="${DOCKER_USER}/rollout-demo-app"

# build/push v1 (Dockerfile is one level up; build context is repo root)
docker build -f ../Dockerfile -t "${IMAGE_NAME}:v1" ..
docker push "${IMAGE_NAME}:v1"

# replace index.html with v2 version, then:
# docker build -f ../Dockerfile -t "${IMAGE_NAME}:v2" ..
# docker push "${IMAGE_NAME}:v2"
