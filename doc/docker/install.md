## Why run Huginn with Docker

You can play with or deploy Huginn inside of [Docker](https://www.docker.com/).

Getting Huginn up and running using docker is quick and painless once you have docker installed. The docker container is suitable for production and evaluation. Huginn uses environmental variables for configuration, so rather than having a .env file, the Docker container expects variables to be passed into the launch command.

## Running the Container

### Quick start to check out Huginn

1. Install Docker using the [install instructions](https://docs.docker.com/get-docker/)
* Start your Huginn container using `docker run -it -p 3000:3000 ghcr.io/huginn/huginn`
* Open Huginn in the browser [http://localhost:3000](http://localhost:3000)
* Log in to your Huginn instance using the username `admin` and password `password`

## Configuration and linking to a database container

Follow the [instructions on the docker hub registry](https://hub.docker.com/r/huginn/huginn/) on how to configure Huginn using environment variables and linking the container to an external MySQL or PostgreSQL database.

## Running each Huginn process in a separate container

With the `huginn/huginn-single-process` image you can easily run each process needed for Huginn in a separate container and scale them individually when needed. Have a look at the [Docker hub](https://hub.docker.com/r/huginn/huginn-single-process/) and the [documentation for the container](https://github.com/huginn/huginn/tree/master/docker/single-process)
