require 'rails_helper'

describe Agents::SlackAgent do
  before(:each) do
    @fallback = "Its going to rain"
    @attachments = [{'fallback' => "{{fallback}}"}]
    @valid_params = {
                      'webhook_url' => 'https://hooks.slack.com/services/random1/random2/token',
                      'channel' => '#random',
                      'username' => "{{username}}",
                      'message' => "{{message}}",
                      'attachments' => @attachments
                    }

    @checker = Agents::SlackAgent.new(:name => "slacker", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :channel => '#random', :message => 'Looks like its going to rain', username: "Huggin user", fallback: @fallback}
    @event.save!
  end

  describe "validating" do
    before do
      expect(@checker).to be_valid
    end

    it "should require a webhook_url" do
      @checker.options['webhook_url'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require a channel" do
      @checker.options['channel'] = nil
      expect(@checker).not_to be_valid
    end

    it "should allow an icon" do
      @checker.options['icon_emoji'] = nil
      expect(@checker).to be_valid
      @checker.options['icon_emoji'] = ":something:"
      expect(@checker).to be_valid
      @checker.options['icon_url'] = "http://something.com/image.png"
      expect(@checker).to be_valid
      @checker.options['icon_emoji'] = "something"
      expect(@checker).to be_valid
    end

    it "should allow attachments" do
      @checker.options['attachments'] = nil
      expect(@checker).to be_valid
      @checker.options['attachments'] = []
      expect(@checker).to be_valid
      @checker.options['attachments'] = @attachments
      expect(@checker).to be_valid
    end
  end

  describe "#receive" do
    it "receive an event without errors" do
      expect_any_instance_of(Slack::Notifier).to receive(:ping).with(@event.payload[:message],
                       attachments: [{'fallback' => @fallback}],
                       channel: @event.payload[:channel],
                       username: @event.payload[:username]
                      )

      expect { @checker.receive([@event]) }.not_to raise_error
    end

    it "sends notifications through OUTBOUND_PROXY when configured" do
      allow(OutboundProxy).to receive(:url).and_return("https://proxy.example:3128")
      http = Net::HTTP.new("hooks.slack.com", 443)
      allow(Net::HTTP).to receive(:new).with("hooks.slack.com", 443).and_return(http)
      expect(http).to receive(:proxy_use_ssl=).with(true).and_call_original

      expect(http).to receive(:request) do |request|
        expect(request).to be_a(Net::HTTP::Post)
        expect(http).not_to be_proxy_from_env
        expect(http.proxy_address).to eq("proxy.example")
        expect(http.proxy_port).to eq(3128)
        expect(http.use_ssl?).to be(true)
        Net::HTTPOK.new("1.1", "200", "OK")
      end

      @checker.receive([@event])
    end
  end

  describe "#working?" do
    it "should call received_event_without_error?" do
      expect(@checker).to receive(:received_event_without_error?)
      @checker.working?
    end
  end
end
