set :deploy_config_path, 'config/capistrano/deploy.rb'
set :stage_config_path, 'config/capistrano/deploy'

# Load DSL and Setup Up Stages
require 'capistrano/setup'

# Includes default deployment tasks
require 'capistrano/deploy'

# Includes tasks from other gems included in your Gemfile

# Capitate (http://capitate.rubyforge.org/)
# See https://github.com/gabriel/capitate/blob/master/lib/deployment/centos-5.1-64-web/install.rb
# require 'capitate'
# require 'capitate/recipes'
# set :project_root, File.dirname(__FILE__)

#
# For documentation on these, see for example:
#
#   https://github.com/capistrano/rvm
#   https://github.com/capistrano/rbenv
#   https://github.com/capistrano/chruby
#   https://github.com/capistrano/bundler
#   https://github.com/capistrano/rails
#
# require 'capistrano/rvm'
require 'capistrano/rbenv'
# require 'capistrano/chruby'
require 'capistrano/bundler'
require 'capistrano/rails/assets'
require 'capistrano/rails/migrations'

# Loads custom tasks from `lib/capistrano/tasks' if you have any defined.
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }

# Set a default stage NB: Comment this out if you are using multiple staging!!!!!!
invoke :production
