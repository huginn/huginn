Docker image for Huginn testing
=================================================

This image allows the Huginn test suite to run in Docker with a bundled headless Chrome browser, against multiple databases.

In Development Mode, the source code of the current project directory is mounted as a volume overlaying the packaged `/app` directory.

The test services are pinned to amd64 because Google Chrome is not yet available for other platforms like arm64.

## Development Usage

Build the test image:

    cd docker/test
    docker compose -f develop.yml build

Run all specs against a MySQL database using `docker compose`:

    cd docker/test
    docker compose -f develop.yml run --rm test_mysql
    docker compose -f develop.yml down

Run the same test command as GitHub Actions against PostgreSQL:

    cd docker/test
    docker compose -f develop.yml run --rm test_postgres
    docker compose -f develop.yml down

Run a specific spec:

    cd docker/test
    docker compose -f develop.yml run --rm test_mysql bundle exec rspec ./spec/features/create_an_agent_spec.rb:65
    docker compose -f develop.yml down
