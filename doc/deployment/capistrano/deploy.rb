default_run_options[:pty] = true

set :application, "huginn"
set :deploy_to, "/home/you/app"
set :user, "you"
set :use_sudo, false
set :scm, :git
set :rails_env, 'production'
set :repository, "git@github.com:you/huginn-private.git"
set :branch, "master"
set :deploy_via, :remote_cache
set :keep_releases, 5

set :bundle_without, [:development]
set :unicorn_pid, "#{shared_path}/pids/unicorn.pid"

server "yourdomain.com", :app, :delayed_job, :web, :db, :primary => true

set :delayed_job_server_role, :delayed_job

set :sync_backups, 3

before 'deploy:restart', 'deploy:migrate'
after 'deploy', 'deploy:cleanup'

set :bundle_without, [:development, :test]

after 'deploy:stop', 'delayed_job:stop'
after 'deploy:start', 'delayed_job:start'
after 'deploy:restart', 'delayed_job:restart'
after 'deploy:update_code', 'deploy:symlink_env_config'

namespace :deploy do
  desc 'Link the environment file from shared/config/.env into the new deploy directory'
  task :symlink_env_config, :roles => :app do
    run <<-CMD
      cd #{latest_release} && ln -nfs #{shared_path}/config/.env #{latest_release}/.env
    CMD
  end
end

# If you want to use command line options, for example to start multiple workers,
# define a Capistrano variable delayed_job_args:
#
#   set :delayed_job_args, "-n 2"

# If you want to use rvm on your server and have it maintained by Capistrano, uncomment these lines:
#   set :rvm_ruby_string, '1.9.3-p286@huginn'
#   set :rvm_type, :user
#   before 'deploy', 'rvm:install_rvm'
#   before 'deploy', 'rvm:install_ruby'
#   require "rvm/capistrano"

# Load Capistrano additions
Dir[File.expand_path("../../lib/capistrano/*.rb", __FILE__)].each{|f| load f }

require "bundler/capistrano"
require "capistrano-unicorn"
require "delayed/recipes"
load 'deploy/assets'
