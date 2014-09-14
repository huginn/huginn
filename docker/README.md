Huginn for docker with multiple container linkage
=================================================

This image runs a linkable [Huginn](https://github.com/cantino/huginn) instance.

There is an automated build repository on docker hub for [cantino/huginn](https://registry.hub.docker.com/builds/github/cantino/huginn/).

This was patterned after [sameersbn/gitlab](https://registry.hub.docker.com/u/sameersbn/gitlab) by [ianblenke/huginn](http://github.com/ianblenke/huginn), and imported here for official generation of a docker hub auto-build image.

The scripts/init script generates a .env file containing the variables as passed as per normal Huginn documentation.
The same environment variables that would be used for Heroku PaaS deployment are used by this script.

The scripts/init script is aware of mysql and postgres linked containers through the environment variables:

    MYSQL_PORT_3306_TCP_ADDR
    MYSQL_PORT_3306_TCP_PORT

and

    POSTGRESQL_PORT_5432_TCP_ADDR
    POSTGRESQL_PORT_5432_TCP_PORT

Its recommended to use an image that allows you to create a database via environmental variables at docker run, like `paintedfox / postgresql` or `centurylink / mysql`, so the db is populated when this script runs.

If you do not link a database container, a built-in mysql database will be started.
There is an exported docker volume of /var/lib/mysql to allow persistence of that mysql database.

Additionally, the database variables may be overridden from the above as per the standard Huginn documentation:

    DATABASE_ADAPTER #(must be either 'postgres' or 'mysql2')
    DATABASE_HOST
    DATABASE_PORT

This script will run database migrations (rake db:migrate) which should be idempotent.

It will also seed the database (rake db:seed) unless this is defined:

    DO_NOT_SEED

This same seeding initially defines the "admin" user with a default password of "password" as per the standard Huginn documentation.

If you do not wish to have the default 6 agents, you will want to set the above environment variable after your initially deploy, otherwise they will be added automatically the next time a container pointing at the database is spun up.

The CMD launches Huginn via the scripts/init script. This may become the ENTRYPOINT later.  It does take under a minute for Huginn to come up.  Use environmental variables that match your DB's creds to ensure it works.

## Usage

Simple stand-alone usage:

    docker run -it -p 5000:5000 cantino/huginn

To link to another mysql container, for example:

    docker run --rm --name newcentury_mysql -p 3306 \
        -e MYSQL_DATABASE=huginn \
        -e MYSQL_USER=huginn \
        -e MYSQL_PASSWORD=somethingsecret \
        -e MYSQL_ROOT_PASSWORD=somethingevenmoresecret \
        cantino/huginn
    docker run --rm --name huginn --link newcentury_mysql:MYSQL -p 5000:5000 \
        -e DATABASE_NAME=huginn \
        -e DATABASE_USER=huginn \
        -e DATABASE_PASSWORD=somethingsecret \
        cantino/huginn

To link to another container named 'postgres':

    docker run --rm --name huginn --link POSTGRES:mysql -p 5000:5000 -e "DATABASE_USER=huginn" -e "DATABASE_PASSWORD=pass@word" cantino/huginn

## Environment Variables

Other Huginn 12factored environment variables of note, as generated and put into the .env file as per Huginn documentation:

    APP_SECRET_TOKEN=${APP_SECRET_TOKEN:-CHANGEME}
    DOMAIN=${HUGINN_HOST:-localhost}:${PORT:-5000}
    ${ASSET_HOST:+ASSET_HOST=${ASSET_HOST}}
    DATABASE_ADAPTER=${DATABASE_ADAPTER:-mysql2}
    DATABASE_ENCODING=${DATABASE_ENCODING:-utf8}
    DATABASE_RECONNECT=${DATABASE_RECONNECT:-true}
    DATABASE_NAME=${DATABASE_NAME:-huginn}
    DATABASE_POOL=${DATABASE_POOL:-5}
    DATABASE_USERNAME=${DATABASE_USERNAME:-root}
    DATABASE_PASSWORD="${DATABASE_PASSWORD}"
    DATABASE_PORT=${DATABASE_PORT:-3306}
    DATABASE_HOST=${DATABASE_HOST:-localhost}
    DATABASE_PORT=${DATABASE_PORT:-3306}
    ${DATABASE_SOCKET:+DATABASE_SOCKET=${DATABASE_SOCKET:-/tmp/mysql.sock}}
    ${RAILS_ENV:+RAILS_ENV=${RAILS_ENV:-production}}
    FORCE_SSL=${FORCE_SSL:-false}
    INVITATION_CODE=${INVITATION_CODE:-try-huginn}
    SMTP_DOMAIN=${SMTP_DOMAIM=-example.com}
    SMTP_USER_NAME=${SMTP_USER_NAME:-you@gmail.com}
    SMTP_PASSWORD=${SMTP_PASSWORD:-somepassword}
    SMTP_SERVER=${SMTP_SERVER:-smtp.gmail.com}
    SMTP_PORT=${SMTP_PORT:-587}
    SMTP_AUTHENTICATION=${SMTP_AUTHENTICATION:-plain}
    SMTP_ENABLE_STARTTLS_AUTO=${SMTP_ENABLE_STARTTLS_AUTO:-true}
    EMAIL_FROM_ADDRESS=${EMAIL_FROM_ADDRESS:-huginn@example.com}
    AGENT_LOG_LENGTH=${AGENT_LOG_LENGTH:-200}
    AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-your aws access key id}"
    AWS_ACCESS_KEY="${AWS_ACCESS_KEY:-your aws access key}"
    AWS_SANDBOX=${AWS_SANDBOX:-false}
    FARADAY_HTTP_BACKEND=${FARADAY_HTTP_BACKEND:-typhoeus}
    DEFAULT_HTTP_USER_AGENT="${DEFAULT_HTTP_USER_AGENT:-Huginn - https://github.com/cantino/huginn}"
    ALLOW_JSONPATH_EVAL=${ALLOW_JSONPATH_EVAL:-false}
    ENABLE_INSECURE_AGENTS=${ENABLE_INSECURE_AGENTS:-false}
    ${USE_GRAPHVIZ_DOT:+USE_GRAPHVIZ_DOT=${USE_GRAPHVIZ_DOT:-dot}}
    TIMEZONE="${TIMEZONE:-Pacific Time (US & Canada)}"

The defaults used are the Huginn defaults as per the [.env.example](https://github.com/cantino/huginn/blob/master/.env.example) file.

## Building on your own

You don't need to do this on your own, because there is an [automated build](https://registry.hub.docker.com/u/cantino/huginn/) for this repository, but if you really want:

    docker build --rm=true --tag={yourname}/huginn .

## Source

The source is [available on GitHub](https://github.com/cantino/huginn/).

Please feel free to submit pull requests and/or fork at your leisure.


