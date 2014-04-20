include_recipe 'apt'
include_recipe 'build-essential'

user "huginn" do
  action :create
  system true
  home "/home/huginn"
  password "$6$ZwO6b.6tij$SMa8UIwtESGDxB37NwHsct.gJfXWmmflNbH.oypwJ9y0KkzMkCdw7D14iK7GX9C4CWSEcpGOFUow7p01rQFu5."
  supports :manage_home => true
  gid "sudo"
  shell "/bin/bash"
end

group "huginn" do
  members ["huginn"]
  action :create
end

%w("ruby1.9.1" "ruby1.9.1-dev" "libxslt-dev" "libxml2-dev" "curl" "libmysqlclient-dev").each do |pkg|
  package pkg do
    action :install
  end
end

git "/home/huginn/huginn" do
  repository 'git://github.com/cantino/huginn.git'
  reference 'master'
  action :sync
  user "huginn"
end

gem_package("rake")
gem_package("bundle")

bash "Setting huginn user with NOPASSWD option" do
  cwd "/etc/sudoers.d"
  code <<-EOH
    touch huginn
    chmod 0440 huginn
    echo "huginn ALL=(ALL) NOPASSWD:ALL" >> huginn
    EOH
end

bash "huginn dependencies" do
  user "huginn"
  cwd "/home/huginn/huginn"
  code <<-EOH
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
    sudo bundle install
    sed s/REPLACE_ME_NOW\!/$(sudo rake secret)/ .env.example > .env
    sudo bundle exec rake db:create
    sudo bundle exec rake db:migrate
    sudo bundle exec rake db:seed
    EOH
end

bash "huginn has been installed and will start in a minute" do
  user "huginn"
  cwd "/home/huginn/huginn"
  code <<-EOH
    sudo foreman start
    EOH
end
