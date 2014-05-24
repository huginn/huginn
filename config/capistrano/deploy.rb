# config valid only for Capistrano 3.1
lock '3.2.1'

set :application, 'huginn'
set :repo_url, 'git@github.com:alias1/huginn-private.git'

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call
# set :branch, ENV['BRANCH'] || "master"
set :branch, 'digitalocean'

# Default deploy_to directory is /var/www/my_app
set :deploy_to, '/home/huginn/app'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :info

# Default value for :pty is false
set :pty, true

# Default value for :linked_files is []
# set :linked_files, %w{config/database.yml}
set :linked_files, %w{.env}

# Default value for linked_dirs is []
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Rbenv (https://github.com/capistrano/rbenv)
set :rbenv_type, :user # or :system, depends on your rbenv setup
set :rbenv_ruby, '2.1.2'
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w{rake gem bundle ruby rails}
# set :rbenv_roles, :all # default value

# Bundler (https://github.com/capistrano/bundler)
# set :bundle_roles, :all                                  # this is default
# set :bundle_servers, -> { release_roles(fetch(:bundle_roles)) } # this is default
# set :bundle_binstubs, -> { shared_path.join('bin') }     # this is default
# set :bundle_gemfile, -> { release_path.join('MyGemfile') } # default: nil
# set :bundle_path, -> { shared_path.join('bundle') }      # this is default
# set :bundle_without, %w{development test}.join(' ')      # this is default
# set :bundle_flags, '--deployment --quiet'                # this is default
# set :bundle_env_variables, {}                    # this is default
# set :bundle_jobs, 4 #This is only available for bundler 1.4+
# set :bundle_env_variables, { foo: "bar" }

# Rails (https://github.com/capistrano/rails)
# set :rails_env, 'production' # If the environment differs from the stage name

# sync.rb (https://gist.github.com/LRDesign/339471)
# set :sync_directories, ["public/assets", "public/galleries"]
set :sync_backups, 3

set :use_sudo, false # deploy:restart, deploy:cleanup, etc

# Capistrano task to upload configuration files outside SCM
# https://gist.github.com/Jesus/448d618c83fb0445ebbf

# TODO
# http://capitate.rubyforge.org/recipes/sshd.html
# http://capitate.rubyforge.org/recipes/mysql-centos.html
# http://capitate.rubyforge.org/recipes/nginx-centos.html
# https://github.com/capistrano/capistrano/wiki/Capistrano-Tasks

# puts "    Deploying #{fetch(:branch})"

# http://capistranorb.com/documentation/getting-started/flow/
# before 'deploy:restart', 'deploy:migrate' # https://github.com/capistrano/capistrano/wiki/Capistrano-Tasks#deploymigrate
# after 'deploy', 'deploy:cleanup' # https://github.com/capistrano/capistrano/wiki/Capistrano-Tasks#deploycleanup

# after 'deploy:update', 'foreman:export' # TODO: Move this into/call this from deploy:restart?
# after 'deploy:update', 'foreman:restart'

namespace :precheck do

desc "Check that we can access everything"
task :check_write_permissions do
  on roles(:all) do |host|
    if test("[ -w #{fetch(:deploy_to)} ]")
      info "#{fetch(:deploy_to)} is writable on #{host}"
    else
      error "#{fetch(:deploy_to)} is not writable on #{host}"
    end
  end
end

# lib/capistrano/tasks/agent_forwarding.rake
    desc "Check if agent forwarding is working"
    task :check_ssh_forwarding do
      on roles(:all) do |h|
        if test("env | grep SSH_AUTH_SOCK")
          info "Agent forwarding is up to #{h}"
        else
          error "Agent forwarding is NOT up to #{h}"
        end
      end
    end

  # task check: :'git:wrapper' do <-- git:wrapper is prereq for check (https://github.com/capistrano/capistrano/blob/master/lib/capistrano/tasks/git.rake#L24)
  # task 'deploy:default' => 'chef-solo:default' <-- reeopens deploy:default and makes it depend on chef.. (http://lee.hambley.name/2013/06/11/using-capistrano-v3-with-chef.html)
end

namespace :huginn do

  desc 'Setup config files'
  task :setup_configs do
    on roles(:app), in: :sequence, wait: 5 do
      # TODO https://github.com/capistrano/sshkit/blob/master/EXAMPLES.md
      #   Copy .env to .env.example
      #   Ask user for values to put into .env
      #     Inclue the value from `rake secret`
      #   Any other config files needed?
    end
  end

  desc "Setup Database"
  task :setup_database do
    on roles(:app) do |host|
      info "Testing #{host}"
      within :latest_release do
        info  capture(:whoami && :pwd)
        # run "rake db:create && rake db:migrate && db:seed"
      end
    end
  end
end


namespace :deploy do

  # # TODO Surely this should be achievable with linked_files ??
  # desc 'Link the .env environment and Procfile from shared/config into the new deploy directory'
  # task :symlink_configs do
  #   on roles(:app) do |host|
  #     run <<-CMD
  #       cd #{fetch(:latest_release)} && ln -nfs #{fetch(:shared_path)}/config/.env #{fetch(:latest_release)}/.env
  #     CMD

  #     run <<-CMD
  #       cd #{fetch(:latest_release)} && ln -nfs #{fetch(:shared_path)}/config/Procfile #{fetch(:latest_release)}/Procfile
  #     CMD
  #   end
  # end

#   desc 'Restart application'
#   task :restart do
#     on roles(:app), in: :sequence, wait: 5 do
#       # Your restart mechanism here, for example:
#       # execute :touch, release_path.join('tmp/restart.txt')
#     end
#   end

#   after :publishing, :restart

#   after :restart, :clear_cache do
#     on roles(:web), in: :groups, limit: 3, wait: 10 do
#       # Here we can do anything such as:
#       # within release_path do
#       #   execute :rake, 'cache:clear'
#       # end
#     end
#   end

end

namespace :foreman do

  desc "Export the Procfile to Ubuntu's upstart scripts"
  task :export do
    on roles(:app) do |host|
      run "cd #{latest_release} && rbenv sudo bundle exec foreman export upstart /etc/init -a #{application} -u #{user} -l #{deploy_to}/upstart_logs"
    end
  end

  desc 'Start the application services'
  task :start do
    on roles(:app) do |host|
      sudo "sudo start #{application}"
    end
  end

  desc 'Stop the application services'
  task :stop do
    on roles(:app) do |host|
      sudo "sudo stop #{application}"
    end
  end

  desc 'Restart the application services'
  task :restart do
    on roles(:app) do |host|
      run "sudo start #{application} || sudo restart #{application}"
    end
  end

end

# before 'deploy:updated', 'huginn:setup_database'
# after 'deploy:updated', 'deploy:symlink_configs'
# after 'deploy:publishing', 'deploy:restart' # Not run by default since 3.1.0
