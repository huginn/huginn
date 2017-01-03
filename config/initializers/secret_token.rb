# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
Huginn::Application.config.secret_key_base = ENV['APP_SECRET_TOKEN']

# Your encryption key for encrypting sensitive data in the database, such as
# credentials.
# If you change this key, all currently encrypted data in the database will
# become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
Huginn::Application.config.encryption_key = ENV['APP_ENCRYPTION_PASSPHRASE']
