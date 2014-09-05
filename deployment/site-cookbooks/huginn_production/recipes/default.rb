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

%w("ruby1.9.1" "ruby1.9.1-dev" "libxslt-dev" "libxml2-dev" "curl" "libmysqlclient-dev" "libffi-dev" "libssl-dev").each do |pkg|
  package("#{pkg}")
end

bash "Setting default ruby and gem versions to 1.9" do
  code <<-EOH
    if [ $(readlink /usr/bin/ruby) != "ruby1.9.1" ]
    then
      update-alternatives --set ruby /usr/bin/ruby1.9.1
    fi

    if [ $(readlink /usr/bin/gem) != "gem1.9.1" ]
    then
      update-alternatives --set gem /usr/bin/gem1.9.1
    fi
  EOH
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
  branch "master"
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
    %w(Procfile unicorn.rb nginx.conf).each do |file|
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
end
