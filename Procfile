# Procfile for development using the new threaded worker (scheduler, twitter stream and delayed job)
# web: bundle exec rails server
# jobs: bundle exec rails runner bin/threaded.rb

web: bundle exec unicorn -p $PORT -c ./deployment/heroku/unicorn.rb

# Possible Profile configuration for production:
# web: bundle exec unicorn -c config/unicorn/production.rb
# jobs: bundle exec rails runner bin/threaded.rb

# Old version with seperate processes for each component (use this if you have issues with the threaded version)
# web: bundle exec rails server
# schedule: bundle exec rails runner bin/schedule.rb
# twitter: bundle exec rails runner bin/twitter_stream.rb
# dj: bundle exec script/delayed_job run
