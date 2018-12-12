require 'dotenv'
Dotenv.load

# config valid only for current version of Capistrano
lock '3.11.0'

set :application, 'huginn'
set :repo_url, ENV['CAPISTRANO_DEPLOY_REPO_URL'] || 'https://github.com/huginn/huginn.git'

# Default branch is :master
set :branch, ENV['CAPISTRANO_DEPLOY_BRANCH'] || ENV['BRANCH'] || 'master'

set :deploy_to, '/home/huginn'

# Set to :debug for verbose ouput
set :log_level, :info

# Default value for :linked_files is []
set :linked_files, fetch(:linked_files, []).push('.env', 'Procfile', 'config/unicorn.rb')

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle')

# Default value for keep_releases is 5
# set :keep_releases, 5

set :bundle_jobs, 4

set :conditionally_migrate, true # Defaults to false. If true, it's skip migration if files in db/migrate not modified

task :deploy => [:production]

namespace :deploy do
  after 'check:make_linked_dirs', :migrate_to_cap do
    on roles(:all) do
      # Try to migrate from the manual installation to capistrano directory structure
      next if test('[ -L ~/huginn ]')
      fetch(:linked_files).each do |f|
        if !test("[ -f ~/shared/#{f} ] ") && test("[ -f ~/huginn/#{f} ]")
          execute("cp ~/huginn/#{f} ~/shared/#{f}")
        end
      end
      execute('mv ~/huginn ~/huginn.manual')
      execute('ln -s ~/current ~/huginn')
    end
  end
  after :publishing, :restart do
    on roles(:all) do
      within release_path do
        execute :rake, 'production:restart'
      end
    end
  end
end
