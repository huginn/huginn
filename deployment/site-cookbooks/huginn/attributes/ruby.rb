default['rbenv']['ruby_version'] = "1.9.3-p547"

default['huginn']['repo'] = "https://github.com/cantino/huginn.git"
default['huginn']['branch'] = "master"
default['huginn']['rails_env'] = "production"
default['huginn']['keep_releases'] = 5
default['huginn']['user'] = "huginn"
default['huginn']['group'] = "huginn"
default['huginn']['deploy_path'] = "/home/#{node['huginn']['user']}"
default['huginn']['env']['invitation_code'] = "try-huginn-secretly"