source 'https://rubygems.org'

# Ruby 2.2.2 is the minimum requirement
ruby ['2.2.2', RUBY_VERSION].max

# Ensure github repositories are fetched using HTTPS
git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end if Gem::Version.new(Bundler::VERSION) < Gem::Version.new('2')

# Load vendored dotenv gem and .env file
require File.join(File.dirname(__FILE__), 'lib/gemfile_helper.rb')
GemfileHelper.load_dotenv do |dotenv_dir|
  path dotenv_dir do
    gem 'dotenv'
    gem 'dotenv-rails'
  end
end

# Introduces a scope for gem loading based on a condition
def if_true(condition)
  if condition
    yield
  else
    # When not including the gems, we still want our Gemfile.lock
    # to include them, so we scope them to an unsupported platform.
    platform :ruby_18, &proc
  end
end

# Optional libraries.  To conserve RAM, comment out any that you don't need,
# then run `bundle` and commit the updated Gemfile and Gemfile.lock.
gem 'twilio-ruby', '~> 3.11.5'    # TwilioAgent
gem 'ruby-growl', '~> 4.1.0'      # GrowlAgent
gem 'net-ftp-list', '~> 3.2.8'    # FtpsiteAgent
gem 'wunderground', '~> 1.2.0'    # WeatherAgent
gem 'forecast_io', '~> 2.0.0'     # WeatherAgent
gem 'rturk', '~> 2.12.1'          # HumanTaskAgent
gem 'hipchat', '~> 1.2.0'         # HipchatAgent
gem 'xmpp4r',  '~> 0.5.6'         # JabberAgent
gem 'mqtt'                        # MQTTAgent
gem 'slack-notifier', '~> 1.0.0'  # SlackAgent
gem 'hypdf', '~> 1.0.10'          # PDFInfoAgent

# Weibo Agents
# FIXME needs to loosen omniauth dependency, add rest-client
gem 'weibo_2', github: 'albertsun/weibo_2', branch: 'master'

# GoogleCalendarPublishAgent and GoogleTranslateAgent
gem 'google-api-client', '~> 0.13'
gem 'google-cloud-translate', '~> 1.0.0', require: 'google/cloud/translate'

# Twitter Agents
gem 'twitter', github: 'sferik/twitter' # Must to be loaded before cantino-twitter-stream.
gem 'twitter-stream', github: 'cantino/twitter-stream', branch: 'huginn'
gem 'omniauth-twitter', '~> 1.3.0'

# Tumblr Agents
# until merge of https://github.com/tumblr/tumblr_client/pull/61
gem 'tumblr_client', github: 'albertsun/tumblr_client', branch: 'master', ref: 'e046fe6e39291c173add0a49081630c7b60a36c7' 
gem 'omniauth-tumblr', '~> 1.2'

# Dropbox Agents
gem 'dropbox-api', github: 'dsander/dropbox-api', ref: '86cb7b5a1254dc5b054de7263835713c4c1018c7'
gem 'omniauth-dropbox-oauth2', github: 'bamorim/omniauth-dropbox-oauth2', ref: '35046706fb781ed3b57dfb9c3cd44ed0f3d3f8ea'

# UserLocationAgent
gem 'haversine'

# EvernoteAgent
gem 'omniauth-evernote'
gem 'evernote_oauth'

# LocalFileAgent (watch functionality)
gem 'listen', '~> 3.0.5', require: false

# S3Agent
gem 'aws-sdk-core', '~> 2.2.15'

# Optional Services.
gem 'omniauth-37signals'          # BasecampAgent
gem 'omniauth-wunderlist'

# Bundler <1.5 does not recognize :x64_mingw as a valid platform name.
# Unfortunately, it can't self-update because it errors when encountering :x64_mingw.
unless Gem::Version.new(Bundler::VERSION) >= Gem::Version.new('1.5.0')
  STDERR.puts "Bundler >=1.5.0 is required.  Please upgrade bundler with 'gem install bundler'"
  exit 1
end

gem 'ace-rails-ap', '~> 2.0.1'
gem 'bootstrap-kaminari-views', '~> 0.0.3'
gem 'bundler', '>= 1.5.0'
gem 'coffee-rails', '~> 4.2'
gem 'daemons', '~> 1.1.9'
gem 'delayed_job', github: 'dsander/delayed_job', branch: 'rails51'
gem 'delayed_job_active_record', github: 'dsander/delayed_job_active_record', branch: 'rails5'
gem 'devise', '~> 4.3.0'
gem 'em-http-request', '~> 1.1.2'
gem 'faraday', '~> 0.9'
gem 'faraday_middleware', github: 'lostisland/faraday_middleware', branch: 'master'  # '>= 0.10.1'
gem 'feedjira', '~> 2.1'
gem 'font-awesome-sass', '~> 4.7.0'
gem 'foreman', '~> 0.63.0'
gem 'geokit', '~> 1.8.4'
gem 'geokit-rails', '~> 2.2.0'
gem 'httparty', '~> 0.13'
gem 'httmultiparty', '~> 0.3.16'
gem 'jquery-rails', '~> 4.2.1'
gem 'huginn_agent', '~> 0.4.0'
gem 'json', '~> 1.8.1'
gem 'jsonpath', '~> 0.8.3'
gem 'kaminari', github: "amatsuda/kaminari", branch: '0-17-stable', ref: 'abbf93d557208ee1d0b612c612cd079f86ed54f4'
gem 'kramdown', '~> 1.3.3'
gem 'liquid', '~> 4.0'
gem 'loofah', '~> 2.0'
gem 'mini_magick'
gem 'multi_xml'
gem 'nokogiri'
gem 'omniauth', '~> 1.6.1'
gem 'rails', '~> 5.1.1'
gem 'rufus-scheduler', '~> 3.3.2', require: false
gem 'sass-rails', '~> 5.0'
gem 'select2-rails', '~> 3.5.4'
gem 'spectrum-rails'
gem 'therubyracer', '~> 0.12.3'
gem 'typhoeus', '~> 0.6.3'
gem 'uglifier', '~> 2.7.2'

group :development do
  gem 'better_errors', '~> 1.1'
  gem 'binding_of_caller'
  gem 'guard', '~> 2.14.1'
  gem 'guard-livereload', '~> 2.5.1'
  gem 'guard-rspec', '~> 4.7.3'
  gem 'rack-livereload', '~> 0.3.16'
  gem 'letter_opener_web', '~> 1.3.1'
  gem 'web-console', '>= 3.3.0'

  gem 'capistrano', '~> 3.4.0'
  gem 'capistrano-rails', '~> 1.1'
  gem 'capistrano-bundler', '~> 1.1.4'

  if_true(ENV['SPRING']) do
    gem 'spring-commands-rspec', '~> 1.0.4'
    gem 'spring', '~> 2.0.2'
    gem 'spring-watcher-listen', '~> 2.0.1'
  end

  group :test do
    gem 'coveralls', '~> 0.8.12', require: false
    gem 'capybara', '~> 2.13.0'
    gem 'capybara-screenshot'
    gem 'capybara-select2', require: false
    gem 'delorean'
    gem 'poltergeist'
    gem 'pry-rails'
    gem 'pry-byebug'
    gem 'rr'
    gem 'rspec', '~> 3.5'
    gem 'rspec-collection_matchers', '~> 1.1.0'
    gem 'rspec-rails', '~> 3.5.2'
    gem 'rspec-html-matchers', '~> 0.8'
    gem 'rails-controller-testing'
    gem 'shoulda-matchers'
    gem 'vcr'
    gem 'webmock', '~> 2.3'
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
  gem 'pg', '~> 0.18.3'
end

if_true(ENV['DATABASE_ADAPTER'].strip == 'mysql2') do
  gem 'mysql2', ">= 0.3.18", "< 0.5"
end

GemfileHelper.parse_each_agent_gem(ENV['ADDITIONAL_GEMS']) do |args|
  gem *args
end
