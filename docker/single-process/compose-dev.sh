#!/usr/bin/env zsh

set -ex

FILE="docker-compose.dev.yml"
PROJECT="huginn-single-dev"

if [[ -z "$@" ]]; then
  exec docker-compose --file "$FILE" --project-name "$PROJECT" up --build
else
  exec docker-compose --file "$FILE" --project-name "$PROJECT" $@
fi
