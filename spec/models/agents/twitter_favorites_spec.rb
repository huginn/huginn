require 'rails_helper'

describe Agents::TwitterFavorites do
  before do
    stub_request(:any, /tectonic/).to_return(body: File.read(Rails.root.join("spec/data_fixtures/user_fav_tweets.json")), status: 200)
  end

  before do
    @opts = {:username => "tectonic", :number => "10", :history => "100", :expected_update_period_in_days => "2", :starting_at => "Sat Feb 20 01:32:08 +0000 2016"}

    @agent = Agents::TwitterFavorites.new(name: "tectonic", options: @opts)
    @agent.service = services(:generic)
    @agent.events.new(payload: JSON.parse(File.read(Rails.root.join("spec/data_fixtures/one_fav_tweet.json"))))
    @agent.user = users(:bob)
    @agent.save!

    @event = Event.new
    @event.agent = agents(:tectonic_twitter_user_agent)
    @event.payload = JSON.parse(File.read(Rails.root.join("spec/data_fixtures/one_fav_tweet.json")))
    @event.save!
  end

  describe "making sure agent last event payload is equivalent to event payload" do
    it "expect change method to change event" do
      expect(@agent.events.last.payload).to eq(@event.payload)
    end
  end

  describe "making sure check method works" do
    it "expect change method to change event" do
      expect { @agent.check }.to change {Event.count}.by(3)
    end
  end

  describe "#check with starting_at=future date" do
    it "should check for changes starting_at a future date, thus not find any" do
      opts = @opts.merge({ starting_at: "Thurs Feb 23 16:12:04 +0000 2017" })

      @agent1 = Agents::TwitterFavorites.new(name: "tectonic", options: opts)
      @agent1.service = services(:generic)
      @agent1.user = users(:bob)
      @agent1.save!

      expect { @agent1.check }.to change { Event.count }.by(0)
    end
  end
end