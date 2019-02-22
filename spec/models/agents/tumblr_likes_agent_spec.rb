require 'rails_helper'

describe Agents::TumblrLikesAgent do
  before do
    stub.any_instance_of(Agents::TumblrLikesAgent).tumblr {
      obj = Object.new
      stub(obj).blog_likes('wendys.tumblr.com', after: 0) {
        JSON.parse File.read(Rails.root.join('spec/data_fixtures/tumblr_likes.json'))
      }
      stub(obj).blog_likes('notfound.tumblr.com', after: 0) { { 'status' => 404, 'msg' => 'Not Found' } }
    }
  end

  describe 'a blog which returns likes' do
    before do
      @agent = Agents::TumblrLikesAgent.new(name: "Wendy's Tumblr Likes", options: {
        blog_name: 'wendys.tumblr.com',
        expected_update_period_in_days: 10
      })
      @agent.service = services(:generic)
      @agent.user = users(:bob)
      @agent.save!
    end

    it 'creates events based on likes' do
      expect { @agent.check }.to change { Event.count }.by(20)
    end
  end

  describe 'a blog which returns an error' do
    before do
      @broken_agent = Agents::TumblrLikesAgent.new(name: "Fake Blog Likes", options: {
        blog_name: 'notfound.tumblr.com',
        expected_update_period_in_days: 10
      })
      @broken_agent.user = users(:bob)
      @broken_agent.service = services(:generic)
      @broken_agent.save!
    end

    it 'creates an error message when status and msg are returned instead of liked_posts' do
      expect { @broken_agent.check }.to change { @broken_agent.logs.count }.by(1)
    end
  end
end
