require 'rails_helper'

describe Agents::TwitterUserAgent do
  before do
    # intercept the twitter API request for @tectonic's user profile
    stub_request(:any, "https://api.twitter.com/1.1/statuses/user_timeline.json?contributor_details=true&count=200&exclude_replies=false&include_entities=true&include_rts=true&screen_name=tectonic&tweet_mode=extended").
      to_return(body: File.read(Rails.root.join("spec/data_fixtures/user_tweets.json")),
                headers: { 'Content-Type': 'application/json;charset=utf-8' },
                status: 200)

    @opts = {
      :username => "tectonic",
      :include_retweets => "true",
      :exclude_replies => "false",
      :expected_update_period_in_days => "2",
      :starting_at => "Jan 01 00:00:01 +0000 2000",
      :consumer_key => "---",
      :consumer_secret => "---",
      :oauth_token => "---",
      :oauth_token_secret => "---"
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
      stub_request(:any, "https://api.twitter.com/1.1/statuses/home_timeline.json?contributor_details=true&count=200&exclude_replies=false&include_entities=true&include_rts=true&tweet_mode=extended").to_return(:body => File.read(Rails.root.join("spec/data_fixtures/user_tweets.json")), :status => 200)
    end

    it 'requires username unless choose_home_time_line is true' do
      expect(@checker).to be_valid

      @checker.options['username'] = nil
      expect(@checker).to_not be_valid

      @checker.options['choose_home_time_line'] = 'true'
      expect(@checker).to be_valid
    end

    context "when choose_home_time_line is true" do
      before do
        @checker.options['choose_home_time_line'] = true
        @checker.options.delete('username')
        @checker.save!
      end
    end

    it "error messaged added if choose_home_time_line is false and username does not exist" do

      opts = @opts.tap { |o| o.delete(:username) }.merge!({:choose_home_time_line => "false" })

      checker = Agents::TwitterUserAgent.new(:name => "tectonic", :options => opts)
      checker.service = services(:generic)
      checker.user = users(:bob)
      expect(checker.save).to eq false
      expect(checker.errors.full_messages.first).to eq("username is required")
    end
  end
end
