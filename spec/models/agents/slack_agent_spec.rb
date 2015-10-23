require 'rails_helper'

describe Agents::SlackAgent do
  before(:each) do
    @fallback = "Its going to rain"
    @attachments = [{'fallback' => "{{fallback}}"}]
    @valid_params = {
                      'webhook_url' => 'https://hooks.slack.com/services/random1/random2/token',
                      'channel' => '#random',
                      'username' => "{{username}}",
                      'message' => "{{message}}",
                      'attachments' => @attachments
                    }

    @checker = Agents::SlackAgent.new(:name => "slacker", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :channel => '#random', :message => 'Looks like its going to rain', username: "Huggin user", fallback: @fallback}
    @event.save!
  end

  describe "validating" do
    before do
      expect(@checker).to be_valid
    end

    it "should require a webhook_url" do
      @checker.options['webhook_url'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require a channel" do
      @checker.options['channel'] = nil
      expect(@checker).not_to be_valid
    end

    it "should allow an icon" do
      @checker.options['icon_emoji'] = nil
      expect(@checker).to be_valid
      @checker.options['icon_emoji'] = ":something:"
      expect(@checker).to be_valid
      @checker.options['icon_url'] = "http://something.com/image.png"
      expect(@checker).to be_valid
      @checker.options['icon_emoji'] = "something"
      expect(@checker).to be_valid
    end

    it "should allow attachments" do
      @checker.options['attachments'] = nil
      expect(@checker).to be_valid
      @checker.options['attachments'] = []
      expect(@checker).to be_valid
      @checker.options['attachments'] = @attachments
      expect(@checker).to be_valid
    end
  end

  describe "#receive" do
    it "receive an event without errors" do
      any_instance_of(Slack::Notifier) do |obj|
        mock(obj).ping(@event.payload[:message],
                       attachments: [{'fallback' => @fallback}],
                       channel: @event.payload[:channel],
                       username: @event.payload[:username]
                      )
      end

      expect { @checker.receive([@event]) }.not_to raise_error
    end
  end

  describe "#working?" do
    it "should call received_event_without_error?" do
      mock(@checker).received_event_without_error?
      @checker.working?
    end
  end
end
