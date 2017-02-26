require 'rails_helper'

describe Agents::PushsaferAgent do
  before do
    @checker = Agents::PushsaferAgent.new(name: 'Some Name',
                                         options: {
                                           k: 'x',
                                           m: "{{ m | default: text | default: 'Some Message' }}",
                                           d: "{{ d | default: 'Some Device ID' }}",
                                           t: "{{ t | default: 'Some Message Title' }}",
                                           u: "{{ u | default: 'http://someurl.com' }}",
                                           ut: "{{ ut | default: 'Some Url Title' }}",
                                           s: "{{ s | default: '1' }}",
										   i: "{{ i | default: '1' }}",
										   v: "{{ v | default: '0' }}",
										   l: "{{ l | default: '0' }}",
                                           expected_receive_period_in_days: '1'
                                         })

    @checker.user = users(:bob)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { m: 'Looks like its going to rain' }
    @event.save!

    @sent_notifications = []
    stub.any_instance_of(Agents::PushsaferAgent).send_notification  { |notification| @sent_notifications << notification}
  end

  describe '#receive' do
    it 'should make sure multiple events are being received' do
      event1 = Event.new
      event1.agent = agents(:bob_rain_notifier_agent)
      event1.payload = { m: 'Some message' }
      event1.save!

      event2 = Event.new
      event2.agent = agents(:bob_weather_agent)
      event2.payload = { m: 'Some other message' }
      event2.save!

      @checker.receive([@event,event1,event2])
      expect(@sent_notifications[0]['m']).to eq('Looks like its going to rain')
      expect(@sent_notifications[1]['m']).to eq('Some message')
      expect(@sent_notifications[2]['m']).to eq('Some other message')
    end

    it 'should make sure event message overrides default message' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { m: 'Some new message'}
      event.save!

      @checker.receive([event])
      expect(@sent_notifications[0]['m']).to eq('Some new message')
    end

    it 'should make sure event text overrides default message' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { text: 'Some new text'}
      event.save!

      @checker.receive([event])
      expect(@sent_notifications[0]['m']).to eq('Some new text')
    end

    it 'should make sure event title overrides default title' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { m: 'Some message', t: 'Some new title' }
      event.save!

      @checker.receive([event])
      expect(@sent_notifications[0]['title']).to eq('Some new title')
    end

    it 'should make sure event url overrides default url' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { m: 'Some message', u: 'Some new url' }
      event.save!

      @checker.receive([event])
      expect(@sent_notifications[0]['u']).to eq('Some new url')
    end

    it 'should make sure event url_title overrides default url_title' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { m: 'Some message', ut: 'Some new url_title' }
      event.save!

      @checker.receive([event])
      expect(@sent_notifications[0]['ut']).to eq('Some new url_title')
    end

    it 'should make sure event sound overrides default sound' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { m: 'Some message', s: 'Some new sound' }
      event.save!

      @checker.receive([event])
      expect(@sent_notifications[0]['s']).to eq('Some new sound')
    end
	
    it 'should make sure event icon overrides default icon' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { m: 'Some message', i: 'Some new icon' }
      event.save!

      @checker.receive([event])
      expect(@sent_notifications[0]['i']).to eq('Some new icon')
    end	
	
    it 'should make sure event vibration overrides default vibration' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { m: 'Some message', v: 'Some new vibration' }
      event.save!

      @checker.receive([event])
      expect(@sent_notifications[0]['v']).to eq('Some new vibration')
    end	

	it 'should make sure event time2live overrides default time2live' do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { m: 'Some message', l: 'Some new time2live' }
      event.save!

      @checker.receive([event])
      expect(@sent_notifications[0]['l']).to eq('Some new time2live')
    end	

  end

  describe '#working?' do
    it 'checks if events have been received within the expected receive period' do
      # No events received
      expect(@checker).not_to be_working
      Agents::PushsaferAgent.async_receive @checker.id, [@event.id]

      # Just received events
      expect(@checker.reload).to be_working
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }

      # More time has passed than the expected receive period without any new events
      expect(@checker.reload).not_to be_working
    end
  end

  describe "validation" do
    before do
      expect(@checker).to be_valid
    end

    it "should validate presence of privatekey" do
      @checker.options[:privatekey] = ""
      expect(@checker).not_to be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      @checker.options[:expected_receive_period_in_days] = ""
      expect(@checker).not_to be_valid
    end

    it "should make sure device is optional" do
      @checker.options[:d] = ""
      expect(@checker).to be_valid
    end

    it "should make sure title is optional" do
      @checker.options[:t] = ""
      expect(@checker).to be_valid
    end

    it "should make sure url is optional" do
      @checker.options[:u] = ""
      expect(@checker).to be_valid
    end

    it "should make sure url_title is optional" do
      @checker.options[:ut] = ""
      expect(@checker).to be_valid
    end

    it "should make sure sound is optional" do
      @checker.options[:s] = ""
      expect(@checker).to be_valid
    end
	
    it "should make sure icon is optional" do
      @checker.options[:i] = ""
      expect(@checker).to be_valid
    end

    it "should make sure vibration is optional" do
      @checker.options[:v] = ""
      expect(@checker).to be_valid
    end
	
    it "should make sure time2live is optional" do
      @checker.options[:l] = ""
      expect(@checker).to be_valid
    end	
  end
end
