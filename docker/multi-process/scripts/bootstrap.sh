#!/bin/bash -e
source /tmp/.env

echo DATABASE_HOST=${DATABASE_HOST}

# start mysql server if ${DATABASE_HOST} is the .env.example default
if [ "${START_MYSQL}" = "true" ]; then
  if [ "${DATABASE_ADAPTER}" = "postgresql" ]; then
    echo "DATABASE_ADAPTER 'postgresql' is not supported internally. Please provide DATABASE_HOST."
    exit 1
  fi

  # initialize MySQL data directory
  if [ ! -d /var/lib/mysql/mysql ]; then
    mysqld --initialize-insecure --user=$(whoami) --datadir=/tmp/mysql
    mv -f /tmp/mysql/* /var/lib/mysql/
  fi

  echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DATABASE_PASSWORD}';" > /app/tmp/mysql_init.sql

  echo "Starting mysql server..."
  supervisorctl start mysqld >/dev/null

  # wait for mysql server to start (max 120 seconds)
  timeout=120
  while ! mysqladmin -u root status >/dev/null 2>&1 && ! mysqladmin -u root --password="${DATABASE_PASSWORD}" status >/dev/null 2>&1
  do
    (( timeout = timeout - 1 ))
    if [ $timeout -eq 0 ]; then
      echo "Failed to start mysql server"
      exit 1
    fi
    echo -n .
    sleep 1
  done
fi

supervisorctl start foreman >/dev/null
