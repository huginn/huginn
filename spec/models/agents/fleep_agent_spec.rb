require 'rails_helper'

describe Agents::FleepAgent do
  before do
    @checker = Agents::FleepAgent.new(:name => "something",
      :options => {
          :fleep_conversation_webhook_url => "https://fleep.io/somekey",
          :user => 'Huginn',
          :message => 'Hello!'
      })
    @checker.user = users(:bob)
    @checker.save!
  end

  describe "#receive" do
    it "immediately sends any payloads it receives" do
      fleep_conversation_webhook_url = @checker.options[:fleep_conversation_webhook_url]

      event1 = Event.new
      event1.agent = agents(:bob_rain_notifier_agent)
      event1.payload = { :message => "hi!", :data => "Something you should know about" }
      event1.save!

      stub_request(:post, fleep_conversation_webhook_url)

      Agents::FleepAgent.async_receive(@checker.id, [event1.id])
      assert_requested(:post, fleep_conversation_webhook_url, times: 1) {|req| req.body == "user=Huginn&message=Hello%21"}
    end
  end
end
