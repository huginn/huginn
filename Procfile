###############################
#         DEVELOPMENT         #
###############################

# Procfile for development using the threaded worker
web: bundle exec puma -C config/puma.rb
jobs: bundle exec rails runner bin/threaded.rb

# Separate AgentRunner and delayed_job_master processes
# web: bundle exec puma -C config/puma.rb
# jobs: bundle exec rails runner bin/agent_runner.rb
# dj: env DELAYED_JOB_WORKERS=2 bundle exec bin/delayed_job_master -c config/delayed_job_master.rb

###############################
#         PRODUCTION          #
###############################

# Puma uses config/puma.rb for both production versions.

# Using the threaded worker (consumes less RAM but can run slower)
# web: bundle exec puma -C config/puma.rb
# jobs: bundle exec rails runner bin/threaded.rb

# Using separate AgentRunner and delayed_job_master processes
# web: bundle exec puma -C config/puma.rb
# jobs: bundle exec rails runner bin/agent_runner.rb
# dj: env DELAYED_JOB_WORKERS=2 bundle exec bin/delayed_job_master -c config/delayed_job_master.rb
