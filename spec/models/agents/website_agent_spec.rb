require 'spec_helper'

describe Agents::WebsiteAgent do
  describe "checking without basic auth" do
    before do
      stub_request(:any, /xkcd/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/xkcd.html")), :status => 200)
      @valid_options = {
        'name' => "XKCD",
        'expected_update_period_in_days' => "2",
        'type' => "html",
        'url' => "http://xkcd.com",
        'mode' => 'on_change',
        'extract' => {
          'url' => { 'css' => "#comic img", 'value' => "@src" },
          'title' => { 'css' => "#comic img", 'value' => "@alt" },
          'hovertext' => { 'css' => "#comic img", 'value' => "@title" }
        }
      }
      @checker = Agents::WebsiteAgent.new(:name => "xkcd", :options => @valid_options, :keep_events_for => 2)
      @checker.user = users(:bob)
      @checker.save!
    end

    it_behaves_like WebRequestConcern

    describe "validations" do
      before do
        @checker.should be_valid
      end

      it "should validate the integer fields" do
        @checker.options['expected_update_period_in_days'] = "2"
        @checker.should be_valid

        @checker.options['expected_update_period_in_days'] = "nonsense"
        @checker.should_not be_valid
      end

      it "should validate uniqueness_look_back" do
        @checker.options['uniqueness_look_back'] = "nonsense"
        @checker.should_not be_valid

        @checker.options['uniqueness_look_back'] = "2"
        @checker.should be_valid
      end

      it "should validate mode" do
        @checker.options['mode'] = "nonsense"
        @checker.should_not be_valid

        @checker.options['mode'] = "on_change"
        @checker.should be_valid

        @checker.options['mode'] = "all"
        @checker.should be_valid

        @checker.options['mode'] = ""
        @checker.should be_valid
      end

      it "should validate the force_encoding option" do
        @checker.options['force_encoding'] = ''
        @checker.should be_valid

        @checker.options['force_encoding'] = 'UTF-8'
        @checker.should be_valid

        @checker.options['force_encoding'] = ['UTF-8']
        @checker.should_not be_valid

        @checker.options['force_encoding'] = 'UTF-42'
        @checker.should_not be_valid
      end
    end

    describe "#check" do
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
          @valid_options['mode'] = 'all'
          @checker.options = @valid_options
          @checker.check
          @checker.check
        }.should change { Event.count }.by(2)
      end

      it "should take uniqueness_look_back into account during deduplication" do
        @valid_options['mode'] = 'all'
        @checker.options = @valid_options
        @checker.check
        @checker.check
        event = Event.last
        event.payload = "{}"
        event.save

        lambda {
          @valid_options['mode'] = 'on_change'
          @valid_options['uniqueness_look_back'] = 2
          @checker.options = @valid_options
          @checker.check
        }.should_not change { Event.count }

        lambda {
          @valid_options['mode'] = 'on_change'
          @valid_options['uniqueness_look_back'] = 1
          @checker.options = @valid_options
          @checker.check
        }.should change { Event.count }.by(1)
      end

      it "should log an error if the number of results for a set of extraction patterns differs" do
        @valid_options['extract']['url']['css'] = "div"
        @checker.options = @valid_options
        @checker.check
        @checker.logs.first.message.should =~ /Got an uneven number of matches/
      end

      it "should accept an array for url" do
        @valid_options['url'] = ["http://xkcd.com/1/", "http://xkcd.com/2/"]
        @checker.options = @valid_options
        lambda { @checker.save! }.should_not raise_error;
        lambda { @checker.check }.should_not raise_error;
      end

      it "should parse events from all urls in array" do
        lambda {
          @valid_options['url'] = ["http://xkcd.com/", "http://xkcd.com/"]
          @valid_options['mode'] = 'all'
          @checker.options = @valid_options
          @checker.check
        }.should change { Event.count }.by(2)
      end

      it "should follow unique rules when parsing array of urls" do
        lambda {
          @valid_options['url'] = ["http://xkcd.com/", "http://xkcd.com/"]
          @checker.options = @valid_options
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
          'expected_update_period_in_days' => "2",
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
          'expected_update_period_in_days' => "2",
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
        @valid_options['extract'].each { |key, value|
          value.delete('css')
          value['xpath'] = "//*[@id='comic']//img"
        }
        @checker.options = @valid_options
        @checker.check
        event = Event.last
        event.payload['url'].should == "http://imgs.xkcd.com/comics/evolving.png"
        event.payload['title'].should == "Evolving"
        event.payload['hovertext'].should =~ /^Biologists play reverse/
      end

      it "should turn relative urls to absolute" do
        rel_site = {
          'name' => "XKCD",
          'expected_update_period_in_days' => "2",
          'type' => "html",
          'url' => "http://xkcd.com",
          'mode' => "on_change",
          'extract' => {
            'url' => {'css' => "#topLeft a", 'value' => "@href"},
          }
        }
        rel = Agents::WebsiteAgent.new(:name => "xkcd", :options => rel_site)
        rel.user = users(:bob)
        rel.save!
        rel.check
        event = Event.last
        event.payload['url'].should == "http://xkcd.com/about"
      end

      it "should return an integer value if XPath evaluates to one" do
        rel_site = {
          'name' => "XKCD",
          'expected_update_period_in_days' => 2,
          'type' => "html",
          'url' => "http://xkcd.com",
          'mode' => "on_change",
          'extract' => {
            'num_links' => {'css' => "#comicLinks", 'value' => "count(./a)"}
          }
        }
        rel = Agents::WebsiteAgent.new(:name => "xkcd", :options => rel_site)
        rel.user = users(:bob)
        rel.save!
        rel.check
        event = Event.last
        event.payload['num_links'].should == "9"
      end

      it "should return all texts concatenated if XPath returns many text nodes" do
        rel_site = {
          'name' => "XKCD",
          'expected_update_period_in_days' => 2,
          'type' => "html",
          'url' => "http://xkcd.com",
          'mode' => "on_change",
          'extract' => {
            'slogan' => {'css' => "#slogan", 'value' => ".//text()"}
          }
        }
        rel = Agents::WebsiteAgent.new(:name => "xkcd", :options => rel_site)
        rel.user = users(:bob)
        rel.save!
        rel.check
        event = Event.last
        event.payload['slogan'].should == "A webcomic of romance, sarcasm, math, and language."
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
            'expected_update_period_in_days' => "2",
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
            'expected_update_period_in_days' => "2",
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
            'expected_update_period_in_days' => "2",
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

      describe "text parsing" do
        before do
          stub_request(:any, /text-site/).to_return(body: <<-EOF, status: 200)
water: wet
fire: hot
          EOF
          site = {
            'name' => 'Some Text Response',
            'expected_update_period_in_days' => '2',
            'type' => 'text',
            'url' => 'http://text-site.com',
            'mode' => 'on_change',
            'extract' => {
              'word' => { 'regexp' => '^(.+?): (.+)$', index: 1 },
              'property' => { 'regexp' => '^(.+?): (.+)$', index: 2 },
            }
          }
          @checker = Agents::WebsiteAgent.new(name: 'Text Site', options: site)
          @checker.user = users(:bob)
          @checker.save!
        end

        it "works with regexp" do
          @checker.options = @checker.options.merge('extract' => {
            'word' => { 'regexp' => '^(?<word>.+?): (?<property>.+)$', index: 'word' },
            'property' => { 'regexp' => '^(?<word>.+?): (?<property>.+)$', index: 'property' },
          })

          lambda {
            @checker.check
          }.should change { Event.count }.by(2)

          event1, event2 = Event.last(2)
          event1.payload['word'].should == 'water'
          event1.payload['property'].should == 'wet'
          event2.payload['word'].should == 'fire'
          event2.payload['property'].should == 'hot'
        end

        it "works with regexp with named capture" do
          lambda {
            @checker.check
          }.should change { Event.count }.by(2)

          event1, event2 = Event.last(2)
          event1.payload['word'].should == 'water'
          event1.payload['property'].should == 'wet'
          event2.payload['word'].should == 'fire'
          event2.payload['property'].should == 'hot'
        end
      end
    end

    describe "#receive" do
      it "should scrape from the url element in incoming event payload" do
        @event = Event.new
        @event.agent = agents(:bob_rain_notifier_agent)
        @event.payload = { 'url' => "http://xkcd.com" }

        lambda {
          @checker.options = @valid_options
          @checker.receive([@event])
        }.should change { Event.count }.by(1)
      end
    end
  end

  describe "checking with http basic auth" do
    before do
      stub_request(:any, /example/).
        with(headers: { 'Authorization' => "Basic #{['user:pass'].pack('m').chomp}" }).
        to_return(:body => File.read(Rails.root.join("spec/data_fixtures/xkcd.html")), :status => 200)
      @valid_options = {
        'name' => "XKCD",
        'expected_update_period_in_days' => "2",
        'type' => "html",
        'url' => "http://www.example.com",
        'mode' => 'on_change',
        'extract' => {
          'url' => { 'css' => "#comic img", 'value' => "@src" },
          'title' => { 'css' => "#comic img", 'value' => "@alt" },
          'hovertext' => { 'css' => "#comic img", 'value' => "@title" }
        },
        'basic_auth' => "user:pass"
      }
      @checker = Agents::WebsiteAgent.new(:name => "auth", :options => @valid_options)
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

  describe "checking with headers" do
    before do
      stub_request(:any, /example/).
        with(headers: { 'foo' => 'bar', 'user_agent' => /Faraday/ }).
        to_return(:body => File.read(Rails.root.join("spec/data_fixtures/xkcd.html")), :status => 200)
      @valid_options = {
        'name' => "XKCD",
        'expected_update_period_in_days' => "2",
        'type' => "html",
        'url' => "http://www.example.com",
        'mode' => 'on_change',
        'headers' => { 'foo' => 'bar' },
        'extract' => {
          'url' => { 'css' => "#comic img", 'value' => "@src" },
        }
      }
      @checker = Agents::WebsiteAgent.new(:name => "ua", :options => @valid_options)
      @checker.user = users(:bob)
      @checker.save!
    end

    describe "#check" do
      it "should check for changes" do
        lambda { @checker.check }.should change { Event.count }.by(1)
      end
    end
  end
end
