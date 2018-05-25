#!/bin/bash -e
source /tmp/.env

# The database may need to start up for a bit first
if [ -n "${INTENTIONALLY_SLEEP}" ]; then
  echo "Intentionally sleeping ${INTENTIONALLY_SLEEP}"
  sleep ${INTENTIONALLY_SLEEP}
fi

if [ -n "${DATABASE_INITIAL_CONNECT_MAX_RETRIES}" ]; then
  max=${DATABASE_INITIAL_CONNECT_MAX_RETRIES}
  count=0
  while ! rake database_test:ping > /dev/null 2>&1 && [[ $count -le $max ]] ; do
    count=$[$count+1]
    echo "Retry $count of $max attempting to connect to $DATABASE_HOST. Sleeping ${DATABASE_INITIAL_CONNECT_SLEEP:5}"
    sleep ${DATABASE_INITIAL_CONNECT_SLEEP:5}
  done
fi

# We may need to try and create a database
if [ -z "${DO_NOT_CREATE_DATABASE}" ]; then
  bundle exec rake db:create
fi

# Assuming we have a created database, run the migrations and seed it idempotently.
if [ -z "${DO_NOT_MIGRATE}" ]; then
  bundle exec rake db:migrate
fi

if [ -z "${DO_NOT_SEED}" ]; then
  bundle exec rake db:seed
fi

# Start huginn
exec bundle exec foreman start
