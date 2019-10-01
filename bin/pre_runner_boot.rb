unless defined?(Rails)
  puts
  puts "Please run me with rails runner, for example:"
  puts "  RAILS_ENV=production bundle exec rails runner bin/#{File.basename($0)}"
  puts
  exit 1
end

Rails.configuration.cache_classes = true

Dotenv.load if ENV['APP_SECRET_TOKEN'].blank?
