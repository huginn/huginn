#!/usr/bin/env zsh

cd ..
pwd

# Build huginn ng
docker build -f ./docker/Dockerfile.ng -t huginn-ng-test .
exec docker run --name huginn-ng-test --rm -it huginn-ng-test
