require 'spec_helper'

describe Agents::WebsiteAgent do
  before do
    stub_request(:any, /xkcd/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/xkcd.html")), :status => 200)
    @site = {
        :name => "XKCD",
        :expected_update_period_in_days => 2,
        :url => "http://xkcd.com",
        :mode => :on_change,
        :extract => {
            :url => {:css => "#comic img", :attr => "src"},
            :title => {:css => "#comic img", :attr => "title"}
        }
    }
    @checker = Agents::WebsiteAgent.new(:name => "xkcd", :options => @site)
    @checker.user = users(:bob)
    @checker.save!
  end

  describe "#check" do
    it "should check for changes" do
      lambda { @checker.check }.should change { Event.count }.by(1)
      lambda { @checker.check }.should_not change { Event.count }
    end

    it "should always save events when in :all mode" do
      lambda {
        @site[:mode] = :all
        @checker.options = @site
        @checker.check
        @checker.check
      }.should change { Event.count }.by(2)
    end

    it "should log an error if the number of results for a set of extraction patterns differs" do
      lambda {
        @site[:extract][:url][:css] = "div"
        @checker.options = @site
        @checker.check
      }.should raise_error(StandardError, /Got an uneven number of matches/)
    end
  end
end