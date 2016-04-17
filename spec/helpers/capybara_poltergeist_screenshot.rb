require 'launchy'

module Capybara
  module PoltergeistScreenshot
    def screenshot_and_open_image(full: false)
      timestamp = Time.now.strftime('%Y-%m-%d-%H-%M-%S')
      screenshot_path = "tmp/capybara/screenshot_#{timestamp}_#{SecureRandom.hex}.png"
      page.save_screenshot(screenshot_path, full: full)
      Launchy.open screenshot_path
    end
  end
end
