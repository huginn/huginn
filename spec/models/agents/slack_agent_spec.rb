require 'spec_helper'
require 'models/concerns/liquid_interpolatable'

describe Agents::SlackAgent do
  it_behaves_like LiquidInterpolatable

  before(:each) do
    @valid_params = {
                      'auth_token' => 'token',
                      'team_name' => 'testteam',
                      'channel' => '#random',
                      'username' => "{{username}}",
                      'message' => "{{message}}"
                    }

    @checker = Agents::SlackAgent.new(:name => "slacker", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :channel => '#random', :message => 'Looks like its going to rain', username: "Huggin user"}
    @event.save!
  end

  describe "validating" do
    before do
      expect(@checker).to be_valid
    end

    it "should require a auth_token" do
      @checker.options['auth_token'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require a channel" do
      @checker.options['channel'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require a team_name" do
      @checker.options['team_name'] = 'nil'
      expect(@checker).to be_valid
    end
  end
  describe "#receive" do
    it "receive an event without errors" do
      any_instance_of(Slack::Notifier) do |obj|
        mock(obj).ping(@event.payload[:message],
                       channel: @event.payload[:channel],
                       username: @event.payload[:username]
                      )
      end
      expect(@checker.receive([@event])).to_not raise_error
    end
  end

  describe "#working?" do
    it "should call received_event_without_error?" do
      mock(@checker).received_event_without_error?
      @checker.working?
    end
  end
end
