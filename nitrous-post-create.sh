#!/bin/bash

rm -rf ~/code/example

export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo -E apt-get -q -y install mysql-server
sudo apt-get -y install libmysqlclient-dev pwgen
sudo apt-get clean

cp .env.example .env

MYSQL_PASSWORD=`pwgen -1`
mysql -u root -e "CREATE USER 'huginn'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'huginn'@'localhost';"
sed -i 's/DATABASE_USERNAME=.*/DATABASE_USERNAME=huginn/g' .env
sed -i "s/DATABASE_PASSWORD=.*/DATABASE_PASSWORD=\"$MYSQL_PASSWORD\"/g" .env

APP_SECRET_TOKEN=`pwgen 24 -1`
sed -i "s/APP_SECRET_TOKEN=.*/APP_SECRET_TOKEN=$APP_SECRET_TOKEN/g" .env

npm install -g phantomjs-prebuilt
gem install bundler
bundle install
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rake db:seed

cat >> ~/code/huginn/README.nitrous.md <<EOT
# Setup

Welcome to your Huginn project on Nitrous.

## Running the development server:

In the [Nitrous IDE](https://community.nitrous.io/docs/ide-overview), start Huginn via "Run > Start Huginn" and wait for 30 seconds for the server to be started.

Now you've got a development server running and can see the output in the Nitrous terminal window. You can open up a new shell or utilize [tmux](https://community.nitrous.io/docs/tmux) to open new shells to run other commands.

## Preview the app

In the Nitrous IDE, open the "Preview" menu and click "Port 3000".
EOT
