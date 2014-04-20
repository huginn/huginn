include_recipe 'apt'
include_recipe 'build-essential'

user "huginn" do
  system true
  home "/home/huginn"
  password "$6$ZwO6b.6tij$SMa8UIwtESGDxB37NwHsct.gJfXWmmflNbH.oypwJ9y0KkzMkCdw7D14iK7GX9C4CWSEcpGOFUow7p01rQFu5."
  supports :manage_home => true
  shell "/bin/bash"
  gid "sudo"
end

group "huginn" do
  members ["huginn"]
end

%w("ruby1.9.1" "ruby1.9.1-dev" "libxslt-dev" "libxml2-dev" "curl" "libshadow-ruby1.8" "libmysqlclient-dev").each do |pkg|
  package("#{pkg}")
end

gem_package("rake")
gem_package("bundle")

service "nginx" do
  supports :restart => true, :start => true, :stop => true, :reload => true
  action :nothing
end

bash "Setting huginn user with NOPASSWD option" do
  cwd "/etc/sudoers.d"
  code <<-EOH
    touch huginn && chmod 0440 huginn 
    echo "huginn ALL=(ALL) NOPASSWD:ALL" >> huginn
  EOH
end

deploy "/home/huginn" do
  repo "https://github.com/cantino/huginn.git"
  user "huginn"
  group "huginn"
  environment "RAILS_ENV" => "production"
  keep_releases 5
  create_dirs_before_symlink []
  symlinks "log" => "log"
  symlink_before_migrate({})
  rollback_on_error true
  notifies :enable, "service[nginx]"
  notifies :start, "service[nginx]"
  before_symlink do
    %w(config log tmp).each do |dir|
      directory "/home/huginn/shared/#{dir}" do
      owner "huginn"
      group "huginn"
      recursive true
      end
    end
    directory("/home/huginn/shared/tmp/pids")
    directory("/home/huginn/shared/tmp/sockets")
    %w(Procfile unicorn.rb Gemfile nginx.conf).each do |file|
      cookbook_file "/home/huginn/shared/config/#{file}" do
      owner "huginn"
      action :create_if_missing
      end
    end
    cookbook_file "home/huginn/shared/config/.env" do
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
      ln -nfs /home/huginn/shared/config/Gemfile ./Gemfile
      ln -nfs /home/huginn/shared/config/Procfile ./Procfile
      ln -nfs /home/huginn/shared/config/.env ./.env
      ln -nfs /home/huginn/shared/config/unicorn.rb ./config/unicorn.rb
      sudo cp /home/huginn/shared/config/nginx.conf /etc/nginx/ 
      sudo bundle install
      sed -i s/REPLACE_ME_NOW\!/$(sudo rake secret)/ .env
      sudo bundle exec rake db:create
      sudo bundle exec rake db:migrate
      sudo bundle exec rake db:seed
      sudo foreman export upstart /etc/init -a huginn -u huginn -l log
      sudo start huginn
      EOH
    end
  end
end
