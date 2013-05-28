include_recipe 'apt'
include_recipe 'build-essential'

%w("ruby1.9.1" "ruby1.9.1-dev" "libxslt-dev" "libxml2-dev" "curl").each do |pkg|
  package pkg do
    action :install
  end
end

git "/usr/local/huginn" do
  repository 'git://github.com/cantino/huginn.git'
  reference 'master'
  action :sync
end

gem_package("rake")
gem_package("bundle")

bash "huginn dependencies" do
  user "root"
  cwd "/usr/local/huginn"
  code <<-EOH
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
    bundle install
    sed s/REPLACE_ME_NOW\!/$(rake secret)/ .env.example > .env
    rake db:create
    rake db:migrate
    rake db:seed
    EOH
end

#log "huginn start" do
#  level :info 
#  message "Huginn has been installed and wil start at your instance in two minutes"
#end

bash "Huginn has been installed and server will start in a minute" do
 user "root"
 cwd "/usr/local/huginn"
 code <<-EOH
   sudo foreman start
 EOH
end
