include_recipe "rbenv::system"

rbenv_ruby node["rbenv"]["ruby_version"]

rbenv_gem "rake"
rbenv_gem "bundle"


case node['platform']
when "centos"
  packages = %w(libxslt-devel libxml2-devel mysql-devel curl libffi-devel libssl-devel)
else
  packages = %w(libxslt-dev libxml2-dev curl libmysqlclient-dev libffi-dev libssl-dev)
end

packages.each do |pkg|
  package pkg
end

