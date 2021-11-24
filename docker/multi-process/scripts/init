#!/bin/bash
set -e

cd /app

# Cleanup any leftover pid file
if [ -f /app/tmp/pids/server.pid ]; then
  rm /app/tmp/pids/server.pid
fi

source /scripts/setup_env

# Fixup the Procfile and prepare the PORT
if [ -n "${DO_NOT_RUN_JOBS}" ]; then
  sed -i -e 's/^jobs:/#jobs:/' /app/Procfile
fi

sed -i -e "s/\${IP-0.0.0.0}/$IP/" -e "s/\${PORT-3000}/$PORT/" /app/Procfile

# start supervisord
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
