# Procfile for development:
web: bundle exec rails server
schedule: bundle exec rails runner bin/schedule.rb
twitter: bundle exec rails runner bin/twitter_stream.rb
dj: bundle exec script/delayed_job run

# Possible Profile configuration for production:
# web: bundle exec unicorn -c config/unicorn/production.rb
# schedule: bundle exec rails runner bin/schedule.rb
# twitter: bundle exec rails runner bin/twitter_stream.rb
# dj: bundle exec script/delayed_job run