#!/bin/bash
set -ev

bin/docker_wrapper build -t $DOCKER_IMAGE -f $DOCKERFILE .

if [[ -n "${DOCKER_USER}" && "${TRAVIS_PULL_REQUEST}" = 'false' && "${TRAVIS_BRANCH}" = "master" ]]; then
  docker login -u $DOCKER_USER -p $DOCKER_PASS
  docker tag $DOCKER_IMAGE $DOCKER_IMAGE:$TRAVIS_COMMIT
  docker push $DOCKER_IMAGE
  docker push $DOCKER_IMAGE:$TRAVIS_COMMIT
else
  echo "Docker image are only pushed for builds of the master branch when Docker Hub credentials are present."
fi

if [[ $DOCKER_IMAGE == "huginn/huginn-single-process" ]]; then
  DOCKER_IMAGE=huginn/huginn-test DOCKERFILE=docker/test/Dockerfile ./build_docker_image.sh
fi
