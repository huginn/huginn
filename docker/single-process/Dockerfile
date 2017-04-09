FROM ubuntu:14.04

LABEL author="Andrew Cantino (@cantino)" \
      contributors="Akinori MUSHA (@knu), Dominik Sander (@dsander), George Opritescu (@International), Glenn 'devalias' Grant (@alias1), Ian Blenke (@ianblenke)" \
      maintainer="Glenn 'devalias' Grant <glenn@devalias.net> (@alias1)" \
      repo="https://github.com/cantino/huginn"

ENV HUGINN_HOME="/usr/src/huginn" \
    HUGINN_USER=huginn \
    HUGINN_GROUP=huginn \
    SCRIPTS_HOME="/docker/scripts" \
    SQLITE_VERSION=1.3.13 \
    LC_ALL=en_US.UTF-8 \
    #\
    # These are from the .env.example but are required early
    RAILS_ENV=production \
    ON_HEROKU=true 

WORKDIR $HUGINN_HOME

COPY docker/scripts/ "$SCRIPTS_HOME/"

RUN set -ex \
    && $SCRIPTS_HOME/adduser.ubuntu.sh

COPY ["Gemfile", "Gemfile.lock", "$HUGINN_HOME/"]
COPY lib/gemfile_helper.rb "$HUGINN_HOME/lib/"
COPY vendor/gems "$HUGINN_HOME/vendor/gems"

RUN set -ex \
    && $SCRIPTS_HOME/dependencies-build.ubuntu.sh \
    && $SCRIPTS_HOME/dependencies-runtime.ubuntu.sh \
    && $SCRIPTS_HOME/dependencies-gemfile.sh \
    && $SCRIPTS_HOME/dependencies-cleanup.ubuntu.sh

COPY . "$HUGINN_HOME"

RUN set -ex \
    && $SCRIPTS_HOME/huginn-setup.sh

COPY ["docker/single-process/scripts/init", "$SCRIPTS_HOME/init"]

# TODO: Make sure this entrypoint is doing everything the old init was doing.. then we can probably delete the old init..
#ENTRYPOINT ["$SCRIPTS_HOME/huginn-entrypoint.sh"]

EXPOSE 3000

USER $HUGINN_USER

CMD ["$SCRIPTS_HOME/init"]
