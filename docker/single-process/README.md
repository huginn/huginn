Docker image for Huginn using the production environment and separate container for every process
=================================================

This image runs a linkable [Huginn](https://github.com/huginn/huginn) instance.

It was inspired by the [official docker container for huginn](https://hub.docker.com/r/huginn/huginn)

The scripts/init script generates a .env file containing the variables as passed as per normal Huginn documentation.
The same environment variables that would be used for Heroku PaaS deployment are used by this script.

The scripts/init script is aware of mysql and postgres linked containers through the environment variables:

    MYSQL_PORT_3306_TCP_ADDR
    MYSQL_PORT_3306_TCP_PORT

and

    POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT_5432_TCP_PORT

Its recommended to use an image that allows you to create a database via environmental variables at docker run, like `postgresql` or `mysql`, so the db is populated when this script runs.

Additionally, the database variables may be overridden from the above as per the standard Huginn documentation:

    DATABASE_ADAPTER #(must be either 'postgresql' or 'mysql2')
    DATABASE_HOST
    DATABASE_PORT

If your database user does not have the permission to create the Huginn database please make sure it exists and set the `DO_NOT_CREATE_DATABASE` environment variable.

This script will run database migrations (rake db:migrate) which should be idempotent.

The Rails secret is taken from the environment variable ``APP_SECRET_TOKEN``.  If it is not set, a random one is generated when the container starts, which invalidates existing sessions whenever the container is recreated.  To keep sessions across restarts, set it to a random value of your own, e.g. the output of ``openssl rand -hex 64``.

It will also seed the database (rake db:seed) unless this is defined:

    DO_NOT_SEED

This same seeding initially defines the "admin" user as per the standard Huginn documentation.
You can customize the admin account name and password with the environment variables ``SEED_USERNAME`` and ``SEED_PASSWORD``.
If ``SEED_PASSWORD`` is not set, a random password is generated and printed once in the container log; note it down.

If you do not wish to have the default 6 agents, you will want to set the above environment variable after your initially deploy, otherwise they will be added automatically the next time a container pointing at the database is spun up.

The CMD launches Huginn via the scripts/init script. This may become the ENTRYPOINT later.  It does take under a minute for Huginn to come up.  Use environmental variables that match your DB's creds to ensure it works.

## Usage

Simple startup using docker compose (you need to daemonize with `-d` to persist the data):

    cd docker/single-process
    docker-compose up

If you already have a MySQL 5.7 data volume, cleanly shut it down before the first MySQL 8.0 start:

    cd docker/single-process
    docker-compose stop web threaded
    docker-compose exec mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SET GLOBAL innodb_fast_shutdown = 0"'
    docker-compose stop mysql
    docker-compose pull mysql mysqldata
    docker-compose up -d

Run this while the old MySQL 5.7 container is still available.  The MySQL 8.0 Docker image automatically performs the data dictionary upgrade when it starts with the existing data volume.

or if you like to use PostgreSQL:

    docker-compose -f postgresql.yml up

Manual startup and linking to a MySQL container:

    docker run --name huginn_mysql \
        -e MYSQL_DATABASE=huginn \
        -e MYSQL_USER=huginn \
        -e MYSQL_PASSWORD=somethingsecret \
        -e MYSQL_ROOT_PASSWORD=somethingevenmoresecret \
        mysql

    docker run --rm --name huginn_web \
        --link huginn_mysql:mysql \
        -p 3000:3000 \
        -e DATABASE_NAME=huginn \
        -e DATABASE_USERNAME=huginn \
        -e DATABASE_PASSWORD=somethingsecret \
        ghcr.io/huginn/huginn-single-process

    docker run --rm --name huginn_threaded \
        --link huginn_mysql:mysql \
        -e DATABASE_NAME=huginn \
        -e DATABASE_USERNAME=huginn \
        -e DATABASE_PASSWORD=somethingsecret \
        ghcr.io/huginn/huginn-single-process /scripts/init bin/threaded.rb

or alternatively:

    docker run --rm --name huginn_threaded \
        --link huginn_mysql:mysql \
        -e DATABASE_NAME=huginn \
        -e DATABASE_USERNAME=huginn \
        -e DATABASE_PASSWORD=somethingsecret \
        -e WORKER_CMD='bin/threaded.rb' \
        ghcr.io/huginn/huginn-single-process

## Restricting outbound requests

Both images bundle [Smokescreen](https://github.com/stripe/smokescreen), an egress proxy that refuses connections to private, loopback and link-local addresses.  Set `ENABLE_SMOKESCREEN=true` to start it inside the container and route all outbound HTTP(S) requests made by Agents through it; `OUTBOUND_PROXY` is then set to `http://127.0.0.1:4750` automatically.  Use this on instances where untrusted users can create Agents.  Internal services that Agents legitimately need can be allowed with `SMOKESCREEN_OPTS`, e.g. `SMOKESCREEN_OPTS=--allow-address=intranet.example.com:443`.  See [doc/manual/outbound-requests.md](../../doc/manual/outbound-requests.md) for details and limitations.

## Environment Variables

Other Huginn [12factored](https://12factor.net/) environment variables of note are generated and put into the .env file as per Huginn documentation. All variables of the [.env.example](https://github.com/huginn/huginn/blob/master/.env.example) can be used to override the defaults which a read from the current `.env.example`.

For variables in the .env.example that are commented out, the default is to not include that variable in the generated .env file.

In newer versions of Docker you are able to pass your own .env file in to the container with the `--env-file` parameter.

## Building on your own

You don't need to do this on your own, but if you really want run this command in the Huginn root directory:

    docker build --rm=true --tag={yourname}/huginn -f docker/single-process/Dockerfile .

## Source

The source is [available on GitHub](https://github.com/huginn/huginn/tree/master/docker/single-process).

Please feel free to submit pull requests and/or fork at your leisure.
