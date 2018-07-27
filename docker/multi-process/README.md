Huginn for docker with multiple container linkage
=================================================

This image runs a linkable [Huginn](https://github.com/huginn/huginn) instance.

There is an automated build repository on docker hub for [huginn/huginn](https://hub.docker.com/r/huginn/huginn).

This was patterned after [sameersbn/gitlab](https://hub.docker.com/r/sameersbn/gitlab) by [ianblenke/huginn](http://github.com/ianblenke/huginn), and imported here for official generation of a docker hub auto-build image.

The scripts/init script generates a .env file containing the variables as passed as per normal Huginn documentation.
The same environment variables that would be used for Heroku PaaS deployment are used by this script.

The scripts/init script is aware of mysql and postgres linked containers through the environment variables:

    MYSQL_PORT_3306_TCP_ADDR
    MYSQL_PORT_3306_TCP_PORT

and

    POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT_5432_TCP_PORT

Its recommended to use an image that allows you to create a database via environmental variables at docker run, like `paintedfox / postgresql` or `centurylink / mysql`, so the db is populated when this script runs.

If you do not link a database container, a built-in mysql database will be started.
There is an exported docker volume of `/var/lib/mysql` to allow persistence of that mysql database.

__NOTE:__ If you do not export the volme, or use a linked database container, you cannot update Huginn without losing your data.

Additionally, the database variables may be overridden from the above as per the standard Huginn documentation:

    DATABASE_ADAPTER #(must be either 'postgresql' or 'mysql2')
    DATABASE_HOST
    DATABASE_PORT

When connecting to an external database and your user does not have the permission to create the Huginn database please make sure it exists and set the `DO_NOT_CREATE_DATABASE` environment variable.

This script will run database migrations (rake db:migrate) which should be idempotent.

It will also seed the database (rake db:seed) unless this is defined:

    DO_NOT_SEED

This same seeding initially defines the "admin" user with a default password of "password" as per the standard Huginn documentation.

If you do not wish to have the default 6 agents, you will want to set the above environment variable after your initially deploy, otherwise they will be added automatically the next time a container pointing at the database is spun up.

The CMD launches Huginn via the scripts/init script. This may become the ENTRYPOINT later.  It does take under a minute for Huginn to come up.  Use environmental variables that match your DB's creds to ensure it works.

## Usage

Simple stand-alone usage (use only for testing/evaluation as it can not be updated without losing data):

    docker run -it -p 3000:3000 huginn/huginn

Use a volume to export the data of the internal mysql server:

    docker run --rm -it -p 3000:3000 -v /home/huginn/mysql-data:/var/lib/mysql huginn/huginn

To link to another mysql container, for example:

    docker run --name huginn_mysql \
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
        huginn/huginn

To link to another container named 'postgres':

    docker run --name huginn_postgres \
        -e POSTGRES_PASSWORD=mysecretpassword \
        -e POSTGRES_USER=huginn -d postgres

    docker run --rm --name huginn \
        --link huginn_postgres:postgres \
        -p 3000:3000 \
        -e HUGINN_DATABASE_USERNAME=huginn \
        -e HUGINN_DATABASE_PASSWORD=mysecretpassword \
        -e HUGINN_DATABASE_ADAPTER=postgresql \
        huginn/huginn

The `docker/multi-process` folder also has a `docker-compose.yml` that allows for a sample database formation with a data volume container:

    cd docker/multi-process
    docker-compose up

## Environment Variables

Other Huginn [12factored](https://12factor.net/) environment variables of note are generated and put into the .env file as per Huginn documentation. All variables of the [.env.example](https://github.com/huginn/huginn/blob/master/.env.example) can be used to override the defaults which a read from the current `.env.example`.

For variables in the .env.example that are commented out, the default is to not include that variable in the generated .env file.

In newer versions of Docker you are able to pass your own .env file in to the container with the `--env-file` parameter.

## Building on your own

You don't need to do this on your own, because there is an [automated build](https://hub.docker.com/r/huginn/huginn/) for this repository, but if you really want run this command in the Huginn root directory:

    bin/docker_wrapper build --rm=true --tag={yourname}/huginn -f docker/multi-process/Dockerfile .

## Source

The source is [available on GitHub](https://github.com/huginn/huginn/tree/master/docker/multi-process).

Please feel free to submit pull requests and/or fork at your leisure.
