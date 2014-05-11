# Procfile for development:
web: bundle exec rails server
schedule: bundle exec rails runner bin/schedule.rb
twitter: bundle exec rails runner bin/twitter_stream.rb
dj: bundle exec script/delayed_job run

# Procfile for the exprimental threaded scheduler, twitter stream and delayed job
#web: bundle exec rails server
#jobs: bundle exec rails runner bin/threaded.rb

# Possible Profile configuration for production:
# web: bundle exec unicorn -c config/unicorn/production.rb
# schedule: bundle exec rails runner bin/schedule.rb
# twitter: bundle exec rails runner bin/twitter_stream.rb
# dj: bundle exec script/delayed_job run
