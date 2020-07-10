Huginn::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Attempt to read encrypted secrets from `config/secrets.yml.enc`.
  # Requires an encryption key in `ENV["RAILS_MASTER_KEY"]` or
  # `config/secrets.yml.key`.
  config.read_encrypted_secrets = false

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  if ENV["RAILS_LOG_TO_STDOUT"].present? ||
       ENV['ON_HEROKU'] ||
       ENV['HEROKU_POSTGRESQL_ROSE_URL'] ||
       ENV['HEROKU_POSTGRESQL_GOLD_URL'] ||
       File.read(File.join(File.dirname(__FILE__), '../../Procfile')) =~ /intended for Heroku/
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # Compress JavaScripts and CSS
  config.assets.js_compressor  = :uglifier
  config.assets.css_compressor = :sass

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ENV['FORCE_SSL'] == 'true'

  # See everything in the log (default is will be :debug in Rails 5.0)
  config.log_level = :info

  # Prepend all log lines with the following tags
  config.log_tags = [ :request_id ] # :subdomain

  # Use a different logger for distributed setups
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production
  config.cache_store = :memory_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  if ENV['ASSET_HOST'].present?
    config.action_controller.asset_host = ENV['ASSET_HOST']
  end

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  config.action_mailer.default_url_options = { :host => ENV['DOMAIN'] }
  config.action_mailer.asset_host = ENV['DOMAIN']
  if ENV['ASSET_HOST'].present?
    config.action_mailer.asset_host = ENV['ASSET_HOST']
  end
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = ENV.fetch('SMTP_DELIVERY_METHOD', 'smtp').to_sym
  config.action_mailer.perform_caching = false
  # smtp_settings moved to config/initializers/action_mailer.rb
end
