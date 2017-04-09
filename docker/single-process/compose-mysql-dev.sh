#!/usr/bin/env zsh

set -ex

FILE="docker-compose.mysql.dev.yml"
PROJECT="huginn-single-process-mysql-dev"

if [[ -z "$@" ]]; then
  exec docker-compose --file "$FILE" --project-name "$PROJECT" up --build
else
  exec docker-compose --file "$FILE" --project-name "$PROJECT" $@
fi
