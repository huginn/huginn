source 'https://rubygems.org'

gem 'rails'
gem 'rake'
gem 'mysql2'
gem 'devise'
gem 'kaminari'
gem 'bootstrap-kaminari-views'
gem "rufus-scheduler", :require => false
gem 'json', '>= 1.7.7'
gem 'jsonpath'
gem 'twilio-ruby'
gem 'ruby-growl'

gem 'delayed_job'
gem 'delayed_job_active_record'#, "~> 0.3.3" # newer was giving a strange MySQL error
gem "daemons"

# To enable DelayedJobWeb, see the 'Enable DelayedJobWeb' section of the README.
# gem "delayed_job_web"

gem 'foreman'
gem 'dotenv-rails', :groups => [:development, :test]

gem 'sass-rails',   '~> 3.2.3'
gem 'coffee-rails', '~> 3.2.1'
gem 'uglifier', '>= 1.0.3'
gem 'select2-rails'
gem 'jquery-rails'
gem 'ace-rails-ap'

gem 'geokit-rails3'
gem 'kramdown'
gem "typhoeus"
gem 'nokogiri'
gem 'wunderground'
gem 'forecast_io'
gem 'rturk'

gem "twitter", '~> 5.7.1'
gem 'twitter-stream', :git => 'https://github.com/cantino/twitter-stream', :branch => 'master'
gem 'em-http-request'
gem 'weibo_2'

gem 'therubyracer'

platforms :ruby_18 do
  gem 'system_timer'
  gem 'fastercsv'
end

group :development do
  gem 'binding_of_caller'
  gem 'better_errors'
end

group :development, :test do
  gem 'pry'
  gem 'rspec-rails'
  gem 'rspec'
  gem 'shoulda-matchers'
  gem 'rr'
  gem 'webmock', :require => false
  gem 'coveralls', :require => false
end
