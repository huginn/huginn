service "nginx" do
  supports :restart => true, :start => true, :stop => true, :reload => true
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
    %w(config log tmp).each do |dir|
      directory "/home/huginn/shared/#{dir}" do
        owner "huginn"
        group "huginn"
        recursive true
      end
    end

    directory "/home/huginn/shared/tmp/pids"
    directory "/home/huginn/shared/tmp/sockets"

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
      action :create_if_missing
    end
  end

  before_restart do
    bash "huginn dependencies" do
      cwd "/home/huginn/current"
      user "huginn"
      group "huginn"
      code <<-EOH
      export LANG="en_US.UTF-8"
      export LC_ALL="en_US.UTF-8"
      ln -nfs /home/huginn/shared/config/Procfile ./Procfile
      ln -nfs /home/huginn/shared/config/.env ./.env
      ln -nfs /home/huginn/shared/config/unicorn.rb ./config/unicorn.rb
      sudo cp /home/huginn/shared/config/nginx.conf /etc/nginx/
      echo 'gem "unicorn", :group => :production' >> Gemfile
      sudo bundle install --without=development --without=test
      sed -i s/REPLACE_ME_NOW\!/$(sudo bundle exec rake secret)/ /home/huginn/shared/config/.env
      sudo RAILS_ENV=production bundle exec rake db:create
      sudo RAILS_ENV=production bundle exec rake db:migrate
      sudo RAILS_ENV=production bundle exec rake db:seed
      sudo RAILS_ENV=production bundle exec rake assets:precompile
      sudo foreman export upstart /etc/init -a huginn -u huginn -l log
      sudo start huginn
      EOH
    end
  end
  
  notifies :enable, "service[nginx]"
  notifies :start, "service[nginx]"
end