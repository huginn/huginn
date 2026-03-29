# -*- encoding: utf-8 -*-
# stub: dotenv 3.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "dotenv".freeze
  s.version = "3.2.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/bkeepers/dotenv/releases", "funding_uri" => "https://github.com/sponsors/bkeepers" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Brandon Keepers".freeze]
  s.date = "1980-01-02"
  s.description = "Loads environment variables from `.env`.".freeze
  s.email = ["brandon@opensoul.org".freeze]
  s.executables = ["dotenv".freeze]
  s.files = ["LICENSE".freeze, "README.md".freeze, "bin/dotenv".freeze, "lib/dotenv.rb".freeze, "lib/dotenv/autorestore.rb".freeze, "lib/dotenv/cli.rb".freeze, "lib/dotenv/diff.rb".freeze, "lib/dotenv/environment.rb".freeze, "lib/dotenv/load.rb".freeze, "lib/dotenv/log_subscriber.rb".freeze, "lib/dotenv/missing_keys.rb".freeze, "lib/dotenv/parser.rb".freeze, "lib/dotenv/rails-now.rb".freeze, "lib/dotenv/rails.rb".freeze, "lib/dotenv/replay_logger.rb".freeze, "lib/dotenv/substitutions/command.rb".freeze, "lib/dotenv/substitutions/variable.rb".freeze, "lib/dotenv/tasks.rb".freeze, "lib/dotenv/template.rb".freeze, "lib/dotenv/version.rb".freeze]
  s.homepage = "https://github.com/bkeepers/dotenv".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.0".freeze)
  s.rubygems_version = "3.6.9".freeze
  s.summary = "Loads environment variables from `.env`.".freeze

  s.specification_version = 4

  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<standard>.freeze, [">= 0".freeze])
end

