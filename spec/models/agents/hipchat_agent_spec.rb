require 'spec_helper'
require 'models/concerns/liquid_interpolatable'

describe Agents::HipchatAgent do
  it_behaves_like LiquidInterpolatable

  before(:each) do
    @valid_params = {
                      'auth_token' => 'token',
                      'room_name' => 'test',
                      'username' => "{{username}}",
                      'message' => "{{message}}",
                      'notify' => false,
                      'color' => 'yellow',
                    }

    @checker = Agents::HipchatAgent.new(:name => "somename", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :room_name => 'test room', :message => 'Looks like its going to rain', username: "Huggin user"}
    @event.save!
  end

  describe "validating" do
    before do
      @checker.should be_valid
    end

    it "should require the basecamp username" do
      @checker.options['auth_token'] = nil
      @checker.should_not be_valid
    end

    it "should require the basecamp password" do
      @checker.options['room_name'] = nil
      @checker.should_not be_valid
    end

    it "should require the basecamp user_id" do
      @checker.options['room_name'] = nil
      @checker.options['room_name_path'] = 'jsonpath'
      @checker.should be_valid
    end

  end

  describe "#receive" do
    it "send a message to the hipchat" do
      any_instance_of(HipChat::Room) do |obj|
        mock(obj).send(@event.payload[:username], @event.payload[:message], {:notify => 0, :color => 'yellow'})
      end
      @checker.receive([@event])
    end
  end

  describe "#working?" do
    it "should not be working until the first event was received" do
      @checker.should_not be_working
      @checker.last_receive_at = Time.now
      @checker.should be_working
    end

    it "should not be working when the last error occured after the last received event" do
      @checker.last_receive_at = Time.now - 1.minute
      @checker.last_error_log_at = Time.now
      @checker.should_not be_working
    end

    it "should be working when the last received event occured after the last error" do
      @checker.last_receive_at = Time.now
      @checker.last_error_log_at = Time.now - 1.minute
      @checker.should be_working
    end
  end
end
