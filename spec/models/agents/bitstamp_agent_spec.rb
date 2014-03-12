require 'spec_helper'

describe Agents::BitstampAgent do
  before do
    # intercept the twitter API request for @tectonic's user profile
    stub_request(:any, /ticker/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/bitstamp.json")), :status => 200)

    @checker = Agents::BitstampAgent.new(:name => "somename")
    @checker.user = users(:bob)
    @checker.save!
  end

  describe "#check" do
    it "should check for changes" do
      lambda { @checker.check }.should change { Event.count }.by(1)
    end
  end

  describe "#working?" do
    it "checks if its generating events as scheduled" do
      @checker.should_not be_working
      @checker.check
      @checker.reload.should be_working
      three_days_from_now = 3.days.from_now
      stub(Time).now { three_days_from_now }
      @checker.should_not be_working
    end
  end
end
