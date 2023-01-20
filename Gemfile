source 'https://rubygems.org'

ruby '>=2.7.0'

# Ensure github repositories are fetched using HTTPS
git_source(:github) do |repo_name|
  "https://github.com/#{repo_name}.git"
end

# Load vendored dotenv gem and .env file
require File.join(File.dirname(__FILE__), 'lib/gemfile_helper.rb')
GemfileHelper.load_dotenv do |dotenv_dir|
  path dotenv_dir do
    gem 'dotenv'
    gem 'dotenv-rails'
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
gem 'twilio-ruby', '~> 5.62.0'    # TwilioAgent
gem 'ruby-growl', '~> 4.1.0'      # GrowlAgent
gem 'net-ftp-list', '~> 3.2.8'    # FtpsiteAgent
gem 'forecast_io', '~> 2.0.0'     # WeatherAgent
gem 'rturk', '~> 2.12.1'          # HumanTaskAgent
gem 'erector', github: 'dsander/erector', branch: 'rails6'
gem 'hipchat', '~> 1.2.0'         # HipchatAgent
gem 'mini_racer'                  # JavaScriptAgent
gem 'xmpp4r',  '~> 0.5.6'         # JabberAgent
gem 'mqtt'                        # MQTTAgent
gem 'slack-notifier', '~> 1.0.0'  # SlackAgent
gem 'hypdf', '~> 1.0.10'          # PDFInfoAgent

# Weibo Agents
# FIXME needs to loosen omniauth dependency, add rest-client
gem 'weibo_2', github: 'albertsun/weibo_2', branch: 'master'

# GoogleCalendarPublishAgent and GoogleTranslateAgent
gem 'google-api-client', '~> 0.13'
gem 'google-cloud-translate', '~> 2.0', require: 'google/cloud/translate'

# Twitter Agents
gem 'twitter', github: 'sferik/twitter' # Must to be loaded before cantino-twitter-stream.
gem 'twitter-stream', github: 'cantino/twitter-stream', branch: 'huginn'
gem 'omniauth-twitter'

# Tumblr Agents
# until merge of https://github.com/tumblr/tumblr_client/pull/61
gem 'tumblr_client', github: 'albertsun/tumblr_client', branch: 'master', ref: 'e046fe6e39291c173add0a49081630c7b60a36c7'
gem 'omniauth-tumblr'

# Dropbox Agents
gem 'dropbox-api', github: 'dsander/dropbox-api', ref: '86cb7b5a1254dc5b054de7263835713c4c1018c7'
gem 'omniauth-dropbox-oauth2', github: 'huginn/omniauth-dropbox-oauth2'

# UserLocationAgent
gem 'haversine'

# EvernoteAgent
gem 'omniauth-evernote'
gem 'evernote_oauth'

# LocalFileAgent (watch functionality)
gem 'listen', '~> 3.0.5', require: false

# S3Agent
gem 'aws-sdk-s3', '~> 1'

# ImapFolderAgent
gem 'omniauth-google-oauth2', '>= 0.8.0'
gem 'gmail_xoauth' # support for Gmail using OAuth

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
gem 'devise', '~> 4.8'
gem 'em-http-request', '~> 1.1.2'
gem 'faraday', '~> 0.9'
gem 'faraday_middleware', '~> 0.12.2'
gem 'feedjira', '~> 3.1'
gem 'font-awesome-sass', '~> 4.7.0'
gem 'foreman', '~> 0.63.0'
gem 'geokit', '~> 1.13'
gem 'geokit-rails', '~> 2.3'
gem 'httparty', '~> 0.13'
gem 'httmultiparty', '~> 0.3.16'
gem 'jquery-rails', '~> 4.2.1'
gem 'huginn_agent'
gem 'json', '~> 2.3'
gem 'jsonpath', '~> 1.1'
gem 'kaminari', '~> 1.2'
gem 'kramdown'
gem 'liquid', '~> 5.1'
gem 'loofah', '~> 2.0'
gem 'mini_magick', ">= 4.9.4"
gem 'multi_xml'
gem "nokogiri", ">= 1.10.8"
gem 'omniauth'
gem 'rails', '~> 6.0.4'
gem 'sprockets', '~> 3.7.2'
gem 'rails-html-sanitizer', '~> 1.2'
gem 'rufus-scheduler', '~> 3.4', require: false
gem 'sass-rails', '>= 6.0'
gem 'select2-rails', '~> 3.5.4'
gem 'spectrum-rails'
gem 'execjs'
gem 'typhoeus', '~> 1.3.1'
gem 'uglifier', '~> 2.7.2'
gem 'bootsnap', require: false

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'guard'
  gem 'guard-livereload'
  gem 'guard-rspec'
  gem 'rack-livereload'
  gem 'letter_opener_web', '~> 1.4' # 2.0+ requires Ruby 2.7
  gem 'web-console', '>= 3.3.0'

  gem 'capistrano'
  gem 'capistrano-rails'
  gem 'capistrano-bundler'

  if_true(ENV['SPRING']) do
    gem 'spring-commands-rspec'
    gem 'spring'
    gem 'spring-watcher-listen'
  end

  group :test do
    gem 'coveralls', require: false
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
    gem 'rspec-collection_matchers'
    gem 'rspec-html-matchers'
    gem 'rails-controller-testing'
    gem 'shoulda-matchers'
    gem 'vcr'
    gem 'webmock', '~> 3.5.1'
  end
end

group :production do
  gem 'unicorn'
end

# Platform requirements.
require 'rbconfig'
gem 'ffi', '>= 1.9.4'		# required by typhoeus; 1.9.4 has fixes for *BSD.
gem 'tzinfo', '>= 1.2.0'	# required by rails; 1.2.0 has support for *BSD and Solaris.
# Windows does not have zoneinfo files, so bundle the tzinfo-data gem.
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]
# BSD systems require rb-kqueue for "listen" to avoid polling for changes.
gem 'rb-kqueue', '>= 0.2', require: /bsd|dragonfly/i === RbConfig::CONFIG['target_os']


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
  gem 'pg', '~> 1.1'
end

if_true(ENV['DATABASE_ADAPTER'].strip == 'mysql2') do
  gem 'mysql2', "~> 0.5"
end

GemfileHelper.parse_each_agent_gem(ENV['ADDITIONAL_GEMS']) do |args|
  gem *args
end
