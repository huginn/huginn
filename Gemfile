#
# The default setup of Huginn is pretty large and may not fit on
# servers with lower RAM.  To conserve RAM, you can turn off some of
# the Agent types you don't need and avoid loading their dependencies.
# To do this, list the gem groups you want to opt out of after
# `--without` when you run `bundle` like this:
#
#     bundle --without basecamp human_task jabber mqtt weibo
#
# For production deployment, you can also omit gems used only for
# development like this:
#
#     bundle install --deployment --without development test basecamp human_task jabber mqtt weibo
#
# Here's the list of gem groups enabled by default but optional:
#
# Group         | Use(s)
# ------------- | --------------------------
# development   | development
# test          | running tests
# basecamp      | BasecampAgent
# dropbox       | Dropbox Agents
# ftpsite       | FtpsiteAgent
# github        | GitHub Agents
# google_api    | GoogleCalendarPublishAgent
# growl         | GrowlAgent
# hipchat       | HipchatAgent
# human_task    | HumanTaskAgent
# jabber        | JabberAgent
# mqtt          | MqttAgent
# pdf_info      | PdfInfoAgent
# slack         | SlackAgent
# tumblr        | Tumblr Agents
# twilio        | TwilioAgent
# twitter       | Twitter Agents
# user_location | UserLocationAgent
# weather       | WeatherAgent
# weibo         | Weibo Agents
# wunderlist    | WunderListAgent
#

source 'https://rubygems.org'

# Bundler <1.5 does not recognize :x64_mingw as a valid platform name.
# Unfortunately, it can't self-update because it errors when encountering :x64_mingw.
unless Gem::Version.new(Bundler::VERSION) >= Gem::Version.new('1.5.0')
  STDERR.puts "Bundler >=1.5.0 is required.  Please upgrade bundler with 'gem install bundler'"
  exit 1
end

def optional
  group :optional, &proc
end

# Let optional gems optional
Bundler.settings.without |= [:optional]

# Essential gems.

gem 'protected_attributes', '~>1.0.8' # This must be loaded before some other gems, like delayed_job.

gem 'ace-rails-ap', '~> 2.0.1'
gem 'bootstrap-kaminari-views', '~> 0.0.3'
gem 'bundler', '>= 1.5.0'
gem 'coffee-rails', '~> 4.1.0'
gem 'daemons', '~> 1.1.9'
gem 'delayed_job', '~> 4.0.0'
gem 'delayed_job_active_record', '~> 4.0.0'
gem 'devise', '~> 3.4.0'
gem 'dotenv-rails', '~> 2.0.1'
gem 'em-http-request', '~> 1.1.2'
gem 'faraday', '~> 0.9.0'
gem 'faraday_middleware'
gem 'feed-normalizer'
gem 'font-awesome-sass', '~> 4.3.2'
gem 'foreman', '~> 0.63.0'
# geokit-rails doesn't work with geokit 1.8.X but it specifies ~> 1.5
# in its own Gemfile.
gem 'geokit', '~> 1.8.4'
gem 'geokit-rails', '~> 2.0.1'
gem 'httparty', '~> 0.13'
gem 'jquery-rails', '~> 3.1.3'
gem 'json', '~> 1.8.1'
gem 'jsonpath', '~> 0.5.6'
gem 'kaminari', '~> 0.16.1'
gem 'kramdown', '~> 1.3.3'
gem 'liquid', '~> 3.0.3'
gem 'mini_magick'
gem 'mysql2', '~> 0.3.16'
gem 'multi_xml'
gem 'nokogiri', '~> 1.6.4'
gem 'omniauth'
gem 'rails' , '4.2.2'
gem 'rufus-scheduler', '~> 3.0.8', require: false
gem 'sass-rails',   '~> 5.0.3'
gem 'select2-rails', '~> 3.5.4'
gem 'spectrum-rails'
gem 'string-scrub'	# for ruby <2.1
gem 'therubyracer', '~> 0.12.2'
gem 'typhoeus', '~> 0.6.3'
gem 'uglifier', '>= 1.3.0'

group :production do
  gem 'rack', '> 1.5.0'
end

# Platform requirements.
gem 'ffi', '>= 1.9.4'		# required by typhoeus; 1.9.4 has fixes for *BSD.
gem 'tzinfo', '>= 1.2.0'	# required by rails; 1.2.0 has support for *BSD and Solaris.
# Windows does not have zoneinfo files, so bundle the tzinfo-data gem.
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]

# Introduces a scope for Heroku specific gems.
def on_heroku
  if ENV['ON_HEROKU'] ||
     ENV['HEROKU_POSTGRESQL_ROSE_URL'] ||
     ENV['HEROKU_POSTGRESQL_GOLD_URL'] ||
     File.read(File.join(File.dirname(__FILE__), 'Procfile')) =~ /intended for Heroku/
    yield
  else
    # When not on Heroku, we still want our Gemfile.lock to include
    # Heroku specific gems, so we scope them to an unsupported
    # platform.
    platform :ruby_18, &proc
  end
end

on_heroku do
  gem 'pg'
  gem 'unicorn'
  gem 'rails_12factor', group: :production
end

# Development dependencies.

group :development do
  gem 'better_errors', '~> 1.1'
  gem 'binding_of_caller'
  gem 'quiet_assets'
  gem 'guard'
  gem 'guard-livereload'
  gem 'guard-rspec'

  group :test do
    gem 'coveralls', require: false
    gem 'delorean'
    gem 'pry-rails'
    gem 'rr'
    gem 'rspec', '~> 3.2'
    gem 'rspec-collection_matchers', '~> 1.1.0'
    gem 'rspec-rails', '~> 3.1'
    gem 'rspec-html-matchers', '~> 0.7'
    gem 'shoulda-matchers'
    gem 'spring', '~> 1.3.0'
    gem 'spring-commands-rspec'
    gem 'vcr'
    gem 'webmock', '~> 1.17.4', require: false
  end
end

# Optional libraries.
optional do
  gem 'twilio-ruby', '~> 3.11.5',   group: :twilio     # TwilioAgent
  gem 'ruby-growl', '~> 4.1.0',     group: :growl      # GrowlAgent
  gem 'net-ftp-list', '~> 3.2.8',   group: :ftpsite    # FtpsiteAgent
  gem 'wunderground', '~> 1.2.0',   group: :weather    # WeatherAgent
  gem 'forecast_io', '~> 2.0.0',    group: :weather    # WeatherAgent
  gem 'rturk', '~> 2.12.1',         group: :human_task # HumanTaskAgent
  gem 'hipchat', '~> 1.2.0',        group: :hipchat    # HipchatAgent
  gem 'xmpp4r',  '~> 0.5.6',        group: :jabber     # JabberAgent
  gem 'mqtt',                       group: :mqtt       # MqttAgent
  gem 'slack-notifier', '~> 1.0.0', group: :slack      # SlackAgent
  gem 'hypdf', '~> 1.0.7',          group: :pdf_info   # PdfInfoAgent

  # Weibo Agents
  gem 'weibo_2', github: 'cantino/weibo_2', branch: 'master', group: :weibo

  # GoogleCalendarPublishAgent
  gem "google-api-client", require: 'google/api_client', group: :google_api

  # Twitter Agents
  group :twitter do
    gem 'twitter', '~> 5.14.0' # Must to be loaded before cantino-twitter-stream.
    gem 'twitter-stream', github: 'cantino/twitter-stream', branch: 'huginn'
    gem 'omniauth-twitter'
  end

  # Tumblr Agents
  group :tumblr do
    gem 'tumblr_client'
    gem 'omniauth-tumblr'
  end

  # Dropbox Agents
  group :dropbox do
    gem 'dropbox-api'
    gem 'omniauth-dropbox'
  end

  # UserLocationAgent
  group :user_location do
    gem 'haversine'
  end

  # Optional services.

  # BasecampAgent
  group :basecamp do
    gem 'omniauth-37signals'
  end

  # GitHub
  group :github do
    gem 'omniauth-github'
  end

  # WunderListAgent
  group :wunderlist do
    gem 'omniauth-wunderlist', github: 'wunderlist/omniauth-wunderlist', ref: 'd0910d0396107b9302aa1bc50e74bb140990ccb8'
  end
end
