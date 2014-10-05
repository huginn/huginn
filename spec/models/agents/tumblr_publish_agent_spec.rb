require 'spec_helper'

describe Agents::TumblrPublishAgent do
  before do
    @opts = {
      :blog_name => "huginnbot.tumblr.com",
      :post_type => "text",
      :expected_update_period_in_days => "2",
      :options => {
        :title => "{{title}}",
        :body => "{{body}}",
      },
    }

    @checker = Agents::TumblrPublishAgent.new(:name => "HuginnBot", :options => @opts)
    @checker.service = services(:generic)
    @checker.user = users(:bob)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :title => "Gonna rain...", :body => 'San Francisco is gonna get wet' }
    @event.save!

    stub.any_instance_of(Agents::TumblrPublishAgent).tumblr {
      stub!.text(anything, anything) { { "id" => "5" } }
    }
  end

  describe '#receive' do
    it 'should publish any payload it receives' do
      Agents::TumblrPublishAgent.async_receive(@checker.id, [@event.id])
      expect(@checker.events.count).to eq(1)
      expect(@checker.events.first.payload['post_id']).to eq('5')
      expect(@checker.events.first.payload['published_post']).to eq('[huginnbot.tumblr.com] text')
    end
  end
end
