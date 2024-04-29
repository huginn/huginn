require 'rails_helper'

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

    @checker = Agents::HipchatAgent.new(name: "somename", options: @valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = {
      room_name: 'test room',
      message: 'Looks like its going to rain',
      username: "Huggin user                  "
    }
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
      @checker.user.user_credentials.create credential_name: 'hipchat_auth_token', credential_value: 'something'
      expect(@checker.reload).to be_valid
    end
  end

  describe "#validate_auth_token" do
    it "should return true when valid" do
      allow_any_instance_of(HipChat::Client).to receive(:rooms) { true }
      expect(@checker.validate_auth_token).to be true
    end

    it "should return false when invalid" do
      allow_any_instance_of(HipChat::Client).to receive(:rooms).and_raise(HipChat::UnknownResponseCode, '403')
      expect(@checker.validate_auth_token).to be false
    end
  end

  describe "#complete_room_name" do
    it "should return a array of hashes" do
      allow_any_instance_of(HipChat::Client).to receive(:rooms) {
                                                  [OpenStruct.new(name: 'test'), OpenStruct.new(name: 'test1')]
                                                }
      expect(@checker.complete_room_name).to eq [{ text: 'test', id: 'test' }, { text: 'test1', id: 'test1' }]
    end
  end

  describe "#receive" do
    it "send a message to the hipchat" do
      expect_any_instance_of(HipChat::Room).to receive(:send).with(@event.payload[:username][0..14],
                                                                   @event.payload[:message], { notify: false, color: 'yellow', message_format: 'html' })
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
