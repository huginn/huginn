require 'spec_helper'

describe Agents::RssAgent do
  before do
    @valid_options = {
      'expected_update_period_in_days' => "2",
      'url' => "https://github.com/cantino/huginn/commits/master.atom",
    }

    stub_request(:any, /github.com/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/github_rss.atom")), :status => 200)
  end

  let(:agent) do
    _agent = Agents::RssAgent.new(:name => "github rss feed", :options => @valid_options)
    _agent.user = users(:bob)
    _agent.save!
    _agent
  end

  it_behaves_like WebRequestConcern

  describe "validations" do
    it "should validate the presence of url" do
      agent.options['url'] = "http://google.com"
      agent.should be_valid

      agent.options['url'] = ""
      agent.should_not be_valid

      agent.options['url'] = nil
      agent.should_not be_valid
    end

    it "should validate the presence and numericality of expected_update_period_in_days" do
      agent.options['expected_update_period_in_days'] = "5"
      agent.should be_valid

      agent.options['expected_update_period_in_days'] = "wut?"
      agent.should_not be_valid

      agent.options['expected_update_period_in_days'] = 0
      agent.should_not be_valid

      agent.options['expected_update_period_in_days'] = nil
      agent.should_not be_valid

      agent.options['expected_update_period_in_days'] = ""
      agent.should_not be_valid
    end
  end

  describe "emitting RSS events" do
    it "should emit items as events" do
      lambda {
        agent.check
      }.should change { agent.events.count }.by(20)
    end

    it "should track ids and not re-emit the same item when seen again" do
      agent.check
      agent.memory['seen_ids'].should == agent.events.map {|e| e.payload['id'] }

      newest_id = agent.memory['seen_ids'][0]
      agent.events.first.payload['id'].should == newest_id
      agent.memory['seen_ids'] = agent.memory['seen_ids'][1..-1] # forget the newest id

      lambda {
        agent.check
      }.should change { agent.events.count }.by(1)

      agent.events.first.payload['id'].should == newest_id
      agent.memory['seen_ids'][0].should == newest_id
    end

    it "should truncate the seen_ids in memory at 500 items" do
      agent.memory['seen_ids'] = ['x'] * 490
      agent.check
      agent.memory['seen_ids'].length.should == 500
    end
  end
end
