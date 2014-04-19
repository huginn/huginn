require 'spec_helper'

describe Agents::PushoverAgent do
  before do
    @checker = Agents::PushoverAgent.new(:name => 'Some Name',
                                       :options => { :token => 'x',
                                                :user => 'x',
                                                :message => 'Some Message',
                                                :device => 'Some Device',
                                                :title => 'Some Message Title',
                                                :url => 'http://someurl.com',
                                                :url_title => 'Some Url Title',
                                                :priority => 0,
                                                :timestamp => 'false',
                                                :sound => 'pushover',
                                                :retry => 0,
                                                :expire => 0,
                                                :expected_receive_period_in_days => '1'})
     
    @checker.user = users(:bob)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :message => 'Looks like its going to rain' }
    @event.save!

    @sent_notifications = []
    stub.any_instance_of(Agents::PushoverAgent).send_notification  { |notification| @sent_notifications << notification}
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
      @sent_notifications[0]['message'].should == 'Looks like its going to rain'
      @sent_notifications[1]['message'].should == 'Some message'
      @sent_notifications[2]['message'].should == 'Some other message'
    end

    it 'should make sure event message overrides default message' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { :message => 'Some new message'}
      event.save!

      @checker.receive([event])
      @sent_notifications[0]['message'].should == 'Some new message'
    end

    it 'should make sure event text overrides default message' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { :text => 'Some new text'}
      event.save!

      @checker.receive([event])
      @sent_notifications[0]['message'].should == 'Some new text'
    end

    it 'should make sure event title overrides default title' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { :message => 'Some message', :title => 'Some new title' }
      event.save!

      @checker.receive([event])
      @sent_notifications[0]['title'].should == 'Some new title'
    end

    it 'should make sure event url overrides default url' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { :message => 'Some message', :url => 'Some new url' }
      event.save!

      @checker.receive([event])
      @sent_notifications[0]['url'].should == 'Some new url'
    end

    it 'should make sure event url_title overrides default url_title' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { :message => 'Some message', :url_title => 'Some new url_title' }
      event.save!

      @checker.receive([event])
      @sent_notifications[0]['url_title'].should == 'Some new url_title'
    end

    it 'should make sure event priority overrides default priority' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { :message => 'Some message', :priority => 1 }
      event.save!

      @checker.receive([event])
      @sent_notifications[0]['priority'].should == 1
    end

    it 'should make sure event timestamp overrides default timestamp' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { :message => 'Some message', :timestamp => 'false' }
      event.save!

      @checker.receive([event])
      @sent_notifications[0]['timestamp'].should == 'false'
    end

    it 'should make sure event sound overrides default sound' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { :message => 'Some message', :sound => 'Some new sound' }
      event.save!

      @checker.receive([event])
      @sent_notifications[0]['sound'].should == 'Some new sound'
    end

    it 'should make sure event retry overrides default retry' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { :message => 'Some message', :retry => 1 }
      event.save!

      @checker.receive([event])
      @sent_notifications[0]['retry'].should == 1
    end

    it 'should make sure event expire overrides default expire' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { :message => 'Some message', :expire => 60 }
      event.save!

      @checker.receive([event])
      @sent_notifications[0]['expire'].should == 60
    end
  end

  describe '#working?' do
    it 'checks if events have been received within the expected receive period' do
      # No events received
      @checker.should_not be_working 
      Agents::PushoverAgent.async_receive @checker.id, [@event.id]

      # Just received events
      @checker.reload.should be_working 
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      
      # More time has passed than the expected receive period without any new events
      @checker.reload.should_not be_working 
    end
  end

  describe "validation" do
    before do
      @checker.should be_valid
    end

    it "should validate presence of token" do
      @checker.options[:token] = ""
      @checker.should_not be_valid
    end

    it "should validate presence of user" do
      @checker.options[:user] = ""
      @checker.should_not be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      @checker.options[:expected_receive_period_in_days] = ""
      @checker.should_not be_valid
    end

    it "should make sure device is optional" do
      @checker.options[:device] = ""
      @checker.should be_valid
    end

    it "should make sure title is optional" do
      @checker.options[:title] = ""
      @checker.should be_valid
    end

    it "should make sure url is optional" do
      @checker.options[:url] = ""
      @checker.should be_valid
    end

    it "should make sure url_title is optional" do
      @checker.options[:url_title] = ""
      @checker.should be_valid
    end

    it "should make sure priority is optional" do
      @checker.options[:priority] = ""
      @checker.should be_valid
    end

    it "should make sure timestamp is optional" do
      @checker.options[:timestamp] = ""
      @checker.should be_valid
    end

    it "should make sure sound is optional" do
      @checker.options[:sound] = ""
      @checker.should be_valid
    end
  end
end
