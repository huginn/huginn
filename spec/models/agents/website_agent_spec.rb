require 'rails_helper'

describe Agents::WebsiteAgent do
  describe "checking without basic auth" do
    before do
      stub_request(:any, /xkcd/).to_return(body: File.read(Rails.root.join("spec/data_fixtures/xkcd.html")),
                                           status: 200,
                                           headers: {
                                             'X-Status-Message' => 'OK'
                                           })
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
      @checker = Agents::WebsiteAgent.new(:name => "xkcd", :options => @valid_options, :keep_events_for => 2.days)
      @checker.user = users(:bob)
      @checker.save!
    end

    it_behaves_like WebRequestConcern

    describe "validations" do
      before do
        expect(@checker).to be_valid
      end

      it "should validate the integer fields" do
        @checker.options['expected_update_period_in_days'] = "2"
        expect(@checker).to be_valid

        @checker.options['expected_update_period_in_days'] = "nonsense"
        expect(@checker).not_to be_valid
      end

      it 'should validate the http_success_codes fields' do
        @checker.options['http_success_codes'] = [404]
        expect(@checker).to be_valid

        @checker.options['http_success_codes'] = [404, 404]
        expect(@checker).not_to be_valid

        @checker.options['http_success_codes'] = [404, "422"]
        expect(@checker).to be_valid

        @checker.options['http_success_codes'] = [404.0]
        expect(@checker).not_to be_valid

        @checker.options['http_success_codes'] = ["not_a_code"]
        expect(@checker).not_to be_valid

        @checker.options['http_success_codes'] = []
        expect(@checker).to be_valid

        @checker.options['http_success_codes'] = ''
        expect(@checker).to be_valid

        @checker.options['http_success_codes'] = false
        expect(@checker).to be_valid
      end

      it "should validate uniqueness_look_back" do
        @checker.options['uniqueness_look_back'] = "nonsense"
        expect(@checker).not_to be_valid

        @checker.options['uniqueness_look_back'] = "2"
        expect(@checker).to be_valid
      end

      it "should validate mode" do
        @checker.options['mode'] = "nonsense"
        expect(@checker).not_to be_valid

        @checker.options['mode'] = "on_change"
        expect(@checker).to be_valid

        @checker.options['mode'] = "all"
        expect(@checker).to be_valid

        @checker.options['mode'] = ""
        expect(@checker).to be_valid
      end

      it "should validate the force_encoding option" do
        @checker.options['force_encoding'] = ''
        expect(@checker).to be_valid

        @checker.options['force_encoding'] = 'UTF-8'
        expect(@checker).to be_valid

        @checker.options['force_encoding'] = ['UTF-8']
        expect(@checker).not_to be_valid

        @checker.options['force_encoding'] = 'UTF-42'
        expect(@checker).not_to be_valid
      end

      context "in 'json' type" do
        it "should ensure that all extractions have a 'path'" do
          @checker.options['type'] = 'json'
          @checker.options['extract'] = {
            'url' => { 'foo' => 'bar' },
          }
          expect(@checker).to_not be_valid
          expect(@checker.errors_on(:base)).to include(/When type is json, all extractions must have a path attribute/)

          @checker.options['type'] = 'json'
          @checker.options['extract'] = {
            'url' => { 'path' => 'bar' },
          }
          expect(@checker).to be_valid
        end
      end
    end

    describe "#check" do
      it "should check for changes (and update Event.expires_at)" do
        expect { @checker.check }.to change { Event.count }.by(1)
        event = Event.last
        sleep 2
        expect { @checker.check }.not_to change { Event.count }
        update_event = Event.last
        expect(update_event.expires_at).not_to eq(event.expires_at)
      end

      it "should always save events when in :all mode" do
        expect {
          @valid_options['mode'] = 'all'
          @checker.options = @valid_options
          @checker.check
          @checker.check
        }.to change { Event.count }.by(2)
      end

      it "should take uniqueness_look_back into account during deduplication" do
        @valid_options['mode'] = 'all'
        @checker.options = @valid_options
        @checker.check
        @checker.check
        event = Event.last
        event.payload = "{}"
        event.save

        expect {
          @valid_options['mode'] = 'on_change'
          @valid_options['uniqueness_look_back'] = 2
          @checker.options = @valid_options
          @checker.check
        }.not_to change { Event.count }

        expect {
          @valid_options['mode'] = 'on_change'
          @valid_options['uniqueness_look_back'] = 1
          @checker.options = @valid_options
          @checker.check
        }.to change { Event.count }.by(1)
      end

      it "should log an error if the number of results for a set of extraction patterns differs" do
        @valid_options['extract']['url']['css'] = "div"
        @checker.options = @valid_options
        @checker.check
        expect(@checker.logs.first.message).to match(/Got an uneven number of matches/)
      end

      it "should accept an array for url" do
        @valid_options['url'] = ["http://xkcd.com/1/", "http://xkcd.com/2/"]
        @checker.options = @valid_options
        expect { @checker.save! }.not_to raise_error;
        expect { @checker.check }.not_to raise_error;
      end

      it "should parse events from all urls in array" do
        expect {
          @valid_options['url'] = ["http://xkcd.com/", "http://xkcd.com/"]
          @valid_options['mode'] = 'all'
          @checker.options = @valid_options
          @checker.check
        }.to change { Event.count }.by(2)
      end

      it "should follow unique rules when parsing array of urls" do
        expect {
          @valid_options['url'] = ["http://xkcd.com/", "http://xkcd.com/"]
          @checker.options = @valid_options
          @checker.check
        }.to change { Event.count }.by(1)
      end
    end

    describe 'http_success_codes' do
      it 'should allow scraping from a 404 result' do
        json = {
          'response' => {
            'version' => 2,
            'title' => "hello!"
          }
        }
        zipped = ActiveSupport::Gzip.compress(json.to_json)
        stub_request(:any, /gzip/).to_return(body: zipped, headers: { 'Content-Encoding' => 'gzip' }, status: 404)
        site = {
          'name' => "Some JSON Response",
          'expected_update_period_in_days' => "2",
          'type' => "json",
          'url' => "http://gzip.com",
          'mode' => 'on_change',
          'http_success_codes' => [404],
          'extract' => {
            'version' => { 'path' => 'response.version' },
          },
          # no unzip option
        }
        checker = Agents::WebsiteAgent.new(:name => "Weather Site", :options => site)
        checker.user = users(:bob)
        checker.save!

        checker.check
        event = Event.last
        expect(event.payload['version']).to eq(2)
      end
    end

    describe 'unzipping' do
      it 'should unzip automatically if the response has Content-Encoding: gzip' do
        json = {
          'response' => {
            'version' => 2,
            'title' => "hello!"
          }
        }
        zipped = ActiveSupport::Gzip.compress(json.to_json)
        stub_request(:any, /gzip/).to_return(body: zipped, headers: { 'Content-Encoding' => 'gzip' }, status: 200)
        site = {
          'name' => "Some JSON Response",
          'expected_update_period_in_days' => "2",
          'type' => "json",
          'url' => "http://gzip.com",
          'mode' => 'on_change',
          'extract' => {
            'version' => { 'path' => 'response.version' },
          },
          # no unzip option
        }
        checker = Agents::WebsiteAgent.new(:name => "Weather Site", :options => site)
        checker.user = users(:bob)
        checker.save!

        checker.check
        event = Event.last
        expect(event.payload['version']).to eq(2)
      end

      it 'should unzip with unzip option' do
        json = {
          'response' => {
            'version' => 2,
            'title' => "hello!"
          }
        }
        zipped = ActiveSupport::Gzip.compress(json.to_json)
        stub_request(:any, /gzip/).to_return(body: zipped, status: 200)
        site = {
          'name' => "Some JSON Response",
          'expected_update_period_in_days' => "2",
          'type' => "json",
          'url' => "http://gzip.com",
          'mode' => 'on_change',
          'extract' => {
            'version' => { 'path' => 'response.version' },
          },
          'unzip' => 'gzip',
        }
        checker = Agents::WebsiteAgent.new(:name => "Weather Site", :options => site)
        checker.user = users(:bob)
        checker.save!

        checker.check
        event = Event.last
        expect(event.payload['version']).to eq(2)
      end

      it 'should either avoid or support a raw deflate stream (#1018)' do
        stub_request(:any, /deflate/).with(headers: { 'Accept-Encoding' => /\A(?!.*deflate)/ }).
          to_return(body: 'hello',
                    status: 200)
        stub_request(:any, /deflate/).with(headers: { 'Accept-Encoding' => /deflate/ }).
          to_return(body: "\xcb\x48\xcd\xc9\xc9\x07\x00\x06\x2c".b,
                    headers: { 'Content-Encoding' => 'deflate' },
                    status: 200)

        site = {
          'name' => 'Some Response',
          'expected_update_period_in_days' => '2',
          'type' => 'text',
          'url' => 'http://deflate',
          'mode' => 'on_change',
          'extract' => {
            'content' => { 'regexp' => '.+', 'index' => 0 }
          }
        }
        checker = Agents::WebsiteAgent.new(name: "Deflate Test", options: site)
        checker.user = users(:bob)
        checker.save!

        expect {
          checker.check
        }.to change { Event.count }.by(1)
        event = Event.last
        expect(event.payload['content']).to eq('hello')
      end
    end

    describe 'encoding' do
      it 'should be forced with force_encoding option' do
        huginn = "\u{601d}\u{8003}"
        stub_request(:any, /no-encoding/).to_return(body: {
            value: huginn,
          }.to_json.encode(Encoding::EUC_JP).b, headers: {
            'Content-Type' => 'application/json',
          }, status: 200)
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
        checker = Agents::WebsiteAgent.new(name: "No Encoding Site", options: site)
        checker.user = users(:bob)
        checker.save!

        expect { checker.check }.to change { Event.count }.by(1)
        event = Event.last
        expect(event.payload['value']).to eq(huginn)
      end

      it 'should be overridden with force_encoding option' do
        huginn = "\u{601d}\u{8003}"
        stub_request(:any, /wrong-encoding/).to_return(body: {
            value: huginn,
          }.to_json.encode(Encoding::EUC_JP).b, headers: {
            'Content-Type' => 'application/json; UTF-8',
          }, status: 200)
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
        checker = Agents::WebsiteAgent.new(name: "Wrong Encoding Site", options: site)
        checker.user = users(:bob)
        checker.save!

        expect { checker.check }.to change { Event.count }.by(1)
        event = Event.last
        expect(event.payload['value']).to eq(huginn)
      end

      it 'should be determined by charset in Content-Type' do
        huginn = "\u{601d}\u{8003}"
        stub_request(:any, /charset-euc-jp/).to_return(body: {
            value: huginn,
          }.to_json.encode(Encoding::EUC_JP), headers: {
            'Content-Type' => 'application/json; charset=EUC-JP',
          }, status: 200)
        site = {
          'name' => "Some JSON Response",
          'expected_update_period_in_days' => "2",
          'type' => "json",
          'url' => "http://charset-euc-jp.example.com",
          'mode' => 'on_change',
          'extract' => {
            'value' => { 'path' => 'value' },
          },
        }
        checker = Agents::WebsiteAgent.new(name: "Charset reader", options: site)
        checker.user = users(:bob)
        checker.save!

        expect { checker.check }.to change { Event.count }.by(1)
        event = Event.last
        expect(event.payload['value']).to eq(huginn)
      end

      it 'should default to UTF-8 when unknown charset is found' do
        huginn = "\u{601d}\u{8003}"
        stub_request(:any, /charset-unknown/).to_return(body: {
            value: huginn,
          }.to_json.b, headers: {
            'Content-Type' => 'application/json; charset=unicode',
          }, status: 200)
        site = {
          'name' => "Some JSON Response",
          'expected_update_period_in_days' => "2",
          'type' => "json",
          'url' => "http://charset-unknown.example.com",
          'mode' => 'on_change',
          'extract' => {
            'value' => { 'path' => 'value' },
          },
        }
        checker = Agents::WebsiteAgent.new(name: "Charset reader", options: site)
        checker.user = users(:bob)
        checker.save!

        expect { checker.check }.to change { Event.count }.by(1)
        event = Event.last
        expect(event.payload['value']).to eq(huginn)
      end
    end

    describe '#working?' do
      it 'checks if events have been received within the expected receive period' do
        stubbed_time = Time.now
        stub(Time).now { stubbed_time }

        expect(@checker).not_to be_working # No events created
        @checker.check
        expect(@checker.reload).to be_working # Just created events

        @checker.error "oh no!"
        expect(@checker.reload).not_to be_working # There is a recent error

        stubbed_time = 20.minutes.from_now
        @checker.events.delete_all
        @checker.check
        expect(@checker.reload).to be_working # There is a newer event now

        stubbed_time = 2.days.from_now
        expect(@checker.reload).not_to be_working # Two days have passed without a new event having been created
      end
    end

    describe "parsing" do
      it "parses CSS" do
        @checker.check
        event = Event.last
        expect(event.payload['url']).to eq("http://imgs.xkcd.com/comics/evolving.png")
        expect(event.payload['title']).to eq("Evolving")
        expect(event.payload['hovertext']).to match(/^Biologists play reverse/)
      end

      it "parses XPath" do
        @valid_options['extract'].each { |key, value|
          value.delete('css')
          value['xpath'] = "//*[@id='comic']//img"
        }
        @checker.options = @valid_options
        @checker.check
        event = Event.last
        expect(event.payload['url']).to eq("http://imgs.xkcd.com/comics/evolving.png")
        expect(event.payload['title']).to eq("Evolving")
        expect(event.payload['hovertext']).to match(/^Biologists play reverse/)
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
        expect(event.payload['url']).to eq("http://xkcd.com/about")
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
        expect(event.payload['num_links']).to eq("9")
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
        expect(event.payload['slogan']).to eq("A webcomic of romance, sarcasm, math, and language.")
      end

      it "should interpolate _response_" do
        @valid_options['extract']['response_info'] =
          @valid_options['extract']['url'].merge(
            'value' => '"{{ "The reponse was " | append:_response_.status | append:" " | append:_response_.headers.X-Status-Message | append:"." }}"'
          )
        @checker.options = @valid_options
        @checker.check
        event = Event.last
        expect(event.payload['response_info']).to eq('The reponse was 200 OK.')
      end

      describe "XML" do
        before do
          stub_request(:any, /github_rss/).to_return(
            body: File.read(Rails.root.join("spec/data_fixtures/github_rss.atom")),
            status: 200
          )

          @checker = Agents::WebsiteAgent.new(name: 'github', options: {
            'name' => 'GitHub',
            'expected_update_period_in_days' => '2',
            'type' => 'xml',
            'url' => 'http://example.com/github_rss.atom',
            'mode' => 'on_change',
            'extract' => {
              'title' => { 'xpath' => '/feed/entry', 'value' => 'normalize-space(./title)' },
              'url' => { 'xpath' => '/feed/entry', 'value' => './link[1]/@href' },
              'thumbnail' => { 'xpath' => '/feed/entry', 'value' => './thumbnail/@url' },
            }
          }, keep_events_for: 2.days)
          @checker.user = users(:bob)
          @checker.save!
        end

        it "works with XPath" do
          expect {
            @checker.check
          }.to change { Event.count }.by(20)
          event = Event.last
          expect(event.payload['title']).to eq('Shift to dev group')
          expect(event.payload['url']).to eq('https://github.com/cantino/huginn/commit/d465158f77dcd9078697e6167b50abbfdfa8b1af')
          expect(event.payload['thumbnail']).to eq('https://avatars3.githubusercontent.com/u/365751?s=30')
        end

        it "works with XPath with namespaces unstripped" do
          @checker.options['use_namespaces'] = 'true'
          @checker.save!
          expect {
            @checker.check
          }.to change { Event.count }.by(0)

          @checker.options['extract'] = {
            'title' => { 'xpath' => '/xmlns:feed/xmlns:entry', 'value' => 'normalize-space(./xmlns:title)' },
            'url' => { 'xpath' => '/xmlns:feed/xmlns:entry', 'value' => './xmlns:link[1]/@href' },
            'thumbnail' => { 'xpath' => '/xmlns:feed/xmlns:entry', 'value' => './media:thumbnail/@url' },
          }
          @checker.save!
          expect {
            @checker.check
          }.to change { Event.count }.by(20)
          event = Event.last
          expect(event.payload['title']).to eq('Shift to dev group')
          expect(event.payload['url']).to eq('https://github.com/cantino/huginn/commit/d465158f77dcd9078697e6167b50abbfdfa8b1af')
          expect(event.payload['thumbnail']).to eq('https://avatars3.githubusercontent.com/u/365751?s=30')
        end

        it "works with CSS selectors" do
          @checker.options['extract'] = {
            'title' => { 'css' => 'feed > entry', 'value' => 'normalize-space(./title)' },
            'url' => { 'css' => 'feed > entry', 'value' => './link[1]/@href' },
            'thumbnail' => { 'css' => 'feed > entry', 'value' => './thumbnail/@url' },
          }
          @checker.save!
          expect {
            @checker.check
          }.to change { Event.count }.by(20)
          event = Event.last
          expect(event.payload['title']).to be_empty
          expect(event.payload['thumbnail']).to be_empty

          @checker.options['extract'] = {
            'title' => { 'css' => 'feed > entry', 'value' => 'normalize-space(./xmlns:title)' },
            'url' => { 'css' => 'feed > entry', 'value' => './xmlns:link[1]/@href' },
            'thumbnail' => { 'css' => 'feed > entry', 'value' => './media:thumbnail/@url' },
          }
          @checker.save!
          expect {
            @checker.check
          }.to change { Event.count }.by(20)
          event = Event.last
          expect(event.payload['title']).to eq('Shift to dev group')
          expect(event.payload['url']).to eq('https://github.com/cantino/huginn/commit/d465158f77dcd9078697e6167b50abbfdfa8b1af')
          expect(event.payload['thumbnail']).to eq('https://avatars3.githubusercontent.com/u/365751?s=30')
        end

        it "works with CSS selectors with namespaces stripped" do
          @checker.options['extract'] = {
            'title' => { 'css' => 'feed > entry', 'value' => 'normalize-space(./title)' },
            'url' => { 'css' => 'feed > entry', 'value' => './link[1]/@href' },
            'thumbnail' => { 'css' => 'feed > entry', 'value' => './thumbnail/@url' },
          }
          @checker.options['use_namespaces'] = 'false'
          @checker.save!
          expect {
            @checker.check
          }.to change { Event.count }.by(20)
          event = Event.last
          expect(event.payload['title']).to eq('Shift to dev group')
          expect(event.payload['url']).to eq('https://github.com/cantino/huginn/commit/d465158f77dcd9078697e6167b50abbfdfa8b1af')
          expect(event.payload['thumbnail']).to eq('https://avatars3.githubusercontent.com/u/365751?s=30')
        end
      end

      describe "XML with cdata" do
        before do
          stub_request(:any, /cdata_rss/).to_return(
            body: File.read(Rails.root.join("spec/data_fixtures/cdata_rss.atom")),
            status: 200
          )

          @checker = Agents::WebsiteAgent.new(name: 'cdata', options: {
            'name' => 'CDATA',
            'expected_update_period_in_days' => '2',
            'type' => 'xml',
            'url' => 'http://example.com/cdata_rss.atom',
            'mode' => 'on_change',
            'extract' => {
              'author' => { 'xpath' => '/feed/entry/author/name', 'value' => './/text()'},
              'title' => { 'xpath' => '/feed/entry/title', 'value' => './/text()' },
              'content' => { 'xpath' => '/feed/entry/content', 'value' => './/text()' },
            }
          }, keep_events_for: 2.days)
          @checker.user = users(:bob)
          @checker.save!
        end

        it "works with XPath" do
          expect {
            @checker.check
          }.to change { Event.count }.by(10)
          event = Event.last
          expect(event.payload['author']).to eq('bill98')
          expect(event.payload['title']).to eq('Help: Rainmeter Skins • Test if Today is Between 2 Dates')
          expect(event.payload['content']).to start_with('Can I ')
        end

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
          expect(event.payload['version']).to eq(2)
          expect(event.payload['title']).to eq("hello!")
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

          expect {
            checker.check
          }.to change { Event.count }.by(2)

          (event2, event1) = Event.last(2)
          expect(event1.payload['version']).to eq(2.5)
          expect(event1.payload['title']).to eq("second")

          expect(event2.payload['version']).to eq(2)
          expect(event2.payload['title']).to eq("first")
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
          expect(event.payload['response']['version']).to eq(2)
          expect(event.payload['response']['title']).to eq("hello!")
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
              'property' => { 'regexp' => '^(.+?): (.+)$', index: '2' },
            }
          }
          @checker = Agents::WebsiteAgent.new(name: 'Text Site', options: site)
          @checker.user = users(:bob)
          @checker.save!
        end

        it "works with regexp with named capture" do
          @checker.options = @checker.options.merge('extract' => {
            'word' => { 'regexp' => '^(?<word>.+?): (?<property>.+)$', index: 'word' },
            'property' => { 'regexp' => '^(?<word>.+?): (?<property>.+)$', index: 'property' },
          })

          expect {
            @checker.check
          }.to change { Event.count }.by(2)

          event1, event2 = Event.last(2)
          expect(event1.payload['word']).to eq('water')
          expect(event1.payload['property']).to eq('wet')
          expect(event2.payload['word']).to eq('fire')
          expect(event2.payload['property']).to eq('hot')
        end

        it "works with regexp" do
          expect {
            @checker.check
          }.to change { Event.count }.by(2)

          event1, event2 = Event.last(2)
          expect(event1.payload['word']).to eq('water')
          expect(event1.payload['property']).to eq('wet')
          expect(event2.payload['word']).to eq('fire')
          expect(event2.payload['property']).to eq('hot')
        end
      end
    end

    describe "#receive" do
      describe "with a url or url_from_event" do
        before do
          @event = Event.new
          @event.agent = agents(:bob_rain_notifier_agent)
          @event.payload = {
            'url' => 'http://foo.com',
            'link' => 'Random'
          }
        end

        it "should use url_from_event as the url to scrape" do
          stub = stub_request(:any, 'http://example.org/?url=http%3A%2F%2Ffoo.com')

          @checker.options = @valid_options.merge(
            'url_from_event' => 'http://example.org/?url={{url | uri_escape}}'
          )
          @checker.receive([@event])

          expect(stub).to have_been_requested
        end

        it "should use the Agent's `url` option if url_from_event is not set" do
          expect {
            @checker.options = @valid_options
            @checker.receive([@event])
          }.to change { Event.count }.by(1)
        end

        it "should allow url_from_event to be an array of urls" do
          stub1 = stub_request(:any, 'http://example.org/?url=http%3A%2F%2Ffoo.com')
          stub2 = stub_request(:any, 'http://google.org/?url=http%3A%2F%2Ffoo.com')

          @checker.options = @valid_options.merge(
            'url_from_event' => ['http://example.org/?url={{url | uri_escape}}', 'http://google.org/?url={{url | uri_escape}}']
          )
          @checker.receive([@event])

          expect(stub1).to have_been_requested
          expect(stub2).to have_been_requested
        end

        it "should interpolate values from incoming event payload" do
          stub_request(:any, /foo/).to_return(body: File.read(Rails.root.join("spec/data_fixtures/xkcd.html")), status: 200)

          expect {
            @valid_options['url_from_event'] = '{{ url }}'
            @valid_options['extract'] = {
              'from' => {
                'xpath' => '*[1]',
                'value' => '{{url | to_xpath}}'
              },
              'to' => {
                'xpath' => '(//a[@href and text()={{link | to_xpath}}])[1]',
                'value' => '@href'
              },
            }
            @checker.options = @valid_options
            @checker.receive([@event])
          }.to change { Event.count }.by(1)

          expect(Event.last.payload).to eq({
            'from' => 'http://foo.com',
            'to' => 'http://dynamic.xkcd.com/random/comic/',
          })
        end

        it "should use the options url if no url is in the event payload, and `url_from_event` is not provided" do
          @checker.options['mode'] = 'merge'
          @event.payload.delete('url')
          expect {
            @checker.receive([@event])
          }.to change { Event.count }.by(1)
          expect(Event.last.payload['title']).to eq('Evolving')
          expect(Event.last.payload['link']).to eq('Random')
        end

        it "should interpolate values from incoming event payload and _response_" do
          @event.payload['title'] = 'XKCD'

          expect {
            @valid_options['extract'] = {
              'response_info' => @valid_options['extract']['url'].merge(
                'value' => '{% capture sentence %}The reponse from {{title}} was {{_response_.status}} {{_response_.headers.X-Status-Message}}.{% endcapture %}{{sentence | to_xpath}}'
              )
            }
            @checker.options = @valid_options
            @checker.receive([@event])
          }.to change { Event.count }.by(1)

          expect(Event.last.payload['response_info']).to eq('The reponse from XKCD was 200 OK.')
        end

        it "should support merging of events" do
          expect {
            @checker.options = @valid_options
            @checker.options[:mode] = "merge"
            @checker.receive([@event])
          }.to change { Event.count }.by(1)
          last_payload = Event.last.payload
          expect(last_payload['link']).to eq('Random')
        end
      end

      describe "with a data_from_event" do
        describe "with json data" do
          before do
            @event = Event.new
            @event.agent = agents(:bob_rain_notifier_agent)
            @event.payload = {
              'something' => 'some value',
              'some_object' => {
                'some_data' => { hello: 'world' }.to_json
              }
            }
            @event.save!

            @checker.options = @valid_options.merge(
              'type' => 'json',
              'data_from_event' => '{{ some_object.some_data }}',
              'extract' => {
                'value' => { 'path' => 'hello' }
              }
            )
          end

          it "should extract from the event data in the incoming event payload" do
            expect {
              @checker.receive([@event])
            }.to change { Event.count }.by(1)
            expect(@checker.events.last.payload).to eq({ 'value' => 'world' })
          end

          it "should support merge mode" do
            @checker.options['mode'] = "merge"

            expect {
              @checker.receive([@event])
            }.to change { Event.count }.by(1)
            expect(@checker.events.last.payload).to eq(@event.payload.merge('value' => 'world'))
          end

          it "should output an error when nothing can be found at the path" do
            @checker.options = @checker.options.merge(
              'data_from_event' => '{{ some_object.mistake }}'
            )

            expect {
              @checker.receive([@event])
            }.to_not change { Event.count }

            expect(@checker.logs.last.message).to match(/No data was found in the Event payload using the template {{ some_object\.mistake }}/)
          end

          it "should output an error when the data cannot be parsed" do
            @event.update_attribute :payload, @event.payload.merge('some_object' => { 'some_data' => '{invalid json' })

            expect {
              @checker.receive([@event])
            }.to_not change { Event.count }

            expect(@checker.logs.last.message).to match(/Error when handling event data:/)
          end
        end

        describe "with HTML data" do
          before do
            @event = Event.new
            @event.agent = agents(:bob_rain_notifier_agent)
            @event.payload = {
              'url' => 'http://xkcd.com',
              'some_object' => {
                'some_data' => "<div><span class='title'>Title!</span><span class='body'>Body!</span></div>"
              }
            }
            @event.save!

            @checker.options = @valid_options.merge(
              'type' => 'html',
              'data_from_event' => '{{ some_object.some_data }}',
              'extract' => {
                'title' => { 'css' => ".title", 'value' => ".//text()" },
                'body' => { 'css' => "div span.body", 'value' => ".//text()" }
              }
            )
          end

          it "should extract from the event data in the incoming event payload" do
            expect {
              @checker.receive([@event])
            }.to change { Event.count }.by(1)
            expect(@checker.events.last.payload).to eq({ 'title' => 'Title!', 'body' => 'Body!' })
          end
        end
      end
    end
  end

  describe "checking with http basic auth" do
    before do
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

      case @checker.faraday_backend
      when :typhoeus
        # Webmock's typhoeus adapter does not read the Authorization
        # header: https://github.com/bblimke/webmock/pull/592
        stub_request(:any, "www.example.com").
          with(headers: { 'Authorization' => "Basic #{['user:pass'].pack('m0')}" })
      else
        stub_request(:any, "user:pass@www.example.com")
      end.to_return(body: File.read(Rails.root.join("spec/data_fixtures/xkcd.html")), status: 200)
    end

    describe "#check" do
      it "should check for changes" do
        expect { @checker.check }.to change { Event.count }.by(1)
        expect { @checker.check }.not_to change { Event.count }
      end
    end
  end

  describe "checking with headers" do
    before do
      stub_request(:any, /example/).
        with(headers: { 'foo' => 'bar' }).
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
        expect { @checker.check }.to change { Event.count }.by(1)
      end
    end
  end

  describe "checking urls" do
    before do
      stub_request(:any, /example/).
        to_return(:body => File.read(Rails.root.join("spec/data_fixtures/urlTest.html")), :status => 200)
      @valid_options = {
        'name' => "Url Test",
        'expected_update_period_in_days' => "2",
        'type' => "html",
        'url' => "http://www.example.com",
        'mode' => 'all',
        'extract' => {
          'url' => { 'css' => "a", 'value' => "@href" },
        }
      }
      @checker = Agents::WebsiteAgent.new(:name => "ua", :options => @valid_options)
      @checker.user = users(:bob)
      @checker.save!
    end

    describe "#check" do
      before do
        expect { @checker.check }.to change { Event.count }.by(7)
        @events = Event.last(7)
      end

      it "should check hostname" do
        event = @events[0]
        expect(event.payload['url']).to eq("http://google.com")
      end

      it "should check unescaped query" do
        event = @events[1]
        expect(event.payload['url']).to eq("https://www.google.ca/search?q=some%20query")
      end

      it "should check properly escaped query" do
        event = @events[2]
        expect(event.payload['url']).to eq("https://www.google.ca/search?q=some%20query")
      end

      it "should check unescaped unicode url" do
        event = @events[3]
        expect(event.payload['url']).to eq("http://ko.wikipedia.org/wiki/%EC%9C%84%ED%82%A4%EB%B0%B1%EA%B3%BC:%EB%8C%80%EB%AC%B8")
      end

      it "should check unescaped unicode query" do
        event = @events[4]
        expect(event.payload['url']).to eq("https://www.google.ca/search?q=%EC%9C%84%ED%82%A4%EB%B0%B1%EA%B3%BC:%EB%8C%80%EB%AC%B8")
      end

      it "should check properly escaped unicode url" do
        event = @events[5]
        expect(event.payload['url']).to eq("http://ko.wikipedia.org/wiki/%EC%9C%84%ED%82%A4%EB%B0%B1%EA%B3%BC:%EB%8C%80%EB%AC%B8")
      end

      it "should check properly escaped unicode query" do
        event = @events[6]
        expect(event.payload['url']).to eq("https://www.google.ca/search?q=%EC%9C%84%ED%82%A4%EB%B0%B1%EA%B3%BC:%EB%8C%80%EB%AC%B8")
      end
    end
  end
end
