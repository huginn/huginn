require 'rails_helper'

describe Agents::GrowlAgent do
  before do
    @checker = Agents::GrowlAgent.new(:name => 'a growl agent',
                                      :options => { :growl_server => 'localhost',
                                                    :growl_app_name => 'HuginnGrowlApp',
                                                    :growl_password => 'mypassword',
                                                    :growl_notification_name => 'Notification',
                                                    expected_receive_period_in_days: '1' ,
                                                    message: '{{message}}',
                                                    subject: '{{subject}}'})
    @checker.user = users(:bob)
    @checker.save!

    allow_any_instance_of(Growl::GNTP).to receive(:notify)

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :subject => 'Weather Alert!', :message => 'Looks like its going to rain' }
    @event.save!
  end

  describe "#working?" do
    it "checks if events have been received within the expected receive period" do
      expect(@checker).not_to be_working # No events received
      Agents::GrowlAgent.async_receive @checker.id, [@event.id]
      expect(@checker.reload).to be_working # Just received events
      two_days_from_now = 2.days.from_now
      allow(Time).to receive(:now) { two_days_from_now }
      expect(@checker.reload).not_to be_working # More time has passed than the expected receive period without any new events
    end
  end

  describe "validation" do
    before do
      expect(@checker).to be_valid
    end

    it "should validate presence of of growl_server" do
      @checker.options[:growl_server] = ""
      expect(@checker).not_to be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      @checker.options[:expected_receive_period_in_days] = ""
      expect(@checker).not_to be_valid
    end
  end

  describe "register_growl" do
    it "should set the password for the Growl connection from the agent options" do
      @checker.register_growl
      expect(@checker.growler.password).to eql(@checker.options[:growl_password])
    end

    it "should add a notification to the Growl connection" do
      expect(Growl::GNTP).to receive(:new).and_wrap_original do |orig, *args|
        orig.call(*args).tap { |obj|
          expect(obj).to receive(:add_notification).with(@checker.options[:growl_notification_name])
        }
      end
      @checker.register_growl
    end
  end

  describe "notify_growl" do
    it "should call Growl.notify with the correct notification name, subject, and message" do
      message = "message"
      subject = "subject"
      expect(Growl::GNTP).to receive(:new).and_wrap_original do |orig, *args|
        orig.call(*args).tap { |obj|
          expect(obj).to receive(:notify).with(@checker.options[:growl_notification_name], subject, message, 0, false, nil, '')
        }
      end
      @checker.register_growl
      @checker.notify_growl(subject: subject, message: message, sticky: false, priority: 0, callback_url: '')
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

    it "should call register_growl once per received event" do
      events = generate_events_array
      expect(@checker).to receive(:register_growl).exactly(events.length).times.and_call_original
      @checker.receive(events)
    end

    it "should call notify_growl one time for each event received" do
      events = generate_events_array
      events.each do |event|
        expect(@checker).to receive(:notify_growl).with(subject: event.payload['subject'], message: event.payload['message'], priority: 0, sticky: false, callback_url: nil)
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

      expect(@checker).not_to receive(:notify_growl)
      @checker.receive([event_without_a_subject,event_without_a_message])
    end
  end
end
