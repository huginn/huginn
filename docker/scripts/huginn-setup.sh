#!/usr/bin/env sh
set -ex

# Setup the appropraite directories, etc
mkdir -p "$HUGINN_HOME/tmp/pids"
mkdir -p "$HUGINN_HOME/tmp/sockets"
mkdir -p "$HUGINN_HOME/tmp/cache" # TODO: Is this required?
mkdir -p "$HUGINN_HOME/log"
touch "$HUGINN_HOME/log/production.log"

# HACK: Restore these from previous build so we don't overwrite the sqlite gem..
mv Gemfile.bak Gemfile
mv Gemfile.lock.bak Gemfile.lock

# HACK: We need a database connection to precompile the assets, use sqlite for that
#&& cp Gemfile Gemfile.bak \
#&& echo "gem 'sqlite3', '~> $SQLITE_VERSION'" >> "$HUGINN_HOME/Gemfile" \
#&& RAILS_ENV=production APP_SECRET_TOKEN=secret DATABASE_ADAPTER=sqlite3 ON_HEROKU=true bundle install --without test development --jobs 4 \
RAILS_ENV=production APP_SECRET_TOKEN=secret DATABASE_ADAPTER=sqlite3 ON_HEROKU=true bundle exec rake assets:clean assets:precompile

# TODO: This probably isn't needed here.. but copied in in case so we don't lose it from the setup file
# Bundle again to get rid of the sqlite3 gem
#&& cp Gemfile.bak Gemfile \
#&& RAILS_ENV=production APP_SECRET_TOKEN=secret ON_HEROKU=true bundle install --without test development --jobs 4 \
#&& INSTALL_ALL_DATABASE_ADAPTERS=true bundle install --without test development --jobs 4 \

# Configure the unicorn server
mv config/unicorn.rb.example config/unicorn.rb
sed -ri 's/^listen .*$/listen ENV["PORT"]/' config/unicorn.rb
sed -ri 's/^stderr_path.*$//' config/unicorn.rb
sed -ri 's/^stdout_path.*$//' config/unicorn.rb

# Add ENV variables to .env.example which are not present in it but usable
cat >> "$HUGINN_HOME/.env.example" <<EOF
ASSET_HOST=
DEFAULT_SCENARIO_FILE=
RAILS_SERVE_STATIC_FILES=
SEED_EMAIL=
SEED_PASSWORD=
SEED_USERNAME=
SMTP_OPENSSL_CA_FILE=
SMTP_OPENSSL_CA_PATH=
SMTP_OPENSSL_VERIFY_MODE=
EOF

chown -R $HUGINN_USER:$HUGINN_GROUP "$HUGINN_HOME"

# Cleanup docker scripts passed through.. they will still be at $SCRIPTS_HOME
rm -rf "$HUGINN_HOME/docker"