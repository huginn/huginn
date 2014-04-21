# Be sure to restart your server when you modify this file.

# Use the OpenShift secret generator
require File.join(Rails.root,'lib','openshift_secret_generator.rb')

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.

# start with the configured secret token
Huginn::Application.config.secret_token = ENV['APP_SECRET_TOKEN']

# ...but use the OpenShift secret generator if that's available
if defined?(ENV['OPENSHIFT_APP_NAME'])
  require File.join(Rails.root,'lib','openshift_secret_generator.rb')
  Huginn::Application.config.secret_token = get_env_secret
end
