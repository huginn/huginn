require 'spec_helper'

describe Agents::TwitterSearchAgent do
  before do
    # intercept the twitter API request
    stub_request(:any, /freebandnames/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/search_tweets.json")), :status => 200)

    @opts = {
      :search => "freebandnames",
      :expected_update_period_in_days => "2",
      :starting_at => "Jan 01 00:00:01 +0000 2000",
      :consumer_key => "---",
      :consumer_secret => "---",
      :oauth_token => "---",
      :oauth_token_secret => "---"
    }

    @checker = Agents::TwitterSearchAgent.new(:name => "search freebandnames", :options => @opts)
    @checker.service = services(:generic)
    @checker.user = users(:bob)
    @checker.save!
  end

  describe "#check" do
    it "should check for changes" do
      expect { @checker.check }.to change { Event.count }.by(100)
    end
  end

  describe "#check with starting_at=future date" do
    it "should check for changes starting_at a future date, thus not find any" do
      opts = @opts.merge({ :starting_at => "Jan 01 00:00:01 +0000 2999" })

      checker = Agents::TwitterSearchAgent.new(:name => "searching freebandnames", :options => opts)
      checker.service = services(:generic)
      checker.user = users(:bob)
      checker.save!

      expect { checker.check }.to change { Event.count }.by(0)
    end
  end

end
