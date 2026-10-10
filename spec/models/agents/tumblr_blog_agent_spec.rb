require 'spec_helper'

describe Agents::TumblrBlogAgent do
  before do
    @opts = {
      :blog_name => "huginnbot.tumblr.com",
      :expected_update_period_in_days => "2",
    }

    @agent = Agents::TumblrBlogAgent.new(:name => "HuginnBot", :options => @opts)
    @agent.service = services(:generic)
    @agent.user = users(:bob)
    @agent.save!

    @result = { "posts" => [ { "id" => 5 }, { "id" => 4 }, { "id" => 3 } ] }

    stub.any_instance_of(Agents::TumblrBlogAgent).tumblr {
      stub!.posts(anything) { @result }
    }
  end

  describe '#check' do
    it 'should publish any payload it receives initially' do
      @agent.check
      @agent.events.count.should eq(3)
      @agent.events.first.payload['id'].should eq(5)
      @agent.memory['since_id'].should == 5
    end

    it 'should not publish previously-seen posts' do
      @agent.check
      @agent.events.count.should eq(3)
      @agent.events.first.payload['id'].should eq(5)
    end

    it 'should only publish new posts' do
      @result["posts"].unshift( { "id" => 6 } )

      @agent.check
      @agent.events.count.should eq(4)
      @agent.events.first.payload['id'].should eq(6)
    end
  end
end
