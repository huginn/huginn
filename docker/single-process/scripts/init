#!/bin/bash
set -e

cd /app

if [[ -z "$1" && -n "$WORKER_CMD" ]]; then
  set -- $WORKER_CMD
fi

source /scripts/setup_env

if [[ -z "${DO_NOT_CREATE_DATABASE}" && -z "$1" ]]; then
  bundle exec rake db:create RAILS_ENV=${RAILS_ENV}
fi

if [ -z "$1" ]; then
  bundle exec rake db:migrate RAILS_ENV=${RAILS_ENV}
fi

if [[ -z "${DO_NOT_SEED}" && -z "$1" ]]; then
  set +e
  bundle exec rake db:seed RAILS_ENV=${RAILS_ENV}
  set -e
fi

if [ -z "$1" ]; then
  exec bundle exec unicorn -c config/unicorn.rb
else
  exec bundle exec rails runner "$@" RAILS_ENV=${RAILS_ENV}
fi
