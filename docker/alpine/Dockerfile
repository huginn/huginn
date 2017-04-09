FROM usualoma/ruby-with-therubyracer:2.3.0-alpine

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
    && $SCRIPTS_HOME/adduser.alpine.sh

COPY ["Gemfile", "Gemfile.lock", "$HUGINN_HOME/"]
COPY lib/gemfile_helper.rb "$HUGINN_HOME/lib/"
#COPY vendor/gems "$HUGINN_HOME/vendor/gems"

RUN set -ex \
    && $SCRIPTS_HOME/dependencies-build.alpine.sh \
    && $SCRIPTS_HOME/dependencies-runtime.alpine.sh \
    && $SCRIPTS_HOME/dependencies-gemfile.sh \
    && $SCRIPTS_HOME/dependencies-cleanup.alpine.sh

# See .env.example for descriptions/usage
# See also: https://github.com/docker/docker/issues/32455
ENV APP_SECRET_TOKEN=REPLACE_ME_NOW! \
    #ON_HEROKU=true \
    PORT=3000 \
    DOMAIN=localhost:3000 \
    ASSET_HOST= \
    DATABASE_ADAPTER=mysql2 \
    DATABASE_ENCODING=utf8m4 \
    DATABASE_RECONNECT=true \
    DATABASE_NAME=huginn \
    DATABASE_POOL=20 \
    DATABASE_USERNAME=huginn \
    DATABASE_PASSWORD=huginn \
    DATABASE_HOST=db \
    DATABASE_PORT=3306 \
    DATABASE_SOCKET= \
    #RAILS_ENV=production \
    FORCE_SSL=false \
    INVITATION_CODE=try-huginn \
    SKIP_INVITATION_CODE=false \
    REQUIRE_CONFIRMED_EMAIL=false \
    ALLOW_UNCONFIRMED_ACCESS_FOR=2.days \
    CONFIRM_WITHIN=3.days \
    MIN_PASSWORD_LENGTH=8 \
    RESET_PASSWORD_WITHIN=6.hours \
    LOCK_STRATEGY=failed_attempts \
    MAX_FAILED_LOGIN_ATTEMPTS=10 \
    UNLOCK_STRATEGY=both \
    UNLOCK_AFTER=1.hour \
    REMEMBER_FOR=4.weeks \
    IMPORT_DEFAULT_SCENARIO_FOR_ALL_USERS=true \
    DEFAULT_SCENARIO_FILE= \
    SMTP_DOMAIN= \
    SMTP_USER_NAME= \
    SMTP_PASSWORD= \
    SMTP_SERVER=smtp.gmail.com \
    SMTP_PORT=587 \
    SMTP_AUTHENTICATION=plain \
    SMTP_ENABLE_STARTTLS_AUTO=true \
    SEND_EMAIL_IN_DEVELOPMENT=false \
    EMAIL_FROM_ADDRESS=from_address@gmail.com \
    AGENT_LOG_LENGTH=200 \
    TWITTER_OAUTH_KEY= \
    TWITTER_OAUTH_SECRET= \
    THIRTY_SEVEN_SIGNALS_OAUTH_KEY= \
    THIRTY_SEVEN_SIGNALS_OAUTH_SECRET= \
    GITHUB_OAUTH_KEY= \
    GITHUB_OAUTH_SECRET= \
    TUMBLR_OAUTH_KEY= \
    TUMBLR_OAUTH_SECRET= \
    DROPBOX_OAUTH_KEY= \
    DROPBOX_OAUTH_SECRET= \
    WUNDERLIST_OAUTH_KEY= \
    WUNDERLIST_OAUTH_SECRET= \
    EVERNOTE_OAUTH_KEY= \
    EVERNOTE_OAUTH_SECRET= \
    USE_EVERNOTE_SANDBOX=false \
    AWS_ACCESS_KEY_ID= \
    AWS_ACCESS_KEY= \
    AWS_SANDBOX=false \
    ADDITIONAL_GEMS= \
    FARADAY_HTTP_BACKEND=typhoeus \
    DEFAULT_HTTP_USER_AGENT="Huginn - https://github.com/cantino/huginn" \
    ALLOW_JSONPATH_EVAL=false \
    ENABLE_INSECURE_AGENTS=false \
    ENABLE_SECOND_PRECISION_SCHEDULE=false \
    SCHEDULER_FREQUENCY=0.3 \
    EVENT_EXPIRATION_CHECK=6h \
    USE_GRAPHVIZ_DOT= \
    DIAGRAM_DEFAULT_LAYOUT= \
    TIMEZONE="Pacific Time (US & Canada)" \
    FAILED_JOBS_TO_KEEP=100 \
    DELAYED_JOB_MAX_RUNTIME=2 \
    DELAYED_JOB_SLEEP_DELAY=10

COPY . "$HUGINN_HOME"

RUN set -ex \
    && $SCRIPTS_HOME/huginn-setup.sh

COPY docker/init.ng "/huginn-init.sh"

#COPY docker-entrypoint.sh /
#ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 3000

USER $HUGINN_USER

# TODO: Make our entrypoint the init to setup the env.. then pass through whatever commands we need in CMD
CMD ["/huginn-init.sh"]
#CMD ["/bin/sh"]
