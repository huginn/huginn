source 'https://rubygems.org'

ruby '>=2.5.0'

# Ensure github repositories are fetched using HTTPS
git_source(:github) do |repo_name|
  "https://github.com/#{repo_name}.git"
end

# Load vendored dotenv gem and .env file
require File.join(File.dirname(__FILE__), 'lib/gemfile_helper.rb')


# Introduces a scope for gem loading based on a condition
def if_true(condition, &block)
  if condition
    yield
  else
    # When not including the gems, we still want our Gemfile.lock
    # to include them, so we scope them to an unsupported platform.
    platform :ruby_18, &block
  end
end



# Bundler <1.5 does not recognize :x64_mingw as a valid platform name.
# Unfortunately, it can't self-update because it errors when encountering :x64_mingw.
unless Gem::Version.new(Bundler::VERSION) >= Gem::Version.new('1.5.0')
  STDERR.puts "Bundler >=1.5.0 is required.  Please upgrade bundler with 'gem install bundler'"
  exit 1
end

gem 'ace-rails-ap', '~> 2.0.1'
gem 'bootstrap-kaminari-views', '~> 0.0.3'
gem 'bundler', '>= 1.5.0'
gem 'coffee-rails', '~> 5'
gem 'daemons', '~> 1.1.9'
gem 'delayed_job', '~> 4.1.8'
gem 'delayed_job_active_record', github: 'dsander/delayed_job_active_record', branch: 'rails6-zeitwerk'
gem 'devise', '~> 4.8.1'
gem 'em-http-request', '~> 1.1.2'
gem 'faraday', '~> 0.9'
gem 'faraday_middleware', '~> 0.12.2'
gem 'font-awesome-sass', '~> 4.7.0'
gem 'foreman', '~> 0.63.0'
gem 'geokit', '~> 1.8.4'
gem 'geokit-rails', '~> 2.2.0'
gem 'httparty', '~> 0.13'
gem 'httmultiparty', '~> 0.3.16'
gem 'jquery-rails', '~> 4.2.1'
gem 'huginn_agent'
gem 'json', '~> 2.3'
gem 'jsonpath', '~> 1.0.1'
gem 'kaminari', '~> 1.1.1'
gem 'kramdown'
gem 'liquid', '~> 4.0.3'
gem 'loofah', '~> 2.0'
gem 'mini_magick', ">= 4.9.4"
gem 'multi_xml'
gem "nokogiri", ">= 1.10.8"
gem 'omniauth', '~> 2.1'
gem 'rails', '~> 6.0.4'
gem 'sprockets', '~> 3.7.2'
gem 'rails-html-sanitizer', '~> 1.2'
gem 'rufus-scheduler', '~> 3.4.2', require: false
gem 'sass-rails', '>= 6.0'
gem 'select2-rails', '~> 3.5.4'
gem 'spectrum-rails'
gem 'typhoeus', '~> 1.3.1'
gem 'uglifier', '~> 2.7.2'
gem 'bootsnap', require: false
gem 'rickshaw_rails', '~> 1.4'
group :development do
  gem 'better_errors', '~> 1.1'
  gem 'binding_of_caller', '~> 0.8.0'
  gem 'guard', '~> 2.14.1'
  gem 'guard-livereload', '~> 2.5.1'
  gem 'guard-rspec', '~> 4.7.3'
  gem 'rack-livereload', '~> 0.3.16'
  gem 'letter_opener_web', '~> 1.3.1'
  gem 'web-console', '>= 3.3.0'

  gem 'capistrano', '~> 3.11.0'
  gem 'capistrano-rails', '~> 1.1'
  gem 'capistrano-bundler', '~> 1.1.4'

  if_true(ENV['SPRING']) do
    gem 'spring-commands-rspec', '~> 1.0.4'
    gem 'spring', '~> 2.0.2'
    gem 'spring-watcher-listen', '~> 2.0.1'
  end

  group :test do
    gem 'coveralls', '~> 0.8.23', require: false
    gem 'capybara', '~> 2.18'
    gem 'capybara-screenshot'
    gem 'capybara-select-2', github: 'Hirurg103/capybara_select2', ref: 'fbf22fb74dec10fa0edcd26da7c5184ba8fa2c76', require: false
    gem 'poltergeist'
    gem 'pry-rails'
    gem 'pry-byebug'
    gem 'rr', require: false
    gem 'rspec', '~> 3.8'
    gem 'rspec-mocks'
    gem 'rspec-rails'
    gem 'rspec-collection_matchers', '~> 1.1.0'
    gem 'rspec-html-matchers', '~> 0.8'
    gem 'rails-controller-testing'
    gem 'shoulda-matchers'
    gem 'vcr'
    gem 'webmock', '~> 3.5.1'
  end
end

group :production do
  gem 'unicorn', '~> 5.1.0'
end

# Platform requirements.
require 'rbconfig'
gem 'ffi', '>= 1.9.4'		# required by typhoeus; 1.9.4 has fixes for *BSD.
gem 'tzinfo', '>= 1.2.0'	# required by rails; 1.2.0 has support for *BSD and Solaris.
# Windows does not have zoneinfo files, so bundle the tzinfo-data gem.
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]


ENV['DATABASE_ADAPTER'] ||= 'postgresql'
gem 'pg', '~> 1.1.3'



GemfileHelper.parse_each_agent_gem(ENV['ADDITIONAL_GEMS']) do |args|
  gem *args
end