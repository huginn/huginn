require 'spec_helper'

describe Agents::TwitterUserAgent do
  before do
    # intercept the twitter API request for @tectonic's user profile
    stub_request(:any, /tectonic/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/user_tweets.json")), :status => 200)
  
    @opts = {
      :username => "tectonic",
      :expected_update_period_in_days => "2",
      :consumer_key => "---",
      :consumer_secret => "---",
      :oauth_token => "---",
      :oauth_token_secret => "---"
    }

    @checker = Agents::TwitterUserAgent.new(:name => "tectonic", :options => @opts)
    @checker.user = users(:bob)
    @checker.save!
  end

  describe "#check" do
    it "should check for changes" do
      lambda { @checker.check }.should change { Event.count }.by(5)
    end
  end

end