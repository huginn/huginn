#!/bin/bash
set -e

: ${DOCKER_IMAGE:=huginn/huginn}
: ${DOCKER_IMAGE_TAG:=${GITHUB_SHA:-$(git rev-parse HEAD)}}
: ${DOCKERFILE:=docker/multi-process/Dockerfile}

docker build $BUILD_ARGS -t "$DOCKER_IMAGE" -f "$DOCKERFILE" .

if [[ "$1" == --push ]]; then
  [[ -n "$DOCKER_USER" && -n "$DOCKER_IMAGE_TAG" ]]
  docker login -u "$DOCKER_USER" -p "$DOCKER_PASS" "$REGISTRY"
  docker tag "$DOCKER_IMAGE" "$DOCKER_IMAGE:$DOCKER_IMAGE_TAG"
  docker push "$DOCKER_IMAGE"
  docker push "$DOCKER_IMAGE:$DOCKER_IMAGE_TAG"
fi

if [[ "$DOCKER_IMAGE" == *huginn/huginn-single-process ]]; then
  DOCKER_IMAGE=huginn/huginn-test DOCKERFILE=docker/test/Dockerfile ./build_docker_image.sh
fi
