include_recipe 'apt' if platform?('ubuntu', 'debian')
include_recipe 'yum-epel' if platform_family?('rhel')
include_recipe 'build-essential'

if platform_family?('rhel')
  # graphviz*
  %w(curl libxslt-devel libxml2-devel mysql-devel libffi-devel openssl-devel).each do |pkg|
    package("#{pkg}")
  end
else
  %w(curl libxslt-dev libxml2-dev libmysqlclient-dev libffi-dev libssl-dev).each do |pkg|
    package("#{pkg}")
  end
end

# rbenv_ruby "1.9.3-p547"

# rbenv_gem "rake"
# rbenv_gem "bundle"
# gem_package("rake")
# gem_package("bundle")

# rbenv_plugin 'rbenv-sudo' do
#   git_url 'https://github.com/dcarley/rbenv-sudo.git'
# end

# rbenv_rehash "Rbenv rehashing"


# bash "Setting default ruby and gem versions to 1.9" do
#   code <<-EOH
#     if [ $(readlink /usr/bin/ruby) != "ruby1.9.1" ]
#     then
#       update-alternatives --set ruby /usr/bin/ruby1.9.1
#     fi

#     if [ $(readlink /usr/bin/gem) != "gem1.9.1" ]
#     then
#       update-alternatives --set gem /usr/bin/gem1.9.1
#     fi
#   EOH
# end

service "nginx" do
  supports :restart => true, :start => true, :stop => true, :reload => true
  action :nothing
end
