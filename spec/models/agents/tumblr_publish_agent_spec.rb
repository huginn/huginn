require 'rails_helper'

describe Agents::TumblrPublishAgent do
  describe "Should create post" do
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

      @post_body = {
        "id" => 5,
        "title" => "Gonna rain...",
        "link" => "http://huginnbot.tumblr.com/gonna-rain..."
      }
      stub.any_instance_of(Agents::TumblrPublishAgent).tumblr {
        obj = Object.new
        stub(obj).text(anything, anything) { { "id" => "5" } }
        stub(obj).posts("huginnbot.tumblr.com", {:id => "5"}) {
          {"posts" => [@post_body]}
        }
      }

    end

    describe '#receive' do
      it 'should publish any payload it receives' do
        Agents::TumblrPublishAgent.async_receive(@checker.id, [@event.id])
        expect(@checker.events.count).to eq(1)
        expect(@checker.events.first.payload['post_id']).to eq('5')
        expect(@checker.events.first.payload['published_post']).to eq('[huginnbot.tumblr.com] text')
        expect(@checker.events.first.payload["post"]).to eq @post_body
      end
    end
  end

  describe "Should handle tumblr error" do
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
        stub!.text(anything, anything) { {"status" => 401,"msg" => "Not Authorized"} }
      }
    end

    describe '#receive' do
      it 'should publish any payload it receives and handle error' do
        Agents::TumblrPublishAgent.async_receive(@checker.id, [@event.id])
        expect(@checker.events.count).to eq(0)
      end
    end
  end
end
