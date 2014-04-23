require 'spec_helper'

describe Agents::HipchatAgent do
  before(:each) do
    @valid_params = {
                      'auth_token' => 'token',
                      'room_name' => 'test',
                      'room_name_path' => '',
                      'username' => "Huginn",
                      'username_path' => '$.username',
                      'message' => "Hello from Huginn!",
                      'message_path' => '$.message',
                      'notify' => false,
                      'notify_path' => '',
                      'color' => 'yellow',
                      'color_path' => '',
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

  describe "helpers" do
    describe "select_option" do
      it "should use the room_name_path if specified" do
        @checker.options['room_name_path'] = "$.room_name"
        @checker.send(:select_option, @event, :room_name).should == "test room"
      end

      it "should use the normal option when the path option is blank" do
        @checker.send(:select_option, @event, :room_name).should == "test"
      end
    end

    it "should merge all options" do
      @checker.send(:merge_options, @event).should == {
        :room_name => "test",
        :username => "Huggin user",
        :message => "Looks like its going to rain",
        :notify => false,
        :color => "yellow"
      }
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
