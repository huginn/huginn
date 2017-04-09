#!/usr/bin/env sh
set -ex

export LC_ALL=en_US.UTF-8

cd $HUGINN_HOME

suIfRequired () {
  if [ "$(whoami)" == "$HUGINN_USER" ]; then
    $@
  else
    su-exec $HUGINN_USER $@
  fi
}

# TODO: Determine correct database based on configured variable (redmine style)
# REDMINE_DB_MYSQL: db
# REDMINE_DB_POSTGRES: db
# TODO: From that, we know the host, db type, can set the default port (if not overriden), etc

# Legacy: Configure database based on linked container
if [ -n "${MYSQL_PORT_3306_TCP_ADDR}" ]; then
  DATABASE_ADAPTER=${DATABASE_ADAPTER:-mysql2}
  DATABASE_HOST=${DATABASE_HOST:-${MYSQL_PORT_3306_TCP_ADDR}}
  DATABASE_PORT=${DATABASE_PORT:-${MYSQL_PORT_3306_TCP_PORT}}
  DATABASE_ENCODING=${DATABASE_ENCODING:-utf8mb4}
elif [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
  DATABASE_ADAPTER=${DATABASE_ADAPTER:-postgresql}
  DATABASE_HOST=${DATABASE_HOST:-${POSTGRES_PORT_5432_TCP_ADDR}}
  DATABASE_PORT=${DATABASE_PORT:-${POSTGRES_PORT_5432_TCP_PORT}}
  DATABASE_ENCODING=utf8
fi

USE_GRAPHVIZ_DOT=${USE_GRAPHVIZ_DOT:-${USE_GRAPHVIZ_DOT:-dot}}

# Default to the environment variable values set in .env.example
# IFS="="
# grep = "/$HUGINN_HOME/.env.example" | sed -e 's/^#\([^ ]\)/\1/' | grep -v -e '^#' | \
#   while read var value ; do
#     eval "echo \"$var=\${$var:-\${HUGINN_$var-\$value}}\""
#   done | grep -v -e ^= > /app/.env

# eval "echo PORT=${PORT:-${PORT:-3000}}" >> .env
# eval "echo RAILS_ENV=${RAILS_ENV:-${RAILS_ENV:-production}}" >> .env
# eval "echo RAILS_LOG_TO_STDOUT=true" >> .env
# eval "echo RAILS_SERVE_STATIC_FILES=true" >> .env

# chmod ugo+r "/$HUGINN_HOME/.env"
# source "/$HUGINN_HOME/.env"

# use default port number if it is still not set
case "${DATABASE_ADAPTER}" in
  mysql2) DATABASE_PORT=${DATABASE_PORT:-3306} ;;
  postgresql) DATABASE_PORT=${DATABASE_PORT:-5432} ;;
  *) echo "Unsupported database adapter. Available adapters are mysql2, and postgresql." && exit 1 ;;
esac

#su-exec huginn bundle install --without test development --path vendor/bundle

if [ -z $1 ]; then
  suIfRequired bundle exec rake db:create db:migrate
fi

# TODO: Do we need to explicitly pass rails_env through to unicorn? There is a -E flag that talks about this..

if [[ -z "${DO_NOT_SEED}" && -z $1 ]]; then
  suIfRequired bundle exec rake db:seed
  #RAILS_ENV=${RAILS_ENV}
fi

if [ -z $1 ]; then
  suIfRequired bundle exec unicorn -c config/unicorn.rb
else
  suIfRequired bundle exec rails runner "$@" 
  #RAILS_ENV=${RAILS_ENV}
fi
# TODO: We should be calling 'exec' here to pass to unicorn properly..