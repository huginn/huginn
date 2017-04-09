#!/usr/bin/env sh
set -ex

# Hack to avoid "fatal: Not a git repository" from bundler
git init

# Install Gemfile dependencies
#&& chown -R huginn:huginn "$HUGINN_HOME" \
#&& su-exec huginn echo "gem 'sqlite3', '~> $SQLITE_VERSION'" >> "$HUGINN_HOME/Gemfile" \

echo "gem 'sqlite3', '~> $SQLITE_VERSION'" >> "$HUGINN_HOME/Gemfile"
INSTALL_ALL_DATABASE_ADAPTERS=true bundle install --without test development --jobs 4

# TODO: This probably isn't needed here.. but copied in in case so we don't lose it from the setup file
# RAILS_ENV=production APP_SECRET_TOKEN=secret DATABASE_ADAPTER=sqlite3 ON_HEROKU=true bundle install --without test development --path vendor/bundle -j 4
# RAILS_ENV=production APP_SECRET_TOKEN=secret DATABASE_ADAPTER=sqlite3 ON_HEROKU=true bundle exec rake assets:clean assets:precompile

#--deployment # See http://bundler.io/bundle_install.html
#--path vendor/bundle --jobs 4

# HACK: Prevent overwriting this with the later copy.. should we just add the sqlite gem to the gemfile always?
cp Gemfile Gemfile.bak
cp Gemfile.lock Gemfile.lock.bak
