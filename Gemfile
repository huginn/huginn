source 'https://rubygems.org'

# Bundler <1.5 does not recognize :x64_mingw as a valid platform name.
# Unfortunately, it can't self-update because it errors when encountering :x64_mingw.
unless Gem::Version.new(Bundler::VERSION) >= Gem::Version.new('1.5.0')
  STDERR.puts "Bundler >=1.5.0 is required.  Please upgrade bundler with 'gem install bundler'"
  exit 1
end

gem 'bundler', '>= 1.5.0'

gem 'protected_attributes', '~>1.0.8'

gem 'rails' , '4.1.5'

case RUBY_PLATFORM
when /freebsd|netbsd|openbsd/
  # ffi (required by typhoeus via ethon) merged fixes for bugs fatal
  # on these platforms after 1.9.3; no following release as yet.
  gem 'ffi', github: 'ffi/ffi', branch: 'master'

  # tzinfo 1.2.0 has added support for reading zoneinfo on these
  # platforms.
  gem 'tzinfo', '>= 1.2.0'
when /solaris/
  # ditto
  gem 'tzinfo', '>= 1.2.0'
end

# Windows does not have zoneinfo files, so bundle the tzinfo-data gem.
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]

gem 'mysql2', '~> 0.3.16'
gem 'devise', '~> 3.2.4'
gem 'kaminari', '~> 0.16.1'
gem 'bootstrap-kaminari-views', '~> 0.0.3'
gem 'rufus-scheduler', '~> 3.0.8', require: false
gem 'json', '~> 1.8.1'
gem 'jsonpath', '~> 0.5.6'
gem 'twilio-ruby', '~> 3.11.5'
gem 'ruby-growl', '~> 4.1.0'
gem 'liquid', '~> 2.6.1'

gem 'delayed_job', '~> 4.0.0'
gem 'delayed_job_active_record', '~> 4.0.0'
gem 'daemons', '~> 1.1.9'

# To enable DelayedJobWeb, see the 'Enable DelayedJobWeb' section of the README.
# gem 'delayed_job_web'

gem 'foreman', '~> 0.63.0'

gem 'sass-rails',   '~> 4.0.0'
gem 'coffee-rails', '~> 4.0.0'
gem 'uglifier', '>= 1.3.0'
gem 'select2-rails', '~> 3.5.4'
gem 'jquery-rails', '~> 3.1.0'
gem 'ace-rails-ap', '~> 2.0.1'
gem 'spectrum-rails'


# geokit-rails doesn't work with geokit 1.8.X but it specifies ~> 1.5
# in its own Gemfile.
gem 'geokit', '~> 1.8.4'
gem 'geokit-rails', '~> 2.0.1'

gem 'kramdown', '~> 1.3.3'
gem 'faraday', '~> 0.9.0'
gem 'faraday_middleware'
gem 'typhoeus', '~> 0.6.3'
gem 'nokogiri', '~> 1.6.1'
gem 'net-ftp-list', '~> 3.2.8'

gem 'wunderground', '~> 1.2.0'
gem 'forecast_io', '~> 2.0.0'
gem 'rturk', '~> 2.12.1'

gem "google-api-client"

gem 'twitter', '~> 5.8.0'
gem 'cantino-twitter-stream', github: 'cantino/twitter-stream', branch: 'master'
gem 'em-http-request', '~> 1.1.2'
gem 'weibo_2', '~> 0.1.4'
gem 'hipchat', '~> 1.2.0'
gem 'xmpp4r',  '~> 0.5.6'
gem 'feed-normalizer'
gem 'slack-notifier', '~> 0.5.0'
gem 'therubyracer', '~> 0.12.1'
gem 'mqtt'

gem 'omniauth'
gem 'omniauth-twitter'
gem 'omniauth-37signals'
gem 'omniauth-github'

group :development do
  gem 'binding_of_caller'
  gem 'better_errors'
  gem 'quiet_assets'
end

group :development, :test do
  gem 'vcr'
  gem 'dotenv-rails'
  gem 'pry'
  gem 'rspec-rails', '~> 2.99'
  gem 'rspec', '~> 2.99'
  gem 'rspec-collection_matchers'
  gem 'shoulda-matchers'
  gem 'rr'
  gem 'delorean'
  gem 'webmock', '~> 1.17.4', require: false
  gem 'coveralls', require: false
  gem 'spring'
  gem 'spring-commands-rspec'
end

group :production do
  gem 'dotenv-deployment'
  gem 'rack'
end

# This hack needs some explanation.  When on Heroku, use the pg, unicorn, and rails12factor gems.
# When not on Heroku, we still want our Gemfile.lock to include these gems, so we scope them to
# an unsupported platform.
if ENV['ON_HEROKU'] || ENV['HEROKU_POSTGRESQL_ROSE_URL'] || File.read(File.join(File.dirname(__FILE__), 'Procfile')) =~ /intended for Heroku/
  gem 'pg'
  gem 'unicorn'
  gem 'rails_12factor'
else
  gem 'pg', platform: :ruby_18
  gem 'unicorn', platform: :ruby_18
  gem 'rails_12factor', platform: :ruby_18
end
