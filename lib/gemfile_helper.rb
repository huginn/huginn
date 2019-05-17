class GemfileHelper
  class << self
    def rails_env
      ENV['RAILS_ENV'] ||
        case File.basename($0)
        when 'rspec'
          'test'
        when 'rake'
          'test' if ARGV.any? { |arg| /\Aspec(?:\z|:)/ === arg }
        end || 'development'
    end

    def load_dotenv
      dotenv_dir = Dir[File.join(File.dirname(__FILE__), '../vendor/gems/dotenv-[0-9]*')].sort.last

      yield dotenv_dir if block_given?

      return if ENV['ON_HEROKU'] == 'true'

      $:.unshift File.join(dotenv_dir, 'lib')
      require "dotenv"
      $:.shift

      root = Pathname.new(File.join(File.dirname(__FILE__), '..'))
      sanity_check Dotenv.load(
                                root.join(".env.local"),
                                root.join(".env.#{rails_env}"),
                                root.join(".env")
                              )
    end

    GEM_NAME = '[A-Za-z0-9\.\-\_]+'.freeze
    GEM_OPTIONS = '(.+?)\s*(?:,\s*(.+?)){0,1}'.freeze
    GEM_SEPARATOR = '\s*(?:,|\z)'.freeze
    GEM_REGULAR_EXPRESSION = /(#{GEM_NAME})(?:\(#{GEM_OPTIONS}\)){0,1}#{GEM_SEPARATOR}/

    def parse_each_agent_gem(string)
      return unless string
      string.scan(GEM_REGULAR_EXPRESSION).each do |name, version, args|
        if version =~ /\w+:/
          args = "#{version},#{args}"
          version = nil
        end
        yield [name, version, parse_gem_args(args)].compact
      end
    end

    private

    def parse_gem_args(args)
      return nil unless args
      options = {}
      args.scan(/(\w+):\s*(.+?)#{GEM_SEPARATOR}/).each do |key, value|
        options[key.to_sym] = value
      end
      options
    end

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
