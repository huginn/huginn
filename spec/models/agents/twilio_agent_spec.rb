require 'spec_helper'

describe Agents::TwilioAgent do
  before do
    @checker = Agents::TwilioAgent.new(:name => 'somename',
                                       :options => { :account_sid => 'x',
                                                     :auth_token => 'x',
                                                     :sender_cell => 'x',
                                                     :receiver_cell => 'x',
                                                     :server_url    => 'http://somename.com:3000',
                                                     :receive_text  => 'true',
                                                     :receive_call  => 'true',
                                                     :expected_receive_period_in_days => '1' })
    @checker.user = users(:bob)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :message => 'Looks like its going to rain' }
    @event.save!

    @sent_messages = []
    stub.any_instance_of(Agents::TwilioAgent).send_message { |message| @sent_messages << message}
    stub.any_instance_of(Agents::TwilioAgent).make_call {}
  end

  describe '#receive' do
    it 'should make sure multiple events are being received' do
      event1 = Event.new
      event1.agent = agents(:bob_rain_notifier_agent)
      event1.payload = { :message => 'Some message' }
      event1.save!

      event2 = Event.new
      event2.agent = agents(:bob_weather_agent)
      event2.payload = { :message => 'Some other message' }
      event2.save!

      @checker.receive([@event,event1,event2])
      @sent_messages.should == ['Looks like its going to rain','Some message','Some other message']
    end

    it 'should check if receive_text is working fine' do
      @checker.options[:receive_text] = 'false'
      @checker.receive([@event])
      @sent_messages.should be_empty
    end

    it 'should check if receive_call is working fine' do
      @checker.options[:receive_call] = 'true'
      @checker.receive([@event])
      @checker.memory[:pending_calls].should_not == {}
    end

  end

  describe '#working?' do
    it 'checks if events have been received within the expected receive period' do
      @checker.should_not be_working # No events received
      Agents::TwilioAgent.async_receive @checker.id, [@event.id]
      @checker.reload.should be_working # Just received events
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      @checker.reload.should_not be_working # More time has passed than the expected receive period without any new events
    end
  end

  describe "validation" do
    before do
      @checker.should be_valid
    end

    it "should validate presence of of account_sid" do
      @checker.options[:account_sid] = ""
      @checker.should_not be_valid
    end

    it "should validate presence of auth_token" do
      @checker.options[:auth_token] = ""
      @checker.should_not be_valid
    end

    it "should validate presence of receiver_cell" do
      @checker.options[:receiver_cell] = ""
      @checker.should_not be_valid
    end

    it "should validate presence of sender_cell" do
      @checker.options[:sender_cell] = ""
      @checker.should_not be_valid
    end

    it "should make sure filling sure filling server_url is not necessary" do
      @checker.options[:server_url] = ""
      @checker.should be_valid
    end
  end
end