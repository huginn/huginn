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

    HUGINN_DATABASE_ADAPTER #(must be either 'postgres' or 'mysql2')
    HUGINN_DATABASE_HOST
    HUGINN_DATABASE_PORT

This script will run database migrations (rake db:migrate) which should be idempotent.

It will also seed the database (rake db:seed) unless this is defined:

    DO_NOT_SEED

This same seeding initially defines the "admin" user with a default password of "password" as per the standard Huginn documentation.

If you do not wish to have the default 6 agents, you will want to set the above environment variable after your initially deploy, otherwise they will be added automatically the next time a container pointing at the database is spun up.

The CMD launches Huginn via the scripts/init script. This may become the ENTRYPOINT later.  It does take under a minute for Huginn to come up.  Use environmental variables that match your DB's creds to ensure it works.

## Usage

Simple stand-alone usage:

    docker run -it -p 3000:3000 cantino/huginn

To link to another mysql container, for example:

    docker run --rm --name huginn_mysql \
        -e MYSQL_DATABASE=huginn \
        -e MYSQL_USER=huginn \
        -e MYSQL_PASSWORD=somethingsecret \
        -e MYSQL_ROOT_PASSWORD=somethingevenmoresecret \
        mysql
    docker run --rm --name huginn \
        --link huginn_mysql:mysql \
        -p 3000:3000 \
        -e HUGINN_DATABASE_NAME=huginn \
        -e HUGINN_DATABASE_USERNAME=huginn \
        -e HUGINN_DATABASE_PASSWORD=somethingsecret \
        cantino/huginn

To link to another container named 'postgres':

    docker run --rm --name huginn \
        --link huginn_postgres:postgres \
        -p 3000:3000 \
        -e "HUGINN_DATABASE_USERNAME=huginn" \
        -e "HUGINN_DATABASE_PASSWORD=pass@word" \
        cantino/huginn

The `docker/` folder also has a `docker-compose.yml` that allows for a sample database formation with a data volume container:

    cd docker ; docker-compose up

## Environment Variables

Other Huginn 12factored environment variables of note, as generated and put into the .env file as per Huginn documentation,
with an additional `HUGINN_` prefix to the variable.

These are:

    HUGINN_APP_SECRET_TOKEN
    HUGINN_DOMAIN
    HUGINN_ASSET_HOST
    HUGINN_DATABASE_ADAPTER
    HUGINN_DATABASE_ENCODING
    HUGINN_DATABASE_RECONNECT
    HUGINN_DATABASE_NAME
    HUGINN_DATABASE_POOL
    HUGINN_DATABASE_USERNAME
    HUGINN_DATABASE_PASSWORD
    HUGINN_DATABASE_HOST
    HUGINN_DATABASE_PORT
    HUGINN_DATABASE_SOCKET
    HUGINN_RAILS_ENV
    HUGINN_FORCE_SSL
    HUGINN_INVITATION_CODE
    HUGINN_SMTP_DOMAIN
    HUGINN_SMTP_USER_NAME
    HUGINN_SMTP_PASSWORD
    HUGINN_SMTP_SERVER
    HUGINN_SMTP_PORT
    HUGINN_SMTP_AUTHENTICATION
    HUGINN_SMTP_ENABLE_STARTTLS_AUTO
    HUGINN_EMAIL_FROM_ADDRESS
    HUGINN_AGENT_LOG_LENGTH
    HUGINN_TWITTER_OAUTH_KEY
    HUGINN_TWITTER_OAUTH_SECRET
    HUGINN_THIRTY_SEVEN_SIGNALS_OAUTH_KEY
    HUGINN_THIRTY_SEVEN_SIGNALS_OAUTH_SECRET
    HUGINN_AWS_ACCESS_KEY_ID
    HUGINN_AWS_ACCESS_KEY
    HUGINN_AWS_SANDBOX
    HUGINN_FARADAY_HTTP_BACKEND
    HUGINN_DEFAULT_HTTP_USER_AGENT
    HUGINN_ALLOW_JSONPATH_EVAL
    HUGINN_ENABLE_INSECURE_AGENTS
    HUGGIN_ENABLE_SECOND_PRECISION_SCHEDULE
    HUGINN_USE_GRAPHVIZ_DOT
    HUGINN_TIMEZONE
    HUGGIN_FAILED_JOBS_TO_KEEP


The above environment variables will override the defaults. The defaults are read from the [.env.example](https://github.com/cantino/huginn/blob/master/.env.example) file.

For variables in the .env.example that are commented out, the default is to not include that variable in the generated .env file.

## Building on your own

You don't need to do this on your own, because there is an [automated build](https://registry.hub.docker.com/u/cantino/huginn/) for this repository, but if you really want:

    docker build --rm=true --tag={yourname}/huginn .

## Source

The source is [available on GitHub](https://github.com/cantino/huginn/).

Please feel free to submit pull requests and/or fork at your leisure.


