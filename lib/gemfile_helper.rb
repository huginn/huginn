class GemfileHelper
  class << self
    def load_dotenv
      dotenv_dir = Dir[File.join(File.dirname(__FILE__), '../vendor/gems/dotenv-[0-9]*')].sort.last

      yield dotenv_dir

      return if ENV['ON_HEROKU'] == 'true'

      $:.unshift File.join(dotenv_dir, 'lib')
      require "dotenv"
      $:.shift

      root = Pathname.new(File.join(File.dirname(__FILE__), '..'))
      sanity_check Dotenv.load(
                                root.join(".env.local"),
                                root.join(".env.#{ENV['RAILS_ENV'] || 'development'}"),
                                root.join(".env")
                              )
    end

    private

    def sanity_check(env)
      return if ENV['CI'] == 'true' || !env.empty?
      puts warning
      raise "Could not load huginn settings from .env file."
    end

    def warning
      <<-EOF
Could not load huginn settings from .env file.

Make sure to copy the .env.example to .env and change it to match your configuration.

Capistrano 2 users: Make sure shared files are symlinked before bundle runs: before 'bundle:install', 'deploy:symlink_configs'
EOF
    end
  end
end