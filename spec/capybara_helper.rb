require 'rails_helper'
require 'capybara/rails'
require 'capybara/poltergeist'
require 'capybara-select2'
Capybara.javascript_driver = :poltergeist

RSpec.configure do |config|
  config.include Warden::Test::Helpers
  config.before :suite do
    Warden.test_mode!
  end

  config.after :each do
    Warden.test_reset!
  end
end

VCR.configure do |config|
  config.ignore_localhost = true
end