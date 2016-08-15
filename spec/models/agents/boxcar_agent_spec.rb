require 'rails_helper'

describe Agents::BoxcarAgent do
  before(:each) do
  @valid_params = {
                    'user_credentials' => 'access_token',
                    'title' => 'Sample Title',
                    'body' => 'Sample Body'
                  }
  @checker = Agents::BoxcarAgent.new(:name => "boxcartest", :options => @valid_params)
  @checker.user = users(:bob)
  @checker.save!

  @event = Event.new
  @event.agent = agents(:bob_weather_agent)
  @event.payload = { :body => 'Sample message' }
  @event.save!
  end

  describe 'validating' do
    before do
      expect(@checker).to be_valid
    end

    it "should require access token" do
      @checker.options['user_credentials'] = nil
      expect(@checker).not_to be_valid
    end
  end

  describe '#working?' do
    it "should not be working until the first event was received" do
      expect(@checker).not_to be_working
      @checker.last_receive_at = Time.now
      expect(@checker).to be_working
    end
  end

  describe "#receive" do
    it "sends a message" do
      stub(HTTParty).post { {"id" => 1, "message" => "blah", "title" => "blah","source_name" => "Custom Notification"} }
      @checker.receive([@event])
    end

    it "should raise error when invalid response arrives" do
      stub(HTTParty).post { {"blah" => "blah"} }
      expect { @checker.send_notification({}) }.to raise_error(StandardError, /Invalid response from Boxcar:/)
    end

    it "should raise error when response says unauthorized" do
      stub(HTTParty).post { {"Response" => "Not authorized"} }
      expect { @checker.send_notification({}) }.to raise_error(StandardError, /Not authorized/)
    end

    it "should raise error when response has an error" do
      stub(HTTParty).post { {"error" => {"message" => "Sample error"}} }
      expect { @checker.send_notification({}) }.to raise_error(StandardError, /Sample error/)
    end
  end
end
