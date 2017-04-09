#!/usr/bin/env zsh

set -ex

FILE="docker-compose.mysql.yml"
PROJECT="huginn-mysql-test"

if [[ -z "$@" ]]; then
  exec docker-compose --file "$FILE" --project-name "$PROJECT" up --build
else
  exec docker-compose --file "$FILE" --project-name "$PROJECT" $@
fi
