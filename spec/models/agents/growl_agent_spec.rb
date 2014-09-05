require 'spec_helper'

describe Agents::GrowlAgent do
  before do
    @checker = Agents::GrowlAgent.new(:name => 'a growl agent',
                                      :options => { :growl_server => 'localhost',
                                                    :growl_app_name => 'HuginnGrowlApp',
                                                    :growl_password => 'mypassword',
                                                    :growl_notification_name => 'Notification',
                                                    :expected_receive_period_in_days => '1' })
    @checker.user = users(:bob)
    @checker.save!
    
    stub.any_instance_of(Growl).notify

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :subject => 'Weather Alert!', :message => 'Looks like its going to rain' }
    @event.save!
  end

  describe "#working?" do
    it "checks if events have been received within the expected receive period" do
      @checker.should_not be_working # No events received
      Agents::GrowlAgent.async_receive @checker.id, [@event.id]
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

    it "should validate presence of of growl_server" do
      @checker.options[:growl_server] = ""
      @checker.should_not be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      @checker.options[:expected_receive_period_in_days] = ""
      @checker.should_not be_valid
    end
  end
  
  describe "register_growl" do
    it "should set the password for the Growl connection from the agent options" do
      @checker.register_growl
      @checker.growler.password.should eql(@checker.options[:growl_password])
    end

    it "should add a notification to the Growl connection" do
      called = false
      any_instance_of(Growl) do |obj|
        called = true
        mock(obj).add_notification(@checker.options[:growl_notification_name])
      end
      
      @checker.register_growl
      called.should be_truthy
    end
  end
  
  describe "notify_growl" do
    before do
      @checker.register_growl
    end
    
    it "should call Growl.notify with the correct notification name, subject, and message" do
      message = "message"
      subject = "subject"
      called = false
      any_instance_of(Growl) do |obj|
        called = true
        mock(obj).notify(@checker.options[:growl_notification_name],subject,message)
      end
      @checker.notify_growl(subject,message)
      called.should be_truthy
    end
  end
  
  describe "receive" do
    def generate_events_array
      events = []
      (2..rand(7)).each do
        events << @event
      end
      return events
    end
    
    it "should call register_growl once regardless of number of events received" do
      mock.proxy(@checker).register_growl.once
      @checker.receive(generate_events_array)
    end
    
    it "should call notify_growl one time for each event received" do
      events = generate_events_array
      events.each do |event|
        mock.proxy(@checker).notify_growl(event.payload['subject'], event.payload['message'])
      end
      @checker.receive(events)
    end
    
    it "should not call notify_growl if message or subject are missing" do
      event_without_a_subject = Event.new
      event_without_a_subject.agent = agents(:bob_weather_agent)
      event_without_a_subject.payload = { :message => 'Looks like its going to rain' }
      event_without_a_subject.save!
      
      event_without_a_message = Event.new
      event_without_a_message.agent = agents(:bob_weather_agent)
      event_without_a_message.payload = { :subject => 'Weather Alert YO!' }
      event_without_a_message.save!
      
      mock.proxy(@checker).notify_growl.never
      @checker.receive([event_without_a_subject,event_without_a_message])
    end
  end
end