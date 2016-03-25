# Installation from source


## Important Notes

This guide is long because it covers many cases and includes all commands you need.

This installation guide was created for and tested on **Debian/Ubuntu** operating systems. Please read [doc/install/requirements.md](./requirements.md) for hardware and operating system requirements.

This is the official installation guide to set up a production server. To set up a **development installation** or for many other installation options please see [the getting started section of the readme](https://github.com/cantino/huginn#getting-started).

The following steps have been known to work. Please **use caution when you deviate** from this guide. Make sure you don't violate any assumptions Huginn makes about its environment. For example many people run into permission problems because they change the location of directories or run services as the wrong user.

If you find a bug/error in this guide please **submit a pull request**.

If not stated otherwise all commands should be run as user with sudo permissions or as root.

When having problems during the installation please check the [troubleshooting](#troubleshooting) section.

## Overview

The Huginn installation consists of setting up the following components:

1. Packages / Dependencies
1. Ruby
1. System Users
1. Database
1. Huginn
1. Nginx

## 1. Packages / Dependencies

`sudo` is not installed on Debian by default. Make sure your system is
up-to-date and install it.

    # run as root!
    apt-get update -y
    apt-get upgrade -y
    apt-get install sudo -y

**Note:** During this installation some files will need to be edited manually. If you are familiar with vim set it as default editor with the commands below. If you are not familiar with vim please skip this and keep using the default editor.

    # Install vim and set as default editor
    sudo apt-get install -y vim
    sudo update-alternatives --set editor /usr/bin/vim.basic

Import node.js repository (can be skipped on Ubuntu and Debian Jessie):

    curl -sL https://deb.nodesource.com/setup_0.12 | sudo bash -

Install the required packages (needed to compile Ruby and native extensions to Ruby gems):

    sudo apt-get install -y runit build-essential git zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl openssh-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev logrotate python-docutils pkg-config cmake nodejs graphviz


## 2. Ruby


The use of Ruby version managers such as [RVM](http://rvm.io/), [rbenv](https://github.com/sstephenson/rbenv) or [chruby](https://github.com/postmodern/chruby) with Huginn in production frequently leads to hard-to-diagnose problems. Version managers are not supported and we strongly advise everyone to follow the instructions below to use a system Ruby.

Remove the old Ruby versions if present:

    sudo apt-get remove -y ruby1.8 ruby1.9

Download Ruby and compile it:

    mkdir /tmp/ruby && cd /tmp/ruby
    curl -L --progress http://cache.ruby-lang.org/pub/ruby/2.3/ruby-2.3.0.tar.bz2 | tar xj
    cd ruby-2.3.0
    ./configure --disable-install-rdoc
    make -j`nproc`
    sudo make install

Install the bundler and foreman gems:

    sudo gem install rake bundler foreman --no-ri --no-rdoc

## 3. System Users

Create a user for Huginn:

    sudo adduser --disabled-login --gecos 'Huginn' huginn

## 4. Database

Install the database packages

    sudo apt-get install -y mysql-server mysql-client libmysqlclient-dev

    # Pick a MySQL root password (can be anything), type it and press enter,
    # retype the MySQL root password and press enter

Check the installed MySQL version (remeber if its >= 5.5.3 for the `.env` configuration done later):

    mysql --version

Secure your installation

    sudo mysql_secure_installation

Login to MySQL

    mysql -u root -p

    # Type the MySQL root password

Create a user for Huginn do not type the `mysql>`, this is part of the prompt. Change `$password` in the command below to a real password you pick

    mysql> CREATE USER 'huginn'@'localhost' IDENTIFIED BY '$password';

Ensure you can use the InnoDB engine which is necessary to support long indexes

    mysql> SET storage_engine=INNODB;

    # If this fails, check your MySQL config files (e.g. `/etc/mysql/*.cnf`, `/etc/mysql/conf.d/*`)
    # for the setting "innodb = off"

Grant the Huginn user necessary permissions on the database

    mysql> GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, LOCK TABLES ON `huginn_production`.* TO 'huginn'@'localhost';

Quit the database session

    mysql> \q

Try connecting to the new database with the new user

    sudo -u huginn -H mysql -u huginn -p -D huginn_production

    # Type the password you replaced $password with earlier

You should now see `ERROR 1049 (42000): Unknown database 'huginn_production'` which is fine because we will create the database later.

You are done installing the database and can go back to the rest of the installation.


## 6. Huginn

### Clone the Source

    # We'll install Huginn into the home directory of the user "huginn"
    cd /home/huginn

    # Clone Huginn repository
    sudo -u huginn -H git clone https://github.com/cantino/huginn.git -b master huginn

    # Go to Huginn installation folder
    cd /home/huginn/huginn

    # Copy the example Huginn config
    sudo -u huginn -H cp .env.example .env

    # Create the log/, tmp/pids/ and tmp/sockets/ directories
    sudo -u huginn mkdir -p log tmp/pids tmp/sockets

    # Make sure Huginn can write to the log/ and tmp/ directories
    sudo chown -R huginn log/ tmp/
    sudo chmod -R u+rwX,go-w log/ tmp/

    # Make sure permissions are set correctly
    sudo chmod -R u+rwX,go-w log/
    sudo chmod -R u+rwX tmp/
    sudo -u huginn -H chmod o-rwx .env

    # Copy the example Unicorn config
    sudo -u huginn -H cp config/unicorn.rb.example config/unicorn.rb

### Configure it

    # Update Huginn config file and follow the instructions
    sudo -u huginn -H editor .env

If you are using a local MySQL server the database configuration should look like this (use the password of the huginn MySQL user you created earlier):

    DATABASE_ADAPTER=mysql2
    DATABASE_RECONNECT=true
    DATABASE_NAME=huginn_production
    DATABASE_POOL=20
    DATABASE_USERNAME=huginn
    DATABASE_PASSWORD='$password'
    #DATABASE_HOST=your-domain-here.com
    #DATABASE_PORT=3306
    #DATABASE_SOCKET=/tmp/mysql.sock

    DATABASE_ENCODING=utf8
    # MySQL only: If you are running a MySQL server >=5.5.3, you should
    # set DATABASE_ENCODING to utf8mb4 instead of utf8 so that the
    # database can hold 4-byte UTF-8 characters like emoji.
    #DATABASE_ENCODING=utf8mb4

**Important**: Uncomment the RAILS_ENV setting to run Huginn in the production rails environment

    RAILS_ENV=production

Change the Unicorn config if needed, the [requirements.md](./requirements.md#unicorn-workers) has a section explaining the suggested amount of unicorn workers:

    # Increase the amount of workers if you expect to have a high load instance.
    # 2 are enough for most use cases, if the server has less then 2GB of RAM
    # decrease the worker amount to 1
    sudo -u huginn -H editor config/unicorn.rb


**Important Note:** Make sure to edit both `.env` and `unicorn.rb` to match your setup.

**Note:** If you want to use HTTPS, which is what we recommend, see [Using HTTPS](#using-https) for the additional steps.

### Install Gems

**Note:** As of bundler 1.5.2, you can invoke `bundle install -jN` (where `N` the number of your processor cores) and enjoy parallel gem installation with measurable difference in completion time (~60% faster). Check the number of your cores with `nproc`. For more information check this [post](http://robots.thoughtbot.com/parallel-gem-installing-using-bundler). First make sure you have bundler >= 1.5.2 (run `bundle -v`) as it addresses some [issues](https://devcenter.heroku.com/changelog-items/411) that were [fixed](https://github.com/bundler/bundler/pull/2817) in 1.5.2.

    sudo -u huginn -H bundle install --deployment --without development test

### Initialize Database

    # Create the database
    sudo -u huginn -H bundle exec rake db:create RAILS_ENV=production

    # Migrate to the latest version
    sudo -u huginn -H bundle exec rake db:migrate RAILS_ENV=production

    # Create admin user and example agents using the default admin/password login
    sudo -u huginn -H bundle exec rake db:seed RAILS_ENV=production SEED_USERNAME=admin SEED_PASSWORD=password

When done you see `See the Huginn Wiki for more Agent examples!  https://github.com/cantino/huginn/wiki`

**Note:** This will create an initial user, you can change the username and password by supplying it in environmental variables `SEED_USERNAME` and `SEED_PASSWORD` as seen above. If you don't change the password (and it is set to the default one) please wait with exposing Huginn to the public internet until the installation is done and you've logged into the server and changed your password.

### Compile Assets

    sudo -u huginn -H bundle exec rake assets:precompile RAILS_ENV=production

### Install Init Script

Huginn uses [foreman](http://ddollar.github.io/foreman/) to generate the init scripts based on a `Procfile`

Edit the [`Procfile`](https://github.com/cantino/huginn/blob/master/Procfile) and choose one of the suggested versions for production

    sudo -u huginn -H editor Procfile

Comment out (disable) [these two lines](https://github.com/cantino/huginn/blob/master/Procfile#L6-L7)

    web: bundle exec rails server -p ${PORT-3000} -b ${IP-0.0.0.0}
    jobs: bundle exec rails runner bin/threaded.rb

Enable (remove the comment) [from these lines](https://github.com/cantino/huginn/blob/master/Procfile#L24-L25) or [those](https://github.com/cantino/huginn/blob/master/Procfile#L28-L31)

    # web: bundle exec unicorn -c config/unicorn.rb
    # jobs: bundle exec rails runner bin/threaded.rb

Export the init scripts:

    sudo bundle exec rake production:export

**Note:** You have to re-export the init script every time you change the configuration in `.env` or your `Procfile`!

### Setup Logrotate

    sudo cp deployment/logrotate/huginn /etc/logrotate.d/huginn


### Ensure Your Huginn Instance Is Running

    sudo bundle exec rake production:status

## 7. Nginx

**Note:** Nginx is the officially supported web server for Huginn. If you cannot or do not want to use Nginx as your web server, the wiki has a page on how to configure [apache](https://github.com/cantino/huginn/wiki/Apache-Huginn-configuration).

### Installation

    sudo apt-get install -y nginx

### Site Configuration

Copy the example site config:

    sudo cp deployment/nginx/huginn /etc/nginx/sites-available/huginn
    sudo ln -s /etc/nginx/sites-available/huginn /etc/nginx/sites-enabled/huginn

Make sure to edit the config file to match your setup, if you are running multiple nginx sites remove the `default_server` argument from the `listen` directives:

    # Change YOUR_SERVER_FQDN to the fully-qualified
    # domain name of your host serving Huginn.
    sudo editor /etc/nginx/sites-available/huginn

Remove the default nginx site, **if huginn is the only enabled nginx site**:

    sudo rm /etc/nginx/sites-enabled/default

**Note:** If you want to use HTTPS, which is what we recommend, replace the `huginn` Nginx config with `huginn-ssl`. See [Using HTTPS](#using-https) for HTTPS configuration details.

### Test Configuration

Validate your `huginn` or `huginn-ssl` Nginx config file with the following command:

    sudo nginx -t

You should receive `syntax is okay` and `test is successful` messages. If you receive errors check your `huginn` or `huginn-ssl` Nginx config file for typos, etc. as indicated in the error message given.

### Restart

    sudo service nginx restart

# Done!

### Initial Login

Visit YOUR_SERVER in your web browser for your first Huginn login. The setup has created a default admin account for you. You can use it to log in:

    admin (or your SEED_USERNAME)
    password (or your SEED_PASSWORD)


**Enjoy!** :sparkles: :star: :fireworks:

You can use `cd /home/huginn/huginn && sudo bundle exec rake production:start` and `cd /home/huginn/huginn && sudo bundle exec rake production:stop` to start and stop Huginn.

Be sure to read the section about how to [update](./update.md) your Huginn installation as well! You can also use [Capistrano](./capistrano.md) to keep your installation up to date.

**Note:** We also recommend applying standard security practices to your server, including installing a firewall ([ufw](https://wiki.ubuntu.com/UncomplicatedFirewall) is good on Ubuntu and also available for Debian).

## Advanced Setup Tips

### Using HTTPS

To use Huginn with HTTPS:

1. In `.env`:
    1. Set the `FORCE_SSL` option to `true`.
1. Use the `huginn-ssl` Nginx example config instead of the `huginn` config:
    1. `sudo cp deployment/nginx/huginn-ssl /etc/nginx/sites-available/huginn`
    1. Update `YOUR_SERVER_FQDN`.
    1. Update `ssl_certificate` and `ssl_certificate_key`.
    1. Review the configuration file and consider applying other security and performance enhancing features.

Restart Nginx, export the init script and restart Huginn:

```
cd /home/huginn/huginn
sudo service nginx restart
sudo bundle exec rake production:export
```

Using a self-signed certificate is discouraged, but if you must use it follow the normal directions. Then generate the certificate:

```
sudo mkdir -p /etc/nginx/ssl/
cd /etc/nginx/ssl/
sudo openssl req -newkey rsa:2048 -x509 -nodes -days 3560 -out huginn.crt -keyout huginn.key
sudo chmod o-r huginn.key
```

## Troubleshooting

If something went wrong during the installation please make sure you followed the instructions and did not miss a step.

When your Huginn instance still is not working first run the self check:

    cd /home/huginn/huginn
    sudo bundle exec rake production:check

We are sorry when you are still having issues, now please check the various log files for error messages:

#### Nginx error log `/var/log/nginx/huginn_error.log`

This file should be empty, it is the first place to look because `nginx` is the first application handling the request your are sending to Huginn.

Common problems:

* `connect() to unix:/home/huginn/huginn/tmp/sockets/unicorn.socket failed`: The Unicorn application server is not running, ensure you uncommented one of the example configuration below the `PRODUCTION` label in your [Profile](#install-init-script) and the unicorn config file (`/home/huginn/huginn/config/unicorn.rb`) exists.
* `138 open() "/home/huginn/huginn/public/..." failed (13: Permission denied)`: The `/home/huginn/huginn/public` directory needs to be readable by the nginx user (which is per default `www-data`)


#### Unicorn log `/home/huginn/huginn/log/unicorn.log`

Should only contain HTTP request log entries like: `10.0.2.2 - - [18/Aug/2015:21:15:12 +0000] "GET / HTTP/1.0" 200 - 0.0110`

If you see ruby exception backtraces or other error messages the problem could be one of the following:

* The configuration file `/home/huginn/huginn/config/unicorn.rb` does not exist
* Gem dependencies where not [installed](#install-gems)

#### Rails Application log `/home/huginn/huginn/log/production.log`

This file is pretty verbose, you want to look at it if you are getting the `We're sorry, but something went wrong.` error message when using Huginn. This is an example backtrace that can help you or other huginn developers locate the issue:

```
NoMethodError (undefined method `name' for nil:NilClass):
  app/controllers/jobs_controller.rb:6:in `index'
  config/initializers/silence_worker_status_logger.rb:5:in `call_with_silence_worker_status'
```

#### Runit/Background Worker logs `/home/huginn/huginn/log/*/current`

Those files will contain error messages or backtraces if one of your agent is not performing as they should. The easiest way to debug an Agent is to watch all your log files for changes and trigger the agent to run via the Huginn web interface.

The log file location depends your `Procfile` configuration, this command will give you a list of the available logs:

    ls -al /home/huginn/huginn/log/*/current

When you want to monitor the background processes you can easily watch all the files for changes:

    tail -f /home/huginn/huginn/log/*/current

### Still having problems? :crying_cat_face:

You probably found an error message or exception backtrace you could not resolve. Please create a new [issue](https://github.com/cantino/huginn/issues) and include as much information as you could gather about the problem your are experiencing.
