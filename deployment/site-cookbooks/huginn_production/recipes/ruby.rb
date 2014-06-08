# TODO Shift
%w(ruby1.9.1 ruby1.9.1-dev).each do |pkg|
  package pkg
end

case node['platform']
when "centos"
  packages = %w(libxslt-devel libxml2-devel libmysqlclient-devel curl libffi-devel libssl-devel)
else
  packages = %w(libxslt-dev libxml2-dev curl libmysqlclient-dev libffi-dev libssl-dev)
end

packages.each do |pkg|
  package pkg
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
