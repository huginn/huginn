include_recipe "rbenv::system"

rbenv_ruby node["rbenv"]["ruby_version"] do
  action :install
end

%w(bundler).each do |gem_name|
  rbenv_gem gem_name do
    rbenv_version  node["rbenv"]["ruby_version"]
  end
end


case node['platform']
when "centos"
  packages = %w(libxslt-devel libxml2-devel mysql-devel curl libffi-devel libssl-devel)
else
  packages = %w(libxslt-dev libxml2-dev curl libmysqlclient-dev libffi-dev libssl-dev)
end

packages.each do |pkg|
  package pkg
end

