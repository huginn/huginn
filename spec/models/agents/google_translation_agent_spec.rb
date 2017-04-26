require 'rails_helper'

describe Agents::GoogleTranslationAgent, :vcr do
  before do
    @valid_params = {
      name: "somename",
      options: {
        to: "sv",
        from: "en",
        google_api_key: 'some_api_key',
        expected_receive_period_in_days: 1,
        content: {
          text: "{{message}}",
          content: "{{xyz}}"
        }
      }
    }

    @checker = Agents::GoogleTranslationAgent.new(@valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:jane_weather_agent)
    @event.payload = {
      message: "hey what are you doing",
      xyz: "do tell more"
    }

  end

  describe "#receive" do
    it "checks if it can handle multiple events" do
      event1 = Event.new
      event1.agent = agents(:bob_weather_agent)
      event1.payload = {
        xyz: "value1",
        message: "value2"
      }

      expect {
        @checker.receive([@event,event1])
      }.to change { Event.count }.by(2)
    end
  end

  describe "#working?" do
    it "checks if events have been received within expected receive period" do
      expect(@checker).not_to be_working
      Agents::GoogleTranslationAgent.async_receive @checker.id, [@event.id]
      expect(@checker.reload).to be_working
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(@checker.reload).not_to be_working
    end
  end

  describe "validation" do
    before do
      expect(@checker).to be_valid
    end

    it "should validate presence of content key" do
      @checker.options[:content] = nil
      expect(@checker).not_to be_valid
    end

    it "should validate presence of expected_receive_period_in_days key" do
      @checker.options[:expected_receive_period_in_days] = nil
      expect(@checker).not_to be_valid
    end

    it "should validate presence of google_api_key" do
      @checker.options[:google_api_key] = nil
      expect(@checker).not_to be_valid
    end

    it "should validate presence of 'to' key" do
      @checker.options[:to] = ""
      expect(@checker).not_to be_valid
    end
  end
end
