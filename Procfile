#################
# DEVELOPMENT   #
#################

# Procfile for development using the new threaded worker (scheduler, twitter stream and delayed job)
web: bundle exec rails server -b0.0.0.0
jobs: bundle exec rails runner bin/threaded.rb

# Old version with separate processes (use this if you have issues with the threaded version)
# web: bundle exec rails server
# schedule: bundle exec rails runner bin/schedule.rb
# twitter: bundle exec rails runner bin/twitter_stream.rb
# dj: bundle exec script/delayed_job run

#################
# PRODUCTION    #
#################

# Using the threaded worker (consumes less RAM but can run slower)
# web: bundle exec unicorn -c config/unicorn.rb
# jobs: bundle exec rails runner bin/threaded.rb

# Old version with separate processes (use this if you have issues with the threaded version)
# web: bundle exec unicorn -c config/unicorn.rb
# schedule: bundle exec rails runner bin/schedule.rb
# twitter: bundle exec rails runner bin/twitter_stream.rb
# dj: bundle exec script/delayed_job run
