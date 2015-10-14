###############################
#         DEVELOPMENT         #
###############################

# Procfile for development using the new threaded worker (scheduler, twitter stream and delayed job)
web: bundle exec rails server -p ${PORT-3000} -b ${IP-0.0.0.0}
jobs: bundle exec rails runner bin/threaded.rb

# Old version with separate processes (use this if you have issues with the threaded version)
# web: bundle exec rails server
# schedule: bundle exec rails runner bin/schedule.rb
# twitter: bundle exec rails runner bin/twitter_stream.rb
# dj: bundle exec script/delayed_job run

###############################
#         PRODUCTION          #
###############################

# You need to copy or link config/unicorn.rb.example to config/unicorn.rb for both production versions.
# Have a look at the deployment guides, if you want to set up huginn on your server:
# https://github.com/cantino/huginn/doc

# Using the threaded worker (consumes less RAM but can run slower)
# web: bundle exec unicorn -c config/unicorn.rb
# jobs: bundle exec rails runner bin/threaded.rb

# Old version with separate processes (use this if you have issues with the threaded version)
# web: bundle exec unicorn -c config/unicorn.rb
# schedule: bundle exec rails runner bin/schedule.rb
# twitter: bundle exec rails runner bin/twitter_stream.rb
# dj: bundle exec script/delayed_job run

###############################
# Multiple DelayedJob workers #
###############################
# Per default Huginn can just run one agent at a time. Using a lot of agents or calling slow
# external services frequently might require more DelayedJob workers (an indicator for this is
# a backlog in your 'Job Management' page).
# Every uncommented line starts an additional DelayedJob worker. This works for development, production
# and for the threaded and separate worker processes. Keep in mind one worker needs about 300MB of RAM.
#
#dj2: bundle exec script/delayed_job -i 2 run
#dj3: bundle exec script/delayed_job -i 3 run
#dj4: bundle exec script/delayed_job -i 4 run
#dj5: bundle exec script/delayed_job -i 5 run
#dj6: bundle exec script/delayed_job -i 6 run
#dj7: bundle exec script/delayed_job -i 7 run
#dj8: bundle exec script/delayed_job -i 8 run
#dj9: bundle exec script/delayed_job -i 9 run
#dj10: bundle exec script/delayed_job -i 10 run
