require 'spec_helper'

describe Agents::WebsiteAgent do
  before do
    stub_request(:any, /xkcd/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/xkcd.html")), :status => 200)
    @site = {
        :name => "XKCD",
        :expected_update_period_in_days => 2,
        :type => "html",
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

  describe "parsing" do
    it "parses CSS" do
      @checker.check
      event = Event.last
      event.payload[:url].should == "http://imgs.xkcd.com/comics/evolving.png"
      event.payload[:title].should =~ /^Biologists play reverse/
    end

    it "should turn relative urls to absolute" do
      rel_site = {
        :name => "XKCD",
        :expected_update_period_in_days => 2,
        :type => "html",
        :url => "http://xkcd.com",
        :mode => :on_change,
        :extract => {
            :url => {:css => "#topLeft a", :attr => "href"},
            :title => {:css => "#topLeft a", :text => "true"}
        }
      }
      rel = Agents::WebsiteAgent.new(:name => "xkcd", :options => rel_site)
      rel.user = users(:bob)
      rel.save!
      rel.check
      event = Event.last
      event.payload[:url].should == "http://xkcd.com/about"
    end
        
    describe "JSON" do
      it "works with paths" do
        json = {
            :response => {
                :version => 2,
                :title => "hello!"
            }
        }
        stub_request(:any, /json-site/).to_return(:body => json.to_json, :status => 200)
        site = {
            :name => "Some JSON Response",
            :expected_update_period_in_days => 2,
            :type => "json",
            :url => "http://json-site.com",
            :mode => :on_change,
            :extract => {
                :version => { :path => "response.version" },
                :title => { :path => "response.title" }
            }
        }
        checker = Agents::WebsiteAgent.new(:name => "Weather Site", :options => site)
        checker.user = users(:bob)
        checker.save!

        checker.check
        event = Event.last
        event.payload[:version].should == 2
        event.payload[:title].should == "hello!"
      end

      it "can handle arrays" do
        json = {
            :response => {
                :data => [
                    { :title => "first", :version => 2 },
                    { :title => "second", :version => 2.5 }
                ]
            }
        }
        stub_request(:any, /json-site/).to_return(:body => json.to_json, :status => 200)
        site = {
            :name => "Some JSON Response",
            :expected_update_period_in_days => 2,
            :type => "json",
            :url => "http://json-site.com",
            :mode => :on_change,
            :extract => {
                :title => { :path => "response.data[*].title" },
                :version => { :path => "response.data[*].version" }
            }
        }
        checker = Agents::WebsiteAgent.new(:name => "Weather Site", :options => site)
        checker.user = users(:bob)
        checker.save!

        lambda {
          checker.check
        }.should change { Event.count }.by(2)

        event = Event.all[-1]
        event.payload[:version].should == 2.5
        event.payload[:title].should == "second"

        event = Event.all[-2]
        event.payload[:version].should == 2
        event.payload[:title].should == "first"
      end
    end
  end
end
