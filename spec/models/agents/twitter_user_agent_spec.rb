require 'rails_helper'

describe Agents::TwitterUserAgent do
  before do
    # intercept the twitter API request for @tectonic's user profile
    stub_request(:any, "https://api.twitter.com/1.1/statuses/home_timeline.json?contributor_details=true&count=200&exclude_replies=false&include_entities=true&include_rts=true").to_return(:body => File.read(Rails.root.join("spec/data_fixtures/user_tweets.json")), :status => 200)

    @opts = {
      #:username => "tectonic",
      :include_retweets => "true",
      :exclude_replies => "false",
      :expected_update_period_in_days => "2",
      :starting_at => "Jan 01 00:00:01 +0000 2000",
      :consumer_key => "---",
      :consumer_secret => "---",
      :oauth_token => "---",
      :oauth_token_secret => "---",
      :choose_home_time_line => 'true'
    }

    @checker = Agents::TwitterUserAgent.new(:name => "tectonic", :options => @opts)
    @checker.service = services(:generic)
    @checker.user = users(:bob)
    @checker.save!
  end

  describe "#check" do
    it "should check for changes" do
      expect { @checker.check }.to change { Event.count }.by(5)
    end
  end

  describe "#check with starting_at=future date" do
    it "should check for changes starting_at a future date, thus not find any" do
      opts = @opts.merge({ :starting_at => "Jan 01 00:00:01 +0000 2999", })

      checker = Agents::TwitterUserAgent.new(:name => "tectonic", :options => opts)
      checker.service = services(:generic)
      checker.user = users(:bob)
      checker.save!

      expect { checker.check }.to change { Event.count }.by(0)
    end
  end

  describe "#check that if choose time line is false then username is required" do
    before do
      #stub_request(:any, '/tectonic/').to_return(:body => File.read(Rails.root.join("spec/data_fixtures/user_tweets.json")), :status => 200)
      stub_request(:any, "https://api.twitter.com/1.1/statuses/user_timeline.json?contributor_details=true&count=200&exclude_replies=false&include_entities=true&include_rts=true").to_return(:body => File.read(Rails.root.join("spec/data_fixtures/user_tweets.json")), :status => 200)
    end

    it "should check that error messaged added if choose time line is false" do
      
      opts = @opts.merge!({:choose_home_time_line => "false" })

      checker = Agents::TwitterUserAgent.new(:name => "tectonic", :options => opts)
      checker.service = services(:generic)
      checker.user = users(:bob)
      expect(checker.save).to eq (checker.errors.messages[:base] == "username is required" )
    end
  end
end
