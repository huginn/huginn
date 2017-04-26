# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  config.vm.box = "boxcutter/ubuntu1604"


  config.vm.network "forwarded_port", guest: 3000, host: 3000, auto_correct: true

  config.vm.provider "virtualbox" do |vb|
   vb.memory = "1024"
  end

  ## SETTING UP BASE SYSTEM ##
  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    apt-get -y update
    apt-get -y install build-essential
    apt-get -y install zlib1g-dev git-core nodejs

    # Install MySQL
    debconf-set-selections <<< "mysql-server-5.5 mysql-server/root_password password root"
    debconf-set-selections <<< "mysql-server-5.5 mysql-server/root_password_again password root"
    apt-get -y install mysql-server mysql-client libmysqlclient-dev

    apt-get install -y autoconf bison build-essential libssl-dev libyaml-dev
    apt-get install -y libreadline6-dev zlib1g-dev libncurses5-dev
    apt-get install -y libgdbm3 libgdbm-dev libsqlite3-dev
    apt-get install -y libreadline-dev libssl-dev libffi-dev libcurl3
    apt-get install -y libxml2-dev libxslt1-dev python-software-properties

  SHELL

  ## USING RUBY ENV ###
  config.vm.provision 'shell', privileged: false, inline: <<-SHELL
    # download rbenv if the directory is missing
    if cd ~/.rbenv && git rev-parse --verify --short=26 HEAD | grep -q $RBENV_VERSION; then
      echo 'rbenv already downloaded at expected revision'
    else
      git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
      cd ~/.rbenv && git checkout $RBENV_VERSION
    fi
    # download ruby-build if the directory is missing
    if cd ~/.rbenv/plugins/ruby-build && git rev-parse --verify --short=26 HEAD | grep -q $RBBUILD_VERSION; then
      echo 'ruby-build already downloaded at expected revision'
    else
      git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
      cd ~/.rbenv/plugins/ruby-build && git checkout $RBBUILD_VERSION
    fi

    RBENV_PATH='export PATH="$HOME/.rbenv/bin:$PATH"'
    if grep -q "$RBENV_PATH" ~/.bash_profile ; then
      echo 'rbenv path already in .bash_profile'
    else
      echo $RBENV_PATH >> ~/.bash_profile
    fi

    RBENV_INIT='eval "$(rbenv init -)"'
    if grep -q "$RBENV_INIT" ~/.bash_profile ; then
      echo 'rbenv init already in .bash_profile'
    else
      echo $RBENV_INIT >> ~/.bash_profile
    fi
  SHELL

  config.vm.provision 'shell', privileged: false, inline: <<-SHELL
   rbenv install 2.3.4
   rbenv global 2.3.4
  SHELL



  config.vm.provision 'shell', privileged: false, inline: <<-SHELL
   echo "gem: --no-document" > ~/.gemrc
   gem install bundler

   echo 'export RAILS_ENV=development' >> ~/.bash_profile
   echo 'cd /vagrant' >> ~/.bash_profile

   cd /vagrant
   cp .env.example .env
   sed -i 's/DATABASE_PASSWORD=""/DATABASE_PASSWORD="root"/g' .env

   bundle install
   RAILS_ENV=development bundle exec rake db:create
   RAILS_ENV=development bundle exec rake db:migrate
   RAILS_ENV=development bundle exec rake db:schema:load
   RAILS_ENV=development bundle exec rake db:seed

   echo 'alias huginn-server="rails server -b 0.0.0.0"' >> ~/.bash_profile
   echo 'alias huginn-worker="nohup bundle exec rails runner bin/threaded.rb > tmp/worker.log &"' >> ~/.bash_profile

   echo "-------"
   echo "Use: '$: huginn-worker' command to start the worker in the background with output redirected to tmp/worker.log"
   echo "Use: '$: huginn-server' command to start the server "
  SHELL

end
