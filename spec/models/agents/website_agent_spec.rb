require 'spec_helper'

describe Agents::WebsiteAgent do
  describe "checking without basic auth" do
    before do
      stub_request(:any, /xkcd/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/xkcd.html")), :status => 200)
      @site = {
        'name' => "XKCD",
        'expected_update_period_in_days' => 2,
        'type' => "html",
        'url' => "http://xkcd.com",
        'mode' => 'on_change',
        'extract' => {
          'url' => { 'css' => "#comic img", 'attr' => "src" },
          'title' => { 'css' => "#comic img", 'attr' => "alt" },
          'hovertext' => { 'css' => "#comic img", 'attr' => "title" }
        }
      }
      @checker = Agents::WebsiteAgent.new(:name => "xkcd", :options => @site, :keep_events_for => 2)
      @checker.user = users(:bob)
      @checker.save!
    end

    describe "#check" do
      it "should validate the integer fields" do
        @checker.options['expected_update_period_in_days'] = "nonsense"
        lambda { @checker.save! }.should raise_error;
        @checker.options['expected_update_period_in_days'] = "2"
        @checker.options['uniqueness_look_back'] = "nonsense"
        lambda { @checker.save! }.should raise_error;
        @checker.options['mode'] = "nonsense"
        lambda { @checker.save! }.should raise_error;
        @checker.options = @site
      end

      it "should validate the force_encoding option" do
        @checker.options['force_encoding'] = 'UTF-8'
        lambda { @checker.save! }.should_not raise_error;
        @checker.options['force_encoding'] = ['UTF-8']
        lambda { @checker.save! }.should raise_error;
        @checker.options['force_encoding'] = 'UTF-42'
        lambda { @checker.save! }.should raise_error;
        @checker.options = @site
      end

      it "should check for changes (and update Event.expires_at)" do
        lambda { @checker.check }.should change { Event.count }.by(1)
        event = Event.last
        sleep 2
        lambda { @checker.check }.should_not change { Event.count }
        update_event = Event.last
        update_event.expires_at.should_not == event.expires_at
      end

      it "should always save events when in :all mode" do
        lambda {
          @site['mode'] = 'all'
          @checker.options = @site
          @checker.check
          @checker.check
        }.should change { Event.count }.by(2)
      end

      it "should take uniqueness_look_back into account during deduplication" do
        @site['mode'] = 'all'
        @checker.options = @site
        @checker.check
        @checker.check
        event = Event.last
        event.payload = "{}"
        event.save

        lambda {
          @site['mode'] = 'on_change'
          @site['uniqueness_look_back'] = 2
          @checker.options = @site
          @checker.check
        }.should_not change { Event.count }

        lambda {
          @site['mode'] = 'on_change'
          @site['uniqueness_look_back'] = 1
          @checker.options = @site
          @checker.check
        }.should change { Event.count }.by(1)
      end

      it "should log an error if the number of results for a set of extraction patterns differs" do
        @site['extract']['url']['css'] = "div"
        @checker.options = @site
        @checker.check
        @checker.logs.first.message.should =~ /Got an uneven number of matches/
      end

      it "should accept an array for url" do
        @site['url'] = ["http://xkcd.com/1/", "http://xkcd.com/2/"]
        @checker.options = @site
        lambda { @checker.save! }.should_not raise_error;
        lambda { @checker.check }.should_not raise_error;
      end

      it "should parse events from all urls in array" do
        lambda {
          @site['url'] = ["http://xkcd.com/", "http://xkcd.com/"]
          @site['mode'] = 'all'
          @checker.options = @site
          @checker.check
        }.should change { Event.count }.by(2)
      end

      it "should follow unique rules when parsing array of urls" do
        lambda {
          @site['url'] = ["http://xkcd.com/", "http://xkcd.com/"]
          @checker.options = @site
          @checker.check
        }.should change { Event.count }.by(1)
      end
    end

    describe 'encoding' do
      it 'should be forced with force_encoding option' do
        huginn = "\u{601d}\u{8003}"
        stub_request(:any, /no-encoding/).to_return(:body => {
            :value => huginn,
          }.to_json.encode(Encoding::EUC_JP), :headers => {
            'Content-Type' => 'application/json',
          }, :status => 200)
        site = {
          'name' => "Some JSON Response",
          'expected_update_period_in_days' => 2,
          'type' => "json",
          'url' => "http://no-encoding.example.com",
          'mode' => 'on_change',
          'extract' => {
            'value' => { 'path' => 'value' },
          },
          'force_encoding' => 'EUC-JP',
        }
        checker = Agents::WebsiteAgent.new(:name => "No Encoding Site", :options => site)
        checker.user = users(:bob)
        checker.save!

        checker.check
        event = Event.last
        event.payload['value'].should == huginn
      end

      it 'should be overridden with force_encoding option' do
        huginn = "\u{601d}\u{8003}"
        stub_request(:any, /wrong-encoding/).to_return(:body => {
            :value => huginn,
          }.to_json.encode(Encoding::EUC_JP), :headers => {
            'Content-Type' => 'application/json; UTF-8',
          }, :status => 200)
        site = {
          'name' => "Some JSON Response",
          'expected_update_period_in_days' => 2,
          'type' => "json",
          'url' => "http://wrong-encoding.example.com",
          'mode' => 'on_change',
          'extract' => {
            'value' => { 'path' => 'value' },
          },
          'force_encoding' => 'EUC-JP',
        }
        checker = Agents::WebsiteAgent.new(:name => "Wrong Encoding Site", :options => site)
        checker.user = users(:bob)
        checker.save!

        checker.check
        event = Event.last
        event.payload['value'].should == huginn
      end
    end

    describe '#working?' do
      it 'checks if events have been received within the expected receive period' do
        stubbed_time = Time.now
        stub(Time).now { stubbed_time }

        @checker.should_not be_working # No events created
        @checker.check
        @checker.reload.should be_working # Just created events

        @checker.error "oh no!"
        @checker.reload.should_not be_working # There is a recent error

        stubbed_time = 20.minutes.from_now
        @checker.events.delete_all
        @checker.check
        @checker.reload.should be_working # There is a newer event now

        stubbed_time = 2.days.from_now
        @checker.reload.should_not be_working # Two days have passed without a new event having been created
      end
    end

    describe "parsing" do
      it "parses CSS" do
        @checker.check
        event = Event.last
        event.payload['url'].should == "http://imgs.xkcd.com/comics/evolving.png"
        event.payload['title'].should == "Evolving"
        event.payload['hovertext'].should =~ /^Biologists play reverse/
      end

      it "parses XPath" do
        @site['extract'].each { |key, value|
          value.delete('css')
          value['xpath'] = "//*[@id='comic']//img"
        }
        @checker.options = @site
        @checker.check
        event = Event.last
        event.payload['url'].should == "http://imgs.xkcd.com/comics/evolving.png"
        event.payload['title'].should == "Evolving"
        event.payload['hovertext'].should =~ /^Biologists play reverse/
      end

      it "should turn relative urls to absolute" do
        rel_site = {
          'name' => "XKCD",
          'expected_update_period_in_days' => 2,
          'type' => "html",
          'url' => "http://xkcd.com",
          'mode' => "on_change",
          'extract' => {
            'url' => {'css' => "#topLeft a", 'attr' => "href"},
            'title' => {'css' => "#topLeft a", 'text' => "true"}
          }
        }
        rel = Agents::WebsiteAgent.new(:name => "xkcd", :options => rel_site)
        rel.user = users(:bob)
        rel.save!
        rel.check
        event = Event.last
        event.payload['url'].should == "http://xkcd.com/about"
      end

      describe "JSON" do
        it "works with paths" do
          json = {
            'response' => {
              'version' => 2,
              'title' => "hello!"
            }
          }
          stub_request(:any, /json-site/).to_return(:body => json.to_json, :status => 200)
          site = {
            'name' => "Some JSON Response",
            'expected_update_period_in_days' => 2,
            'type' => "json",
            'url' => "http://json-site.com",
            'mode' => 'on_change',
            'extract' => {
              'version' => {'path' => "response.version"},
              'title' => {'path' => "response.title"}
            }
          }
          checker = Agents::WebsiteAgent.new(:name => "Weather Site", :options => site)
          checker.user = users(:bob)
          checker.save!

          checker.check
          event = Event.last
          event.payload['version'].should == 2
          event.payload['title'].should == "hello!"
        end

        it "can handle arrays" do
          json = {
            'response' => {
              'data' => [
                {'title' => "first", 'version' => 2},
                {'title' => "second", 'version' => 2.5}
              ]
            }
          }
          stub_request(:any, /json-site/).to_return(:body => json.to_json, :status => 200)
          site = {
            'name' => "Some JSON Response",
            'expected_update_period_in_days' => 2,
            'type' => "json",
            'url' => "http://json-site.com",
            'mode' => 'on_change',
            'extract' => {
              :title => {'path' => "response.data[*].title"},
              :version => {'path' => "response.data[*].version"}
            }
          }
          checker = Agents::WebsiteAgent.new(:name => "Weather Site", :options => site)
          checker.user = users(:bob)
          checker.save!

          lambda {
            checker.check
          }.should change { Event.count }.by(2)

          event = Event.all[-1]
          event.payload['version'].should == 2.5
          event.payload['title'].should == "second"

          event = Event.all[-2]
          event.payload['version'].should == 2
          event.payload['title'].should == "first"
        end

        it "stores the whole object if :extract is not specified" do
          json = {
            'response' => {
              'version' => 2,
              'title' => "hello!"
            }
          }
          stub_request(:any, /json-site/).to_return(:body => json.to_json, :status => 200)
          site = {
            'name' => "Some JSON Response",
            'expected_update_period_in_days' => 2,
            'type' => "json",
            'url' => "http://json-site.com",
            'mode' => 'on_change'
          }
          checker = Agents::WebsiteAgent.new(:name => "Weather Site", :options => site)
          checker.user = users(:bob)
          checker.save!

          checker.check
          event = Event.last
          event.payload['response']['version'].should == 2
          event.payload['response']['title'].should == "hello!"
        end
      end
    end
  end

  describe "checking with http basic auth" do
    before do
      stub_request(:any, /user:pass/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/xkcd.html")), :status => 200)
      @site = {
        'name' => "XKCD",
        'expected_update_period_in_days' => 2,
        'type' => "html",
        'url' => "http://www.example.com",
        'mode' => 'on_change',
        'extract' => {
          'url' => { 'css' => "#comic img", 'attr' => "src" },
          'title' => { 'css' => "#comic img", 'attr' => "alt" },
          'hovertext' => { 'css' => "#comic img", 'attr' => "title" }
        },
        'basic_auth' => "user:pass"
      }
      @checker = Agents::WebsiteAgent.new(:name => "auth", :options => @site)
      @checker.user = users(:bob)
      @checker.save!
    end

    describe "#check" do
      it "should check for changes" do
        lambda { @checker.check }.should change { Event.count }.by(1)
        lambda { @checker.check }.should_not change { Event.count }
      end
    end
  end
end
