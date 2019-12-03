require 'rails_helper'

describe GoogleCalendar do
  it '#open does not mask exception in initlize' do
    stub(Google::Apis::CalendarV3::CalendarService).new do
      raise "test exception"
    end
    expect {
      GoogleCalendar.open({'google' => {}}, Rails.logger) {}
    }.to raise_error(/test exception/)
  end
end
