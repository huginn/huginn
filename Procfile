web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb
worker:  bundle exec rake jobs:work
schedule: bundle exec rails runner bin/schedule.rb