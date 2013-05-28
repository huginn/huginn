include_recipe 'apt'
include_recipe 'build-essential'

user "huginn" do
  action :create
  system true
  home "/home/huginn"
  password "$6$ZwO6b.6tij$SMa8UIwtESGDxB37NwHsct.gJfXWmmflNbH.oypwJ9y0KkzMkCdw7D14iK7GX9C4CWSEcpGOFUow7p01rQFu5."
  supports :manage_home => true
  shell "/bin/bash"
  gid "sudo"
end

group "huginn" do
  members ["huginn"]
  action :create
end

%w("ruby1.9.1" "ruby1.9.1-dev" "libxslt-dev" "libxml2-dev" "curl" "libshadow-ruby1.8").each do |pkg|
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

cookbook_file "/etc/nginx/nginx.conf" do
  source "nginx.conf"
  owner "huginn"
end

directory "/home/huginn/huginn/tmp" do
  action :create
  owner "huginn"
  recursive true
end

directory "/home/huginn/huginn/log" do
  action :create
  owner "huginn"
  recursive true
end

cookbook_file "/home/huginn/huginn/config/unicorn.rb" do
  source "unicorn.rb"
  mode "644"
  owner "huginn"
end

cookbook_file "home/huginn/huginn/Gemfile" do
  source "Gemfile"
  mode "644"
  owner "huginn"
end

cookbook_file "home/huginn/huginn/.env" do
  source ".env"
  mode "666"
  owner "huginn"
end

cookbook_file "home/huginn/huginn/Procfile" do
  source "Procfile"
  mode "444"
  owner "huginn"
end

service "nginx" do
  action :start
end

bash "Setting huginn user with NOPASSWD option" do
  cwd "/etc/sudoers.d"
  code <<-EOH
    echo 'huginn ALL=(ALL) NOPASSWD:ALL' >> 90-cloudimg-ubuntu
  EOH
end

bash "huginn dependencies" do
  cwd "/home/huginn/huginn"
  user "huginn"
  code <<-EOH
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
    sudo bundle install
    sed -i s/REPLACE_ME_NOW\!/$(sudo rake secret)/ .env
    sudo rake db:create
    sudo rake db:migrate
    sudo rake db:seed
    sudo foreman export upstart /etc/init -a huginn -u huginn
    sudo start huginn
    EOH
end
