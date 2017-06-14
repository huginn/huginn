require 'rails_helper'

describe Agents::TwitterSearchAgent do
  before do
    # intercept the twitter API request
    stub_request(:any, /freebandnames.*[?&]tweet_mode=extended/).
      to_return(body: File.read(Rails.root.join("spec/data_fixtures/search_tweets.json")),
                headers: { 'Content-Type': 'application/json;charset=utf-8' },
                status: 200)

    @opts = {
      search: "freebandnames",
      expected_update_period_in_days: "2",
      starting_at: "Jan 01 00:00:01 +0000 2000",
      max_results: '3'
    }

  end
  let(:checker) {
    _checker = Agents::TwitterSearchAgent.new(name: "search freebandnames", options: @opts)
    _checker.service = services(:generic)
    _checker.user = users(:bob)
    _checker.save!
    _checker
  }

  describe "#check" do
    it "should check for changes" do
      expect { checker.check }.to change { Event.count }.by(3)
    end
  end

  describe "#check with starting_at=future date" do
    it "should check for changes starting_at a future date, thus not find any" do
      opts = @opts.merge({ starting_at: "Jan 01 00:00:01 +0000 2999" })

      checker = Agents::TwitterSearchAgent.new(name: "search freebandnames", options: opts)
      checker.service = services(:generic)
      checker.user = users(:bob)
      checker.save!

      expect { checker.check }.to change { Event.count }.by(0)
    end
  end

end
