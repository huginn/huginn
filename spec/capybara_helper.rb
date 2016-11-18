require 'rails_helper'
require 'capybara/rails'
require 'capybara/poltergeist'
require 'capybara-select2'

CAPYBARA_TIMEOUT = ENV['CI'] == 'true' ? 60 : 5

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, timeout: CAPYBARA_TIMEOUT)
end

Capybara.javascript_driver = :poltergeist
Capybara.default_max_wait_time = CAPYBARA_TIMEOUT
module Capybara::Select2
  module CloseBeforeSelecting
    def select2(value, options = {})
      page.execute_script('$(".select2.select2-container--open").prev("select").select2("close")')
      super
    end
  end

  prepend CloseBeforeSelecting
end

RSpec.configure do |config|
  config.include Warden::Test::Helpers
  config.include AlertConfirmer, type: :feature

  config.before(:suite) do
    Warden.test_mode!
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do |example|
    DatabaseCleaner.strategy = example.metadata[:js] ? :truncation : :transaction
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
    Warden.test_reset!
  end
end

VCR.configure do |config|
  config.ignore_localhost = true
end
