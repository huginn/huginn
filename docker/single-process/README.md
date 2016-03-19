Docker image for Huginn using the production environment and separate container for every process
=================================================

This image runs a linkable [Huginn](https://github.com/cantino/huginn) instance.

It was inspired by the [official docker container for huginn](https://registry.hub.docker.com/u/cantino/huginn)

The scripts/init script generates a .env file containing the variables as passed as per normal Huginn documentation.
The same environment variables that would be used for Heroku PaaS deployment are used by this script.

The scripts/init script is aware of mysql and postgres linked containers through the environment variables:

    MYSQL_PORT_3306_TCP_ADDR
    MYSQL_PORT_3306_TCP_PORT

and

    POSTGRESQL_PORT_5432_TCP_ADDR
    POSTGRESQL_PORT_5432_TCP_PORT

Its recommended to use an image that allows you to create a database via environmental variables at docker run, like `postgresql` or `mysql`, so the db is populated when this script runs.

Additionally, the database variables may be overridden from the above as per the standard Huginn documentation:

    DATABASE_ADAPTER #(must be either 'postgresql' or 'mysql2')
    DATABASE_HOST
    DATABASE_PORT

This script will run database migrations (rake db:migrate) which should be idempotent.

It will also seed the database (rake db:seed) unless this is defined:

    DO_NOT_SEED

This same seeding initially defines the "admin" user with a default password of "password" as per the standard Huginn documentation.

If you do not wish to have the default 6 agents, you will want to set the above environment variable after your initially deploy, otherwise they will be added automatically the next time a container pointing at the database is spun up.

The CMD launches Huginn via the scripts/init script. This may become the ENTRYPOINT later.  It does take under a minute for Huginn to come up.  Use environmental variables that match your DB's creds to ensure it works.

## Usage

Simple startup using docker compose (you need to daemonize with `-d` to persist the data):

    cd docker/single-process
    docker-compose up

or if you like to use PostgreSQL:

    docker-compose -f postgresql.yml up

Manual startup and linking to a MySQL container:

    docker run --name huginn_mysql \
        -e MYSQL_DATABASE=huginn \
        -e MYSQL_USER=huginn \
        -e MYSQL_PASSWORD=somethingsecret \
        -e MYSQL_ROOT_PASSWORD=somethingevenmoresecret \
        mysql

    docker run --name huginn_web \
        --link huginn_mysql:mysql \
        -p 3000:3000 \
        -e DATABASE_NAME=huginn \
        -e DATABASE_USERNAME=huginn \
        -e DATABASE_PASSWORD=somethingsecret \
        cantino/huginn-single-process

    docker run --name huginn_threaded \
        --link huginn_mysql:mysql \
        -e DATABASE_NAME=huginn \
        -e DATABASE_USERNAME=huginn \
        -e DATABASE_PASSWORD=somethingsecret \
        cantino/huginn-single-process /scripts/init bin/threaded.rb

## Environment Variables

Other Huginn 12factored environment variables of note, as generated and put into the .env file as per Huginn documentation. All variables of the [.env.example](https://github.com/cantino/huginn/blob/master/.env.example) can be used to override the defaults which a read from the current `.env.example`.

For variables in the .env.example that are commented out, the default is to not include that variable in the generated .env file.

## Building on your own

You don't need to do this on your own, but if you really want run this command in the Huginn root directory:

    docker build --rm=true --tag={yourname}/huginn -f docker/single-process/Dockerfile .

## Source

The source is [available on GitHub](https://github.com/cantino/huginn/docker/single-process/).

Please feel free to submit pull requests and/or fork at your leisure.


