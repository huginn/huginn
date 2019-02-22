Docker image for Huginn testing
=================================================

This image allows the [Huginn](https://github.com/huginn/huginn) test suite to be run in a container, against multiple databases.

It was inspired by the [official docker container for huginn](https://hub.docker.com/r/huginn/huginn)

In Development Mode, the source code of the current project directory is mounted as a volume overlaying the packaged `/app` directory.

## Development Usage

Build a docker image that contains huginn, as well as huginn test dependencies using `docker-compose`:

    cd docker/test
    docker-compose -f develop.yml build

Run all specs against a MySQL database using `docker-compose`:

    cd docker/test
    docker-compose -f develop.yml run test_mysql
    docker-compose -f develop.yml down

Run all specs against a Postgres database using `docker-compose`:

    cd docker/test
    docker-compose -f develop.yml run test_postgres
    docker-compose -f develop.yml down

Run a specific spec using `docker-compose`:

    docker-compose -f develop.yml run test_postgres rspec ./spec/helpers/dot_helper_spec.rb:82
    docker-compose -f develop.yml down
