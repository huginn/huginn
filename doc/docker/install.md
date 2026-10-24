## Why run Huginn with Docker

You can play with or deploy Huginn inside of [Docker](https://www.docker.com/).

Getting Huginn up and running using docker is quick and painless once you have docker installed. The docker container is suitable for production and evaluation. Huginn uses environmental variables for configuration, so rather than having a .env file, the Docker container expects variables to be passed into the launch command.

## Running the Container

### Quick start to check out Huginn

1. Install Docker using the [install instructions](https://docs.docker.com/get-docker/)
* Start your Huginn container using `docker run -it -p 3000:3000 ghcr.io/huginn/huginn`
* Open Huginn in the browser [http://localhost:3000](http://localhost:3000)
* Log in to your Huginn instance using the username `admin` and the random password printed once in the container log. To choose the credentials yourself, pass `-e SEED_USERNAME=... -e SEED_PASSWORD=...` to `docker run`.

## Configuration and linking to a database container

Follow the [instructions on the docker hub registry](https://hub.docker.com/r/huginn/huginn/) on how to configure Huginn using environment variables and linking the container to an external MySQL or PostgreSQL database.

## Running each Huginn process in a separate container

With the `huginn/huginn-single-process` image you can easily run each process needed for Huginn in a separate container and scale them individually when needed. Have a look at the [Docker hub](https://hub.docker.com/r/huginn/huginn-single-process/) and the [documentation for the container](https://github.com/huginn/huginn/tree/master/docker/single-process)

## Deploying with Dokku

For [Dokku](https://dokku.com/), we recommend the official single-process Docker image with the [Dockerfile builder](https://dokku.com/docs/deployment/builders/dockerfiles/).  Create a separate deployment repository containing these two files.  The image supplies Huginn; the repository defines how Dokku starts its processes.

`Dockerfile`:

```dockerfile
FROM ghcr.io/huginn/huginn-single-process:latest
COPY Procfile /app/Procfile
```

`Procfile`:

```procfile
web: /scripts/init
worker: /scripts/init bin/threaded.rb
```

The worker runs scheduled Agents and background jobs.  Keep both processes running.

On the Dokku server, create the app and select the Dockerfile builder:

```sh
dokku apps:create huginn
dokku builder:set huginn selected dockerfile
```

Explicit builder selection is important when deploying a Huginn source checkout with your own Dockerfile: Dokku 0.38 and later read the Heroku buildpacks in Huginn's `app.json`, which can otherwise cause herokuish to be selected instead.

Before the first deploy, link a database using Dokku's [PostgreSQL](https://github.com/dokku/dokku-postgres) or [MySQL](https://github.com/dokku/dokku-mysql) plugin.  The plugin sets `DATABASE_URL`, which the image uses to configure the database adapter and connection.  Set Huginn's environment variables with [`dokku config:set`](https://dokku.com/docs/configuration/environment-variables/), including `APP_SECRET_TOKEN` and `DOMAIN`.  See the [image configuration reference](../../docker/single-process/README.md) for the available settings, including `SEED_PASSWORD` for the initial admin account.

Commit the Dockerfile and Procfile, then push from your deployment repository.  Replace `dokku.example.com` with your Dokku server:

```sh
git remote add dokku dokku@dokku.example.com:huginn
git push dokku HEAD:master
```

After the first deploy, enable the worker on the Dokku server:

```sh
dokku ps:scale huginn web=1 worker=1
```

Configure your app's [domain](https://dokku.com/docs/configuration/domains/) and [HTTPS](https://dokku.com/docs/configuration/ssl/) through Dokku.  You can pin a release by replacing `latest` in the Dockerfile with the desired image tag, then commit and deploy that change.

To update a deployment that uses `latest`, refresh the base image and rebuild on the Dokku server:

```sh
docker pull ghcr.io/huginn/huginn-single-process:latest
dokku ps:rebuild huginn
```
