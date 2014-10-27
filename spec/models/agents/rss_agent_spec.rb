require 'spec_helper'

describe Agents::RssAgent do
  before do
    @valid_options = {
      'expected_update_period_in_days' => "2",
      'url' => "https://github.com/cantino/huginn/commits/master.atom",
    }

    stub_request(:any, /github.com/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/github_rss.atom")), :status => 200)
    stub_request(:any, /SlickdealsnetFP/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/slickdeals.atom")), :status => 200)
  end

  let(:agent) do
    _agent = Agents::RssAgent.new(:name => "rss feed", :options => @valid_options)
    _agent.user = users(:bob)
    _agent.save!
    _agent
  end

  it_behaves_like WebRequestConcern

  describe "validations" do
    it "should validate the presence of url" do
      agent.options['url'] = "http://google.com"
      expect(agent).to be_valid

      agent.options['url'] = ""
      expect(agent).not_to be_valid

      agent.options['url'] = nil
      expect(agent).not_to be_valid
    end

    it "should validate the presence and numericality of expected_update_period_in_days" do
      agent.options['expected_update_period_in_days'] = "5"
      expect(agent).to be_valid

      agent.options['expected_update_period_in_days'] = "wut?"
      expect(agent).not_to be_valid

      agent.options['expected_update_period_in_days'] = 0
      expect(agent).not_to be_valid

      agent.options['expected_update_period_in_days'] = nil
      expect(agent).not_to be_valid

      agent.options['expected_update_period_in_days'] = ""
      expect(agent).not_to be_valid
    end
  end

  describe "emitting RSS events" do
    it "should emit items as events" do
      expect {
        agent.check
      }.to change { agent.events.count }.by(20)

      event = agent.events.last
      expect(event.payload['url']).to eq("https://github.com/cantino/huginn/commit/d0a844662846cf3c83b94c637c1803f03db5a5b0")
      expect(event.payload['urls']).to eq(["https://github.com/cantino/huginn/commit/d0a844662846cf3c83b94c637c1803f03db5a5b0"])
    end

    it "should track ids and not re-emit the same item when seen again" do
      agent.check
      expect(agent.memory['seen_ids']).to eq(agent.events.map {|e| e.payload['id'] })

      newest_id = agent.memory['seen_ids'][0]
      expect(agent.events.first.payload['id']).to eq(newest_id)
      agent.memory['seen_ids'] = agent.memory['seen_ids'][1..-1] # forget the newest id

      expect {
        agent.check
      }.to change { agent.events.count }.by(1)

      expect(agent.events.first.payload['id']).to eq(newest_id)
      expect(agent.memory['seen_ids'][0]).to eq(newest_id)
    end

    it "should truncate the seen_ids in memory at 500 items" do
      agent.memory['seen_ids'] = ['x'] * 490
      agent.check
      expect(agent.memory['seen_ids'].length).to eq(500)
    end
  end

  context "when no ids are available" do
    before do
      @valid_options['url'] = 'http://feeds.feedburner.com/SlickdealsnetFP?format=atom'
    end

    it "calculates content MD5 sums" do
      expect {
        agent.check
      }.to change { agent.events.count }.by(79)
      expect(agent.memory['seen_ids']).to eq(agent.events.map {|e| Digest::MD5.hexdigest(e.payload['content']) })
    end
  end
end
