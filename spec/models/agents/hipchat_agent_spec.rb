require 'spec_helper'

describe Agents::HipchatAgent do
  before(:each) do
    @valid_params = {
                      'auth_token' => 'token',
                      'room_name' => 'test',
                      'username' => "{{username}}",
                      'message' => "{{message}}",
                      'notify' => 'false',
                      'color' => 'yellow',
                    }

    @checker = Agents::HipchatAgent.new(:name => "somename", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :room_name => 'test room', :message => 'Looks like its going to rain', username: "Huggin user                  "}
    @event.save!
  end

  describe "validating" do
    before do
      expect(@checker).to be_valid
    end

    it "should require the basecamp username" do
      @checker.options['auth_token'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require the basecamp password" do
      @checker.options['room_name'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require the basecamp user_id" do
      @checker.options['room_name'] = nil
      @checker.options['room_name_path'] = 'jsonpath'
      expect(@checker).to be_valid
    end

    it "should also allow a credential" do
      @checker.options['auth_token'] = nil
      expect(@checker).not_to be_valid
      @checker.user.user_credentials.create :credential_name => 'hipchat_auth_token', :credential_value => 'something'
      expect(@checker.reload).to be_valid
    end
  end

  describe "#receive" do
    it "send a message to the hipchat" do
      any_instance_of(HipChat::Room) do |obj|
        mock(obj).send(@event.payload[:username][0..14], @event.payload[:message], {:notify => false, :color => 'yellow'})
      end
      @checker.receive([@event])
    end
  end

  describe "#working?" do
    it "should not be working until the first event was received" do
      expect(@checker).not_to be_working
      @checker.last_receive_at = Time.now
      expect(@checker).to be_working
    end

    it "should not be working when the last error occured after the last received event" do
      @checker.last_receive_at = Time.now - 1.minute
      @checker.last_error_log_at = Time.now
      expect(@checker).not_to be_working
    end

    it "should be working when the last received event occured after the last error" do
      @checker.last_receive_at = Time.now
      @checker.last_error_log_at = Time.now - 1.minute
      expect(@checker).to be_working
    end
  end
end
