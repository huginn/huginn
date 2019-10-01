$stdout.sync = true

Rails.application.configure do
  config.middleware.insert_after ActionDispatch::Static, Rack::LiveReload

  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Raise exception for unpermitted parameters
  config.action_controller.action_on_unpermitted_parameters = :raise

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Expands the lines which load the assets
  config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  config.action_mailer.default_url_options = { :host => ENV['DOMAIN'] }
  config.action_mailer.asset_host = ENV['DOMAIN']
  config.action_mailer.raise_delivery_errors = true
  if ENV['SEND_EMAIL_IN_DEVELOPMENT'] == 'true'
    config.action_mailer.delivery_method = :smtp
  else
    config.action_mailer.delivery_method = :letter_opener_web
  end
  config.action_mailer.perform_caching = false
  # smtp_settings moved to config/initializers/action_mailer.rb

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
end
