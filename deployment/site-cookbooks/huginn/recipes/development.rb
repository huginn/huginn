git "/home/huginn/huginn" do
  repository 'git://github.com/cantino/huginn.git'
  reference 'master'
  action :sync
  user "huginn"
end

bash "huginn dependencies" do
  user "huginn"
  cwd "/home/huginn/huginn"
  code <<-EOH
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
    sudo bundle install
    sed s/REPLACE_ME_NOW\!/$(sudo bundle exec rake secret)/ .env.example > .env
    sudo bundle exec rake db:create
    sudo bundle exec rake db:migrate
    sudo bundle exec rake db:seed
    EOH
end

bash "huginn has been installed and will start in a minute" do
  user "huginn"
  cwd "/home/huginn/huginn"
  code <<-EOH
    sudo nohup foreman start &
    EOH
end
