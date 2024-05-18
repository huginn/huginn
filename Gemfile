source 'https://rubygems.org'

ruby '>=3.2.4'

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
gem 'pirate_weather_forecast_ruby'  # WeatherAgent
gem 'hipchat', '~> 1.6.0'         # HipchatAgent
gem 'hypdf', bitbucket: 'knu/hypdf_gem', branch: 'uploadio_namespace' # PDFInfoAgent
gem 'mini_racer'                  # JavaScriptAgent
gem 'mqtt'                        # MQTTAgent
gem 'net-ftp'
gem 'net-ftp-list'                # FtpsiteAgent
gem 'rturk', '~> 2.12.1'          # HumanTaskAgent
gem 'slack-notifier', '~> 1.5.1'  # SlackAgent
gem 'twilio-ruby', '~> 5.77.0'    # TwilioAgent
gem 'xmpp4r', '~> 0.5.6'          # JabberAgent

# Weibo Agents
# FIXME needs to loosen omniauth dependency, add rest-client
gem 'weibo_2', github: 'albertsun/weibo_2', branch: 'master'

# GoogleCalendarPublishAgent and GoogleTranslateAgent
gem 'google-api-client', '~> 0.53'
gem 'google-cloud-translate', '~> 2.3', require: 'google/cloud/translate'

# Twitter Agents
gem 'omniauth-twitter'
gem 'twitter', github: 'sferik/twitter' # Must to be loaded before cantino-twitter-stream.
gem 'twitter-stream', github: 'cantino/twitter-stream', branch: 'huginn'

# Tumblr Agents
# until merge of https://github.com/tumblr/tumblr_client/pull/61
gem 'omniauth-tumblr'
gem 'tumblr_client', '~> 0.8.6', github: 'tumblr/tumblr_client'

# Dropbox Agents
gem 'dropbox-api', github: 'dsander/dropbox-api', ref: '86cb7b5a1254dc5b054de7263835713c4c1018c7'
gem 'omniauth-dropbox-oauth2', github: 'huginn/omniauth-dropbox-oauth2'

# UserLocationAgent
gem 'haversine'

# EvernoteAgent
gem 'evernote_oauth'
gem 'omniauth-evernote'

# LocalFileAgent (watch functionality)
gem 'listen', '~> 3.9.0', require: false

# S3Agent
gem 'aws-sdk-s3', '~> 1', '>= 1.148.0'

# ImapFolderAgent
gem 'gmail_xoauth' # support for Gmail using OAuth
gem 'omniauth-google-oauth2', '>= 0.8.2'

# Bundler <1.5 does not recognize :x64_mingw as a valid platform name.
# Unfortunately, it can't self-update because it errors when encountering :x64_mingw.
unless Gem::Version.new(Bundler::VERSION) >= Gem::Version.new('1.5.0')
  warn "Bundler >=1.5.0 is required.  Please upgrade bundler with 'gem install bundler'"
  exit 1
end

gem 'ace-rails-ap'
gem 'bootsnap', require: false
gem 'bootstrap-kaminari-views', '~> 0.0.5'
gem 'bundler', '>= 2.5.10'
gem 'coffee-rails', '~> 5'
gem 'daemons', '~> 1.4.1'
gem 'delayed_job'
gem 'delayed_job_active_record'
gem 'devise', '~> 4.9', '>= 4.9.4'
gem 'em-http-request', '~> 1.1.7'
gem 'execjs'
gem 'faraday', '~> 1.10', '>= 1.10.3'
gem 'faraday_middleware'
gem 'feedjira', '~> 3.2', '>= 3.2.3'
gem 'font-awesome-sass', '~> 4.7.0'
gem 'foreman', '~> 0.88.1', github: 'ddollar/foreman'
gem 'geokit', '~> 1.14'
gem 'geokit-rails', '~> 2.5'
gem 'httmultiparty', '~> 0.3.16'
gem 'httparty', '~> 0.21'
gem 'huginn_agent'
gem 'jquery-rails', '~> 4.6'
gem 'json', '~> 2.7', '>= 2.7.2'
gem 'jsonpath', '~> 1.1', '>= 1.1.5'
gem 'kaminari', '~> 1.2', '>= 1.2.2'
gem 'kramdown'
gem 'liquid', '~> 5.5'
gem 'loofah', '~> 2.22'
gem 'mail', '>= 2.8.1'
gem 'mini_magick', ">= 4.12.0"
gem 'multi_xml'
gem "nokogiri", ">= 1.16.5"
gem 'omniauth'
gem 'rails', '~> 6.1.7', '>= 6.1.7.7'
gem 'rails-html-sanitizer', '~> 1.6'
gem 'rufus-scheduler', '~> 3.9', '>= 3.9.1', require: false
gem 'sass-rails', '>= 6.0'
gem 'select2-rails'
gem 'spectrum-rails'
gem 'sprockets'
gem 'terser'
gem 'typhoeus', '~> 1.4.1'
gem 'uglifier', '~> 4.2.0'

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'guard'
  gem 'guard-livereload'
  gem 'guard-rspec'
  gem 'letter_opener_web', '~> 2.0'
  gem 'rack-livereload'
  gem 'web-console', '>= 4.2.1'

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
    gem 'capybara-select-2', github: 'Hirurg103/capybara_select2', require: false
    gem 'puma'
    gem 'rails-controller-testing'
    gem 'rr', require: false
    gem 'rspec'
    gem 'rspec-collection_matchers'
    gem 'rspec-html-matchers'
    gem 'rspec-mocks'
    gem 'rspec-rails'
    gem 'selenium-webdriver'
    gem 'shoulda-matchers'
    gem 'simplecov', require: false
    gem 'simplecov-lcov', '~> 0.8.0', require: false
    gem 'vcr'
    gem 'webmock'
  end
end

group :production do
  gem 'unicorn'
  gem 'unicorn-rails'
end

# Platform requirements.
require 'rbconfig'
gem 'ffi', '>= 1.16.3'	# required by typhoeus; 1.9.4 has fixes for *BSD.
gem 'tzinfo', '>= 2.0.6'	# required by rails; 1.2.0 has support for *BSD and Solaris.
# Windows does not have zoneinfo files, so bundle the tzinfo-data gem.
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]
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
  gem 'pg', '~> 1.5', '>= 1.5.6'
end

if_true(ENV['DATABASE_ADAPTER'].strip == 'mysql2') do
  gem 'mysql2', "~> 0.5", ">= 0.5.6"
end

GemfileHelper.parse_each_agent_gem(ENV['ADDITIONAL_GEMS']) do |args|
  gem *args
end
