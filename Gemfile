source 'https://rubygems.org'

# Ruby 2.0 is the minimum requirement
ruby ['2.0.0', RUBY_VERSION].max

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
gem 'weibo_2', github: 'cantino/weibo_2', branch: 'master'

# GoogleCalendarPublishAgent
gem "google-api-client", require: 'google/api_client'

# Twitter Agents
gem 'twitter', '~> 5.14.0' # Must to be loaded before cantino-twitter-stream.
gem 'twitter-stream', github: 'cantino/twitter-stream', branch: 'huginn'
gem 'omniauth-twitter'

# Tumblr Agents
gem 'tumblr_client', github: 'tumblr/tumblr_client', branch: 'master'  # '>= 0.8.5'
gem 'omniauth-tumblr'

# Dropbox Agents
gem 'dropbox-api'
gem 'omniauth-dropbox'

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
gem 'omniauth-wunderlist', github: 'wunderlist/omniauth-wunderlist', ref: 'd0910d0396107b9302aa1bc50e74bb140990ccb8'

# Bundler <1.5 does not recognize :x64_mingw as a valid platform name.
# Unfortunately, it can't self-update because it errors when encountering :x64_mingw.
unless Gem::Version.new(Bundler::VERSION) >= Gem::Version.new('1.5.0')
  STDERR.puts "Bundler >=1.5.0 is required.  Please upgrade bundler with 'gem install bundler'"
  exit 1
end

gem 'protected_attributes', '~>1.0.8' # This must be loaded before some other gems, like delayed_job.
gem 'ace-rails-ap', '~> 2.0.1'
gem 'bootstrap-kaminari-views', '~> 0.0.3'
gem 'bundler', '>= 1.5.0'
gem 'coffee-rails', '~> 4.1.1'
gem 'daemons', '~> 1.1.9'
gem 'delayed_job', '~> 4.1.0'
gem 'delayed_job_active_record', github: 'collectiveidea/delayed_job_active_record', branch: 'master'
gem 'devise', '~> 3.5.4'
gem 'em-http-request', '~> 1.1.2'
gem 'faraday', '~> 0.9.0'
gem 'faraday_middleware', github: 'lostisland/faraday_middleware', branch: 'master'  # '>= 0.10.1'
gem 'feed-normalizer'
gem 'font-awesome-sass', '~> 4.3.2'
gem 'foreman', '~> 0.63.0'
# geokit-rails doesn't work with geokit 1.8.X but it specifies ~> 1.5
# in its own Gemfile.
gem 'geokit', '~> 1.8.4'
gem 'geokit-rails', '~> 2.0.1'
gem 'httparty', '~> 0.13'
gem 'httmultiparty', '~> 0.3.16'
gem 'jquery-rails', '~> 3.1.3'
gem 'json', '~> 1.8.1'
gem 'jsonpath', '~> 0.5.6'
gem 'kaminari', '~> 0.16.1'
gem 'kramdown', '~> 1.3.3'
gem 'liquid', '~> 3.0.3'
gem 'mini_magick'
gem 'multi_xml'
gem 'nokogiri', '1.6.7.2'
gem 'omniauth'
gem 'rails', '4.2.5.2'
gem 'rufus-scheduler', '~> 3.0.8', require: false
gem 'sass-rails',   '~> 5.0.3'
gem 'select2-rails', '~> 3.5.4'
gem 'spectrum-rails'
gem 'string-scrub'	# for ruby <2.1
gem 'therubyracer', '~> 0.12.2'
gem 'typhoeus', '~> 0.6.3'
gem 'uglifier', '~> 2.7.2'

group :development do
  gem 'better_errors', '~> 1.1'
  gem 'binding_of_caller'
  gem 'quiet_assets'
  gem 'guard', '~> 2.13.0'
  gem 'guard-livereload', '~> 2.5.1'
  gem 'guard-rspec', '~> 4.6.4'
  gem 'rack-livereload', '~> 0.3.16'
  gem 'letter_opener_web'

  gem 'capistrano', '~> 3.4.0'
  gem 'capistrano-rails', '~> 1.1'
  gem 'capistrano-bundler', '~> 1.1.4'

  if_true(ENV['SPRING']) do
    gem 'spring-commands-rspec', '~> 1.0.4'
    gem 'spring', '~> 1.6.3'
  end

  group :test do
    gem 'coveralls', require: false
    gem 'capybara-select2', require: false
    gem 'delorean'
    gem 'poltergeist'
    gem 'pry-rails'
    gem 'rr'
    gem 'rspec', '~> 3.2'
    gem 'rspec-collection_matchers', '~> 1.1.0'
    gem 'rspec-rails', '~> 3.1'
    gem 'rspec-html-matchers', '~> 0.7'
    gem 'shoulda-matchers'
    gem 'vcr'
    gem 'webmock', '~> 1.17.4', require: false
  end
end

group :production do
  gem 'rack', '> 1.5.0'
  gem 'unicorn', '~> 4.9.0'
end

# Platform requirements.
gem 'ffi', '>= 1.9.4'		# required by typhoeus; 1.9.4 has fixes for *BSD.
gem 'tzinfo', '>= 1.2.0'	# required by rails; 1.2.0 has support for *BSD and Solaris.
# Windows does not have zoneinfo files, so bundle the tzinfo-data gem.
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]


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

if_true(on_heroku) do
  gem 'rails_12factor', group: :production
end

if_true(ENV['DATABASE_ADAPTER'].strip == 'postgresql') do
  gem 'pg', '~> 0.18.3'
end

if_true(ENV['DATABASE_ADAPTER'].strip == 'mysql2') do
  gem 'mysql2', '~> 0.3.20'
end
