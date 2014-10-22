require 'spec_helper'

describe Agents::GoogleCalendarPublishAgent, :vcr do
  before do
    @valid_params = {
        'expected_update_period_in_days' => "10",
        'calendar_id' => 'sqv39gj35tc837gdns1g4d81cg@group.calendar.google.com',
        'google' => {
          'key_file' => File.dirname(__FILE__) + '/../../data_fixtures/private.key',
          'key_secret' => 'notasecret',
          'service_account_email' => '1029936966326-ncjd7776pcspc98hsg82gsb56t3217ef@developer.gserviceaccount.com'
        }
      }
    @checker = Agents::GoogleCalendarPublishAgent.new(:name => "somename", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!
  end

  describe '#receive' do
    it 'should publish any payload it receives' do
      event1 = Event.new
      event1.agent = agents(:bob_manual_event_agent)
      event1.payload = {
        'message' => { 
          'visibility' => 'default',
          'summary' => "Awesome event",
          'description' => "An example event with text. Pro tip: DateTimes are in RFC3339",
          'end' => {
            'dateTime' => '2014-10-02T11:00:00-05:00'
          },
          'start' => {
            'dateTime' => '2014-10-02T10:00:00-05:00'
          }
        }
      }
      event1.save!

      @checker.receive([event1])

      expect(@checker.events.count).to eq(1)
    end
  end
end
