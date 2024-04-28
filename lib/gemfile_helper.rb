class GemfileHelper
  class << self
    def rails_env
      ENV['RAILS_ENV'] ||
        case File.basename($0)
        when 'rspec'
          'test'
        when 'rake'
          'test' if ARGV.any?(/\Aspec(?:\z|:)/)
        end || 'development'
    end

    def load_dotenv
      root = Pathname.new(__dir__).parent
      dotenv_dir = (root / 'vendor/gems').glob('dotenv-[0-9]*').last

      yield dotenv_dir.to_s if block_given?

      return if ENV['ON_HEROKU'] == 'true'

      $:.unshift dotenv_dir.join('lib').to_s
      require "dotenv"
      $:.shift

      sanity_check Dotenv.load(
        root.join(".env.local"),
        root.join(".env.#{rails_env}"),
        root.join(".env")
      )
    end

    GEM_NAME = /[A-Za-z0-9.\-_]+/
    GEM_OPTIONS = /(.+?)\s*(?:,\s*(.+?))?/
    GEM_SEPARATOR = /\s*(?:,|\z)/
    GEM_REGULAR_EXPRESSION = /(#{GEM_NAME})(?:\(#{GEM_OPTIONS}\))?#{GEM_SEPARATOR}/

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

      args.scan(/(\w+):\s*(.+?)#{GEM_SEPARATOR}/).to_h { |key, value|
        [key.to_sym, value]
      }
    end

    def sanity_check(env)
      return if ENV['CI'] == 'true' || ENV['APP_SECRET_TOKEN'] || !env.empty?
      # .env is not necessary in bundle update/lock; this helps Renovate
      return if (File.basename($0) in 'bundle' | 'bundler') && (ARGV.first in 'lock' | 'update')

      puts warning
      require "shellwords"
      puts "command: #{[$0, *ARGV].shelljoin}"
      raise "Could not load huginn settings from .env file."
    end

    def warning
      <<~EOF
        Could not load huginn settings from .env file.

        Make sure to copy the .env.example to .env and change it to match your configuration.

        Capistrano 2 users: Make sure shared files are symlinked before bundle runs: before 'bundle:install', 'deploy:symlink_configs'
      EOF
    end
  end
end
