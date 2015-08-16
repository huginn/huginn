# Read smtp config out of a config/smtp.yml file

smtp_config = YAML::load(ERB.new(File.read(Rails.root.join('config', 'smtp.yml'))).result)
if smtp_config.keys.include? Rails.env
  ActionMailer::Base.smtp_settings = smtp_config[Rails.env].symbolize_keys
end