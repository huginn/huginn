require 'rails_helper'

describe Agents::PlivoAgent do
  before do
    @checker = Agents::PlivoAgent.new(:name => 'somename',
                                      :options => { :auth_id => 'x',
                                                    :auth_token => 'x',
                                                    :sender_cell => 'x',
                                                    :receiver_cell => '{{to}}',
                                                    :server_url    => 'http://somename.com:3000',
                                                    :receive_text  => 'true',
                                                    :receive_call  => 'true',
                                                    :expected_receive_period_in_days => '1' })
    @checker.user = users(:bob)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { message: 'Looks like its going to rain', to: 54321 }
    @event.save!

    @messages = []
    @calls = []

    allow(Plivo::RestClient).to receive(:new) do
      instance_double(Plivo::RestClient).tap { |c|
        allow(c).to receive(:calls) do
          double.tap { |l|
            allow(l).to receive(:create) do |*args, **kwargs|
              @calls << (kwargs.empty? ? args : kwargs)
            end
          }
        end
        allow(c).to receive(:messages) do
          double.tap { |l|
            allow(l).to receive(:create) do |*args, **kwargs|
              @messages << (kwargs.empty? ? args.first : kwargs)
            end
          }
        end
      }
    end
  end

  describe '#receive' do
    it 'should make sure multiple events are being received' do
      event1 = Event.new
      event1.agent = agents(:bob_rain_notifier_agent)
      event1.payload = { message: 'Some message', to: 12345 }
      event1.save!

      event2 = Event.new
      event2.agent = agents(:bob_weather_agent)
      event2.payload = { message: 'Some other message', to: 987654 }
      event2.save!

      @checker.receive([@event, event1, event2])
      expect(@messages).to eq [
        { src: "x", dst: "54321", text: "Looks like its going to rain" },
        { src: "x", dst: "12345", text: "Some message" },
        { src: "x", dst: "987654", text: "Some other message" }
      ]
    end

    it 'should check if receive_text is working fine' do
      @checker.options[:receive_text] = 'false'
      @checker.receive([@event])
      expect(@messages).to be_empty
    end

    it 'should check if receive_call is working fine' do
      @checker.options[:receive_call] = 'true'
      @checker.receive([@event])
      expect(@checker.memory[:pending_calls]).not_to eq({})
    end
  end

  describe '#working?' do
    it 'checks if events have been received within the expected receive period' do
      expect(@checker).not_to be_working # No events received
      Agents::PlivoAgent.async_receive @checker.id, [@event.id]
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

    it "accepts boolean receive flags" do
      @checker.options[:receive_text] = false
      @checker.options[:receive_call] = true
      expect(@checker).to be_valid
    end

    it "should validate presence of auth_id" do
      @checker.options[:auth_id] = ""
      expect(@checker).not_to be_valid
    end

    it "should validate presence of auth_token" do
      @checker.options[:auth_token] = ""
      expect(@checker).not_to be_valid
    end

    it "should validate presence of receiver_cell" do
      @checker.options[:receiver_cell] = ""
      expect(@checker).not_to be_valid
    end

    it "should validate presence of sender_cell" do
      @checker.options[:sender_cell] = ""
      expect(@checker).not_to be_valid
    end

    it "should make sure filling server_url is not necessary" do
      @checker.options[:server_url] = ""
      expect(@checker).to be_valid
    end
  end
end
