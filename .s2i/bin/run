#!/bin/bash

set -e

if [[ "$DATABASE_HOST" =~ '_SERVICE_HOST' ]]; then
    DATABASE_HOST=$(echo "$DATABASE_HOST" | tr '[:lower:]' '[:upper:]')
    export DATABASE_HOST=${!DATABASE_HOST}
    echo "---> DATABASE_HOST: ${DATABASE_HOST} ..."
fi

if [[ "$DATABASE_PORT" =~ '_SERVICE_PORT' ]]; then
    DATABASE_PORT=$(echo "$DATABASE_PORT" | tr '[:lower:]' '[:upper:]')
    export DATABASE_PORT=${!DATABASE_PORT}
    echo "---> DATABASE_PORT: ${DATABASE_PORT} ..."
fi

if [ -z "${DO_NOT_CREATE_DATABASE}" ]; then
    echo "---> Creating database ..."
    bundle exec rake db:create
fi

if [ -z "${DO_NOT_MIGRATE}" ]; then
    echo "---> Migrating database ..."
    bundle exec rake db:migrate
fi

if [ -z "${DO_NOT_SEED}" ]; then
    echo "---> Seeding database ..."
    set +e
    bundle exec rake db:seed
    set -e
fi

# Configure the unicorn server
mv config/unicorn.rb.example config/unicorn.rb
sed -ri 's/^listen .*$/listen ENV["PORT"]/' config/unicorn.rb
sed -ri 's/^stderr_path.*$//' config/unicorn.rb
sed -ri 's/^stdout_path.*$//' config/unicorn.rb

export RACK_ENV=${RACK_ENV:-"production"}

WORKER_CMD="${WORKER_CMD:-"unicorn -c ./deployment/heroku/unicorn.rb --listen 0.0.0.0:8080"}"

echo "---> Executing command: ${WORKER_CMD}"
exec bundle exec ${WORKER_CMD}
