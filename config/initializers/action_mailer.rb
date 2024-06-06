ActionMailer::Base.smtp_settings = {}.tap { |config|
  config[:address] = ENV['SMTP_SERVER'] || 'smtp.gmail.com'
  config[:port] = ENV['SMTP_PORT']&.to_i || 587
  config[:domain] = ENV['SMTP_DOMAIN']

  authentication = ENV['SMTP_AUTHENTICATION'].presence || 'plain'
  user_name = ENV['SMTP_USER_NAME'].presence || 'none'

  if authentication != 'none' && user_name != 'none'
    config[:authentication] = authentication
    config[:user_name] = user_name
    config[:password] = ENV['SMTP_PASSWORD'].presence
  end

  config[:enable_starttls_auto] = ENV['SMTP_ENABLE_STARTTLS_AUTO'] == 'true'
  config[:ssl] = ENV['SMTP_SSL'] == 'true'
  config[:openssl_verify_mode] = ENV['SMTP_OPENSSL_VERIFY_MODE'].presence
  config[:ca_path] = ENV['SMTP_OPENSSL_CA_PATH'].presence
  config[:ca_file] = ENV['SMTP_OPENSSL_CA_FILE'].presence
  config[:read_timeout] = ENV['SMTP_READ_TIMEOUT']&.to_i
  config[:open_timeout] = ENV['SMTP_OPEN_TIMEOUT']&.to_i
}
