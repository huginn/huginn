source 'https://rubygems.org'

# Bundler <1.5 does not recognize :x64_mingw as a valid platform name.
# Unfortunately, it can't self-update because it errors when encountering :x64_mingw.
unless Gem::Version.new(Bundler::VERSION) >= Gem::Version.new('1.5.0')
  STDERR.puts "Bundler >=1.5.0 is required.  Please upgrade bundler with 'gem install bundler'"
  exit 1
end

gem 'bundler', '>= 1.5.0'

gem 'protected_attributes', '~>1.0.7'

gem 'rails', '4.1.1'

case RUBY_PLATFORM
when /freebsd/
  # Seems FreeBSD's zoneinfo is not exactly what tzinfo expects
  gem 'tzinfo-data'
else
  # Windows does not include zoneinfo files, so bundle the tzinfo-data gem
  gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]
end

gem 'mysql2', '~> 0.3.15'
gem 'devise', '~> 3.2.4'
gem 'kaminari', '~> 0.15.1'
gem 'bootstrap-kaminari-views', '~> 0.0.2'
gem 'rufus-scheduler', '~> 3.0.7', require: false
gem 'json', '~> 1.8.1'
gem 'jsonpath', '~> 0.5.3'
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

# geokit-rails doesn't work with geokit 1.8.X but it specifies ~> 1.5
# in its own Gemfile.
gem 'geokit', '~> 1.8.4'
gem 'geokit-rails', '~> 2.0.1'

gem 'kramdown', '~> 1.3.3'
gem 'faraday', '~> 0.9.0'
gem 'faraday_middleware'
gem 'typhoeus', '~> 0.6.3'
gem 'nokogiri', '~> 1.6.1'

gem 'wunderground', '~> 1.2.0'
gem 'forecast_io', '~> 2.0.0'
gem 'rturk', '~> 2.12.1'

gem 'twitter', '~> 5.8.0'
gem 'twitter-stream', github: 'cantino/twitter-stream', branch: 'master'
gem 'em-http-request', '~> 1.1.2'
gem 'weibo_2', '~> 0.1.4'
gem 'hipchat', '~> 1.2.0'
gem 'xmpp4r',  '~> 0.5.6'
gem 'slack-notifier', '~> 0.5.0'

gem 'therubyracer', '~> 0.12.1'

gem 'mqtt'

group :development do
  gem 'binding_of_caller'
  gem 'better_errors'
end

group :development, :test do
  gem 'dotenv-rails'
  gem 'pry'
  gem 'rspec-rails'
  gem 'rspec'
  gem 'shoulda-matchers'
  gem 'rr'
  gem 'delorean'
  gem 'webmock', require: false
  gem 'coveralls', require: false
end

group :production do
  gem 'dotenv-deployment'
  gem 'rack'
end
