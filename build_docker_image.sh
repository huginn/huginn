#!/bin/bash
set -ev

docker pull $DOCKER_IMAGE
docker build -t $DOCKER_IMAGE -f $DOCKERFILE .

if [[ -n "${DOCKER_USER}" && "${TRAVIS_PULL_REQUEST}" = 'false' && "${TRAVIS_BRANCH}" = "master" ]]; then
  docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS
  docker tag $DOCKER_IMAGE $DOCKER_IMAGE:$TRAVIS_COMMIT
  docker push $DOCKER_IMAGE
  docker push $DOCKER_IMAGE:$TRAVIS_COMMIT
else
  echo "Docker image are only pushed for builds of the master branch when Docker Hub credentials are present."
fi
