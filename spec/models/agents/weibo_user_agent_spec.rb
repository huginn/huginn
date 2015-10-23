# encoding: utf-8 
require 'rails_helper'

describe Agents::WeiboUserAgent do
  before do
    # intercept the twitter API request for @tectonic's user profile
    stub_request(:any, /api.weibo.com/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/one_weibo.json")), :status => 200)
  
    @opts = {
      :uid => "123456",
      :expected_update_period_in_days => "2",
      :app_key => "asdfe",
      :app_secret => "asdfe",
      :access_token => "asdfe"
    }

    @checker = Agents::WeiboUserAgent.new(:name => "123456 fetcher", :options => @opts)
    @checker.user = users(:bob)
    @checker.save!
  end

  describe "#check" do
    it "should check for changes" do
      expect { @checker.check }.to change { Event.count }.by(1)
    end
  end

end
