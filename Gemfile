source 'https://rubygems.org'

ruby '>=3.4.0'

# Ensure github repositories are fetched using HTTPS
git_source(:github) do |repo_name|
  "https://github.com/#{repo_name}.git"
end

# Load vendored dotenv gem and .env file
require File.join(File.dirname(__FILE__), 'lib/gemfile_helper.rb')
GemfileHelper.load_dotenv do |dotenv_dir|
  path dotenv_dir do
    gem 'dotenv'
  end
end

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

# Optional libraries.  To conserve RAM, comment out any that you don't need,
# then run `bundle` and commit the updated Gemfile and Gemfile.lock.
gem 'erector', github: 'dsander/erector', branch: 'rails6'
gem 'hipchat' # HipchatAgent
gem 'pdf-reader' # PDFInfoAgent
gem 'mini_racer', github: 'knu/mini_racer', branch: 'fix/darwin_build' # JavaScriptAgent
gem 'mqtt' # MQTTAgent
gem 'net-ftp'
gem 'net-ftp-list' # FtpsiteAgent
gem 'pirate_weather_forecast_ruby' # WeatherAgent
gem 'rturk'                       # HumanTaskAgent
gem 'slack-notifier'              # SlackAgent
gem 'twilio-ruby'                 # TwilioAgent
gem 'xmpp4r'                      # JabberAgent

# GoogleCalendarPublishAgent
gem 'google-apis-calendar_v3'
gem 'google-cloud-translate-v2'

# Twitter Agents
gem 'omniauth-twitter'
gem 'twitter', '~> 8.3'

# Tumblr Agents
gem 'omniauth-oauth', '~> 1.2', '>= 1.2.1'
gem 'simple_oauth'

# Dropbox Agents
gem 'omniauth-dropbox2', '>= 2.0.5'

# UserLocationAgent
gem 'haversine'

# EvernoteAgent
gem 'evernote_oauth'
gem 'omniauth-evernote'

# LocalFileAgent (watch functionality)
gem 'listen', require: false

# S3Agent
gem 'aws-sdk-s3', '~> 1', '>= 1.218.0'

# ImapFolderAgent
gem 'gmail_xoauth' # support for Gmail using OAuth
gem 'omniauth-google-oauth2', '~> 1.2.2'

# Common gems
gem 'ace-rails-ap'
gem 'bootsnap', require: false
gem 'bootstrap-kaminari-views'
gem 'daemons'
gem 'delayed_job'
gem 'delayed_job_active_record'
gem 'devise', '~> 5.0', '>= 5.0.3'
gem 'em-http-request'
gem 'execjs'
gem 'faraday'
# gem 'faraday-em_http'
gem 'faraday-follow_redirects'
gem 'faraday-gzip'
# gem 'faraday-httpclient'
gem 'faraday-multipart'
gem 'faraday-typhoeus'
gem 'feedjira', '~> 4.0', '>= 4.0.1'
gem 'foreman'
gem 'geokit'
gem 'geokit-rails'
gem 'httmultiparty'
gem 'httparty', '>= 0.24.2'
gem 'huginn_agent'
gem 'jquery-rails'
gem 'json'
gem 'jsonpath'
gem 'kaminari', '~> 1.2', '>= 1.2.2'
gem 'kramdown'
gem 'liquid', '~> 5.12'
gem 'logger'
gem 'loofah', '~> 2.25', '>= 2.25.1'
gem 'mail', '>= 2.9.0'
gem 'mini_magick', '>= 5.3.1'
gem 'multi_xml'
gem 'nokogiri', '>= 1.19.2'
gem 'omniauth'
gem 'ostruct'
gem 'puma'
gem 'rails', '~> 8.1.3'
gem 'rails-html-sanitizer', '~> 1.7'
gem 'rufus-scheduler', '~> 3.9', '>= 3.9.2', require: false
gem 'sassc-rails'
gem 'select2-rails'
gem 'spectrum-rails'
gem 'sprockets'
gem 'terser'
gem 'typhoeus'
gem 'uglifier'

group :development, :test do
  gem 'debug'
  gem 'rspec-rails'
end

group :development do
  gem 'letter_opener_web'

  gem 'capistrano'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'

  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rspec', require: false

  if_true(ENV['SPRING']) do
    gem 'spring'
    gem 'spring-commands-rspec'
    gem 'spring-watcher-listen'
  end

  group :test do
    gem 'capybara'
    gem 'capybara-select-2', require: false
    gem 'rails-controller-testing'
    gem 'rr', require: false
    gem 'rspec'
    gem 'rspec-collection_matchers'
    gem 'rspec-html-matchers'
    gem 'rspec-mocks'
    gem 'rspec-retry'
    gem 'selenium-webdriver'
    gem 'simplecov', require: false
    gem 'simplecov-lcov', require: false
    gem 'vcr'
    gem 'webmock'
  end
end

# Platform requirements.
require 'rbconfig'
gem 'ffi', '>= 1.17.4'	# required by typhoeus; 1.9.4 has fixes for *BSD.
gem 'tzinfo', '>= 2.0.6'	# required by rails; 1.2.0 has support for *BSD and Solaris.
# Windows does not have zoneinfo files, so bundle the tzinfo-data gem.
gem 'tzinfo-data', platforms: %i[windows]
# BSD systems require rb-kqueue for "listen" to avoid polling for changes.
gem 'rb-kqueue', '>= 0.2.8', require: /bsd|dragonfly/i === RbConfig::CONFIG['target_os']

on_heroku = ENV['ON_HEROKU'] ||
            ENV['HEROKU_POSTGRESQL_ROSE_URL'] ||
            ENV['HEROKU_POSTGRESQL_GOLD_URL'] ||
            File.read(File.join(File.dirname(__FILE__), 'Procfile')) =~ /intended for Heroku/

ENV['DATABASE_ADAPTER'] ||=
  if on_heroku
    'postgresql'
  else
    'mysql2'
  end

if_true(ENV['DATABASE_ADAPTER'].strip == 'postgresql') do
  gem 'pg', '~> 1.6', '>= 1.6.3'
end

if_true(ENV['DATABASE_ADAPTER'].strip == 'mysql2') do
  gem 'mysql2', '~> 0.5', '>= 0.5.7'
end

GemfileHelper.parse_each_agent_gem(ENV['ADDITIONAL_GEMS']) do |args|
  gem(*args)
end
