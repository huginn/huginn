## Why run Huginn with docker

You can play with or deploy Huginn inside of [docker](http://www.docker.io/).

Getting Huginn up and running using docker is quick and painless once you have docker installed. The docker container is suitable for production and evaluation. Huginn uses environmental variables for configuration, so rather than having a .env file, the Docker container expects variables to be passed into the launch command.

## Running the Container

### Quick start to check out Huginn

#### OSX GUI using Kitematic

1. Download and install [Kitematic](https://www.docker.com/docker-kitematic)
* Start Kitematic and search for `cantino/huginn`
* Click `create` and wait for the container to be downloaded and booted
* Click on the link icon next to 'WEB PREVIEW'
* Log in to your Huginn instance using the username `admin` and password `password`

#### OSX/Windows/Linux using docker machine

1. Download [docker machine](https://docs.docker.com/machine/#installation) for your OS
* Follow the installation instructions untill you can successfully run `docker ps`
* Get the the IP of the VM running docker by running `docker-machine ls`
* Start your Huginn container using `docker run -it -p 3000:3000 cantino/huginn`
* Open Huginn in the browser [http://docker-machine ip:3000](http://<docker-machine ip>:3000)
* Log in to your Huginn instance using the username `admin` and password `password`

#### Linux

1. Install docker using the [install instructions](https://docs.docker.com/installation/)
* Start your Huginn container using `docker run -it -p 3000:3000 cantino/huginn`
* Open Huginn in the browser [http://localhost:3000](http://localhost:3000)
* Log in to your Huginn instance using the username `admin` and password `password`

## Configuration and linking to a database container

Follow the [instructions on the docker hub registry](https://registry.hub.docker.com/u/cantino/huginn/) on how to configure Huginn using environment variables and linking the container to an external MySQL or PostgreSQL database.

## Running each Huginn process in a seperate container

With the `cantino/huginn-single-process` image you can easily run each process needed for Huginn in a separate container and scale them individually when needed. Have a look at the [Docker hub](https://hub.docker.com/r/cantino/huginn-single-process/) and the [documentation for the container](https://github.com/cantino/huginn/tree/master/docker/single-process)

### Other options:

Other Docker options:

* If you don't want to use the official repo, see also: https://registry.hub.docker.com/u/andrewcurioso/huginn/
* If you'd like to run Huginn's web process and job worker process in separate containers, another option is https://github.com/hackedu/huginn-docker. It also uses Unicorn as the web server and serves precompiled assets.
