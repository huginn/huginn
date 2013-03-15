# == Schema Information
#
# Table name: agents
#
#  id                    :integer          not null, primary key
#  user_id               :integer
#  options               :text
#  type                  :string(255)
#  name                  :string(255)
#  schedule              :string(255)
#  events_count          :integer
#  last_check_at         :datetime
#  last_receive_at       :datetime
#  last_checked_event_id :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  memory                :text
#

require 'securerandom'

module Agents
  class UserLocationAgent < Agent
    cannot_receive_events!
    cannot_be_scheduled!

    description do
      <<-MD
        The UserLocationAgent creates events based on WebHook POSTS that contain a `latitude` and `longitude`.  You can use the POSTLocation iOS app to post your location.

        Your POST path will be `https://#{DOMAIN}/users/#{user.id}/update_location/:secret` where `:secret` is specified in your options.
      MD
    end

    event_description <<-MD
      Assuming you're using the iOS application, events look like this:

          {
            :latitude => "37.12345",
            :longitude => "-122.12345",
            :timestamp => "123456789.0",
            :altitude => "22.0",
            :horizontal_accuracy => "5.0",
            :vertical_accuracy => "3.0",
            :speed => "0.52595",
            :course => "72.0703",
            :device_token => "..."
          }
    MD

    def working?
      (event = event_created_within(2.days)) && event.payload.present?
    end

    def default_options
      { :secret => SecureRandom.hex(7) }
    end

    def validate_options
      errors.add(:base, "secret is required and must be longer than 4 characters") unless options[:secret].present? && options[:secret].length > 4
    end
  end
end
