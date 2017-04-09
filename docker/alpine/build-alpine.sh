#!/usr/bin/env zsh

cd ../..
pwd

FILE="./docker/alpine/Dockerfile"
TAG="huginn-alpine"
NAME="huginn-alpine"

docker build --file "$FILE" --tag "$TAG" .
exec docker run --name "$NAME" --rm -it "$TAG"
