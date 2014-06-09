service "nginx" do
  supports :restart => true, :start => true, :stop => true, :reload => true
  action :nothing
end

service "huginn" do
  provider Chef::Provider::Service::Upstart
  supports :restart => true, :start => true, :stop => true
  action :nothing
end

deploy "/home/huginn" do
  repo node['huginn']['repo']
  branch node['huginn']['branch']
  keep_releases node['huginn']['keep_releases' ]
  rollback_on_error true

  user "huginn"
  group "huginn"
  
  environment "RAILS_ENV" => node['huginn']['rails_env']

  create_dirs_before_symlink []
  symlinks({
    "log" => "log",
    "config/Procfile" => "Procfile",
    "config/.env" => ".env",
    "config/unicorn.rb" => "/config/unicorn.rb"
  })
  symlink_before_migrate({})


  before_symlink do
    %w(config log tmp tmp/pids tmp/sockets).each do |dir|
      directory "/home/huginn/shared/#{dir}" do
        owner "huginn"
        group "huginn"
        recursive true
      end
    end

    %w(Procfile unicorn.rb nginx.conf).each do |file|
      cookbook_file "/home/huginn/shared/config/#{file}" do
        owner "huginn"
        action :create_if_missing
      end
    end

    cookbook_file "/home/huginn/shared/config/.env" do
      source "env.example"
      mode "666"
      owner "huginn"
      action :create  # Upload a fresh copy, it will be configured from chef settings automagically
    end
  end

  before_restart do
    rbenv_script "Huginn - Bundle, edit config, compile assets" do
      group "huginn"
      rbenv_version node['rbenv']['ruby_version']
      cwd "/home/huginn/current"
      environment({
        "LANG" => "en_US.UTF-8",
        "LC_ALL" => "en_US.UTF-8",
        "RAILS_ENV" => "production"
      })
      code <<-EOH
        # Install gems
        echo 'gem "unicorn", :group => :production' >> Gemfile
        bundle install --without=development --without=test
        rbenv rehash

        # Fix Procfile to work with rbenv
        sed -i s/RAILS_ENV=production\ bundle\ exec/rbenv\ sudo/ /home/huginn/shared/config/Procfile
        sed -i s/bundle\ exec/rbenv\ sudo/ /home/huginn/shared/config/Procfile

        # Configure .env file
        sed -i s/REPLACE_ME_NOW\!/$(rake secret)/ /home/huginn/shared/config/.env
        sed -i s/\=try-huginn/\=#{node['huginn']['env']['invitation_code']}/ /home/huginn/shared/config/.env
      EOH
    end

    rbenv_script "Huginn - Create/Seed Database (if first time)" do
      group "huginn"
      rbenv_version node['rbenv']['ruby_version']
      cwd "/home/huginn/current"
      creates "/home/huginn/shared/RAKE-DB-CREATED"
      environment({
        "LANG" => "en_US.UTF-8",
        "LC_ALL" => "en_US.UTF-8",
        "RAILS_ENV" => "production"
      })
      code <<-EOH
        bundle exec rake db:create
        bundle exec rake db:migrate
        bundle exec rake db:seed

        # This prevents the db:create db:seed from happening again in future
        echo 1 > /home/huginn/shared/RAKE-DB-CREATED
      EOH
    end

    rbenv_script "Huginn - Perform migrations and precompile assets" do
      group "huginn"
      rbenv_version node['rbenv']['ruby_version']
      cwd "/home/huginn/current"
      environment({
        "LANG" => "en_US.UTF-8",
        "LC_ALL" => "en_US.UTF-8",
        "RAILS_ENV" => "production"
      })
      code <<-EOH
        bundle exec rake db:migrate
        bundle exec rake assets:precompile
      EOH
    end

    rbenv_script "Huginn - Setup nginx/foreman configs" do
      group "huginn"
      rbenv_version node['rbenv']['ruby_version']
      cwd "/home/huginn/current"
      environment({
        "LANG" => "en_US.UTF-8",
        "LC_ALL" => "en_US.UTF-8",
        "RAILS_ENV" => "production"
      })
      code <<-EOH
        sudo cp /home/huginn/shared/config/nginx.conf /etc/nginx/
        rbenv sudo foreman export upstart /etc/init -a huginn -u huginn -l log
      EOH
    end
  end

  notifies :enable, "service[huginn]"
  notifies :start, "service[huginn]"

  notifies :enable, "service[nginx]"
  notifies :start, "service[nginx]"
end