# This is an example Capistrano deployment script for Huginn.  It
# assumes you're running on an Ubuntu box and want to use Foreman,
# Upstart, and Unicorn.

default_run_options[:pty] = true

set :application, "huginn"
set :deploy_to, "/home/you/app"
set :user, "you"
set :use_sudo, false
set :scm, :git
set :rails_env, 'production'
set :repository, "git@github.com:you/huginn-private.git"
set :branch, ENV['BRANCH'] || "master"
set :deploy_via, :remote_cache
set :keep_releases, 5

puts "    Deploying #{branch}"

set :bundle_without, [:development]

server "yourdomain.com", :app, :web, :db, :primary => true

set :sync_backups, 3

before 'deploy:restart', 'deploy:migrate'
after 'deploy', 'deploy:cleanup'

set :bundle_without, [:development, :test]

after 'deploy:update_code', 'deploy:symlink_configs'
after 'deploy:update', 'foreman:export'
after 'deploy:update', 'foreman:restart'

namespace :deploy do
  desc 'Link the .env environment and Procfile from shared/config into the new deploy directory'
  task :symlink_configs, :roles => :app do
    run <<-CMD
      cd #{latest_release} && ln -nfs #{shared_path}/config/.env #{latest_release}/.env
    CMD

    run <<-CMD
      cd #{latest_release} && ln -nfs #{shared_path}/config/Procfile #{latest_release}/Procfile
    CMD
  end
end

namespace :foreman do
  desc "Export the Procfile to Ubuntu's upstart scripts"
  task :export, :roles => :app do
    run "cd #{latest_release} && rvmsudo bundle exec foreman export upstart /etc/init -a #{application} -u #{user} -l #{deploy_to}/upstart_logs"
  end

  desc 'Start the application services'
  task :start, :roles => :app do
    sudo "sudo start #{application}"
  end

  desc 'Stop the application services'
  task :stop, :roles => :app do
    sudo "sudo stop #{application}"
  end

  desc 'Restart the application services'
  task :restart, :roles => :app do
    run "sudo start #{application} || sudo restart #{application}"
  end
end

# If you want to use rvm on your server and have it maintained by Capistrano, uncomment these lines:
#   set :rvm_ruby_string, '2.3.4@huginn'
#   set :rvm_type, :user
#   before 'deploy', 'rvm:install_rvm'
#   before 'deploy', 'rvm:install_ruby'
#   require "rvm/capistrano"

# Load Capistrano additions
Dir[File.expand_path("../../lib/capistrano/*.rb", __FILE__)].each{|f| load f }

require "bundler/capistrano"
load 'deploy/assets'
