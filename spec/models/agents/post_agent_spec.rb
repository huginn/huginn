require 'rails_helper'
require 'ostruct'

describe Agents::PostAgent do
  before do
    @valid_options = {
      'post_url' => "http://www.example.com",
      'expected_receive_period_in_days' => 1,
      'payload' => {
        'default' => 'value'
      }
    }
    @valid_params = {
      name: "somename",
      options: @valid_options
    }

    @checker = Agents::PostAgent.new(@valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:jane_weather_agent)
    @event.payload = {
      'somekey' => 'somevalue',
      'someotherkey' => {
        'somekey' => 'value'
      }
    }
    @requests = 0
    @sent_requests = Hash.new { |hash, method| hash[method] = [] }

    stub_request(:any, /:/).to_return { |request|
      method = request.method
      @requests += 1
      @sent_requests[method] << req = OpenStruct.new(uri: request.uri, headers: request.headers)
      case method
      when :get, :delete
        req.data = request.uri.query
      else
        content_type = request.headers['Content-Type'][/\A[^;\s]+/]
        case content_type
        when 'application/x-www-form-urlencoded'
          req.data = request.body
        when 'application/json'
          req.data = ActiveSupport::JSON.decode(request.body)
        when 'text/xml'
          req.data = Hash.from_xml(request.body)
        when Agents::PostAgent::MIME_RE
          req.data = request.body
        else
          raise "unexpected Content-Type: #{content_type}"
        end
      end
      { status: 200, body: "<html>a webpage!</html>", headers: { 'Content-type' => 'text/html', 'X-Foo-Bar' => 'baz' } }
    }
  end

  it_behaves_like WebRequestConcern
  it_behaves_like 'FileHandlingConsumer'

  it 'renders the description markdown without errors' do
    expect { @checker.description }.not_to raise_error
  end

  describe "making requests" do
    it "can make requests of each type" do
      %w[get put post patch delete].each.with_index(1) do |verb, index|
        @checker.options['method'] = verb
        expect(@checker).to be_valid
        @checker.check
        expect(@requests).to eq(index)
        expect(@sent_requests[verb.to_sym].length).to eq(1)
      end
    end
  end

  describe "#receive" do
    it "can handle multiple events and merge the payloads with options['payload']" do
      event1 = Event.new
      event1.agent = agents(:bob_weather_agent)
      event1.payload = {
        'xyz' => 'value1',
        'message' => 'value2',
        'default' => 'value2'
      }

      expect {
        expect {
          @checker.receive([@event, event1])
        }.to change { @sent_requests[:post].length }.by(2)
      }.not_to change { @sent_requests[:get].length }

      expect(@sent_requests[:post][0].data).to eq(@event.payload.merge('default' => 'value').to_query)
      expect(@sent_requests[:post][1].data).to eq(event1.payload.to_query)
    end

    it "can make GET requests" do
      @checker.options['method'] = 'get'

      expect {
        expect {
          @checker.receive([@event])
        }.to change { @sent_requests[:get].length }.by(1)
      }.not_to change { @sent_requests[:post].length }

      expect(@sent_requests[:get][0].data).to eq(@event.payload.merge('default' => 'value').to_query)
    end

    it "can make a GET request merging params in post_url, payload and event" do
      @checker.options['method'] = 'get'
      @checker.options['post_url'] = "http://example.com/a/path?existing_param=existing_value"
      @event.payload = {
        "some_param" => "some_value",
        "another_param" => "another_value"
      }
      @checker.receive([@event])
      uri = @sent_requests[:get].first.uri
      # parameters are alphabetically sorted by Faraday
      expect(uri.request_uri).to eq("/a/path?another_param=another_value&default=value&existing_param=existing_value&some_param=some_value")
    end

    it "can skip merging the incoming event when no_merge is set, but it still interpolates" do
      @checker.options['no_merge'] = 'true'
      @checker.options['payload'] = {
        'key' => 'it said: {{ someotherkey.somekey }}'
      }
      @checker.receive([@event])
      expect(@sent_requests[:post].first.data).to eq({ 'key' => 'it said: value' }.to_query)
    end

    it "interpolates when receiving a payload" do
      @checker.options['post_url'] = "https://{{ domain }}/{{ variable }}?existing_param=existing_value"
      @event.payload = {
        'domain' => 'google.com',
        'variable' => 'a_variable'
      }
      @checker.receive([@event])
      uri = @sent_requests[:post].first.uri
      expect(uri.scheme).to eq('https')
      expect(uri.host).to eq('google.com')
      expect(uri.path).to eq('/a_variable')
      expect(uri.query).to eq("existing_param=existing_value")
    end

    it "interpolates outgoing headers with the event payload" do
      @checker.options['headers'] = {
        "Foo" => "{{ variable }}"
      }
      @event.payload = {
        'variable' => 'a_variable'
      }
      @checker.receive([@event])
      headers = @sent_requests[:post].first.headers
      expect(headers["Foo"]).to eq("a_variable")
    end

    it 'makes a multipart request when receiving a file_pointer' do
      WebMock.reset!
      stub_request(:post, "http://www.example.com/").
        with(headers: {
               'Accept-Encoding' => 'gzip,deflate',
               'Content-Type' => /\Amultipart\/form-data; boundary=/,
               'User-Agent' => 'Huginn - https://github.com/huginn/huginn'
        }) { |request|
        qboundary = Regexp.quote(request.headers['Content-Type'][/ boundary=(.+)/, 1])
        /\A--#{qboundary}\r\nContent-Disposition: form-data; name="default"\r\n\r\nvalue\r\n--#{qboundary}\r\nContent-Disposition: form-data; name="file"; filename="local.path"\r\nContent-Length: 8\r\nContent-Type: \r\nContent-Transfer-Encoding: binary\r\n\r\ntestdata\r\n--#{qboundary}--\r\n\r\n\z/ === request.body
      }.to_return(status: 200, body: "", headers: {})
      event = Event.new(payload: {file_pointer: {agent_id: 111, file: 'test'}})
      io_mock = mock()
      mock(@checker).get_io(event) { StringIO.new("testdata") }
      @checker.options['no_merge'] = true
      @checker.receive([event])
    end
  end

  describe "#check" do
    it "sends options['payload'] as a POST request" do
      expect {
        @checker.check
      }.to change { @sent_requests[:post].length }.by(1)

      expect(@sent_requests[:post][0].data).to eq(@checker.options['payload'].to_query)
    end

    it "sends options['payload'] as JSON as a POST request" do
      @checker.options['content_type'] = 'json'
      expect {
        @checker.check
      }.to change { @sent_requests[:post].length }.by(1)

      expect(@sent_requests[:post][0].data).to eq(@checker.options['payload'])
    end

    it "sends options['payload'] as XML as a POST request" do
      @checker.options['content_type'] = 'xml'
      expect {
        @checker.check
      }.to change { @sent_requests[:post].length }.by(1)

      expect(@sent_requests[:post][0].data.keys).to eq([ 'post' ])
      expect(@sent_requests[:post][0].data['post']).to eq(@checker.options['payload'])
    end

    it "sends options['payload'] as XML with custom root element name, as a POST request" do
      @checker.options['content_type'] = 'xml'
      @checker.options['xml_root'] = 'foobar'
      expect {
        @checker.check
      }.to change { @sent_requests[:post].length }.by(1)

      expect(@sent_requests[:post][0].data.keys).to eq([ 'foobar' ])
      expect(@sent_requests[:post][0].data['foobar']).to eq(@checker.options['payload'])
    end

    it "sends options['payload'] as a GET request" do
      @checker.options['method'] = 'get'
      expect {
        expect {
          @checker.check
        }.to change { @sent_requests[:get].length }.by(1)
      }.not_to change { @sent_requests[:post].length }

      expect(@sent_requests[:get][0].data).to eq(@checker.options['payload'].to_query)
    end

    it "sends options['payload'] as a string POST request when content-type continas a MIME type" do
      @checker.options['payload'] = '<test>hello</test>'
      @checker.options['content_type'] = 'application/xml'
      expect {
        @checker.check
      }.to change { @sent_requests[:post].length }.by(1)

      expect(@sent_requests[:post][0].data).to eq('<test>hello</test>')
    end

    it "interpolates outgoing headers" do
      @checker.options['headers'] = {
        "Foo" => "{% credential aws_key %}"
      }
      @checker.check
      headers = @sent_requests[:post].first.headers
      expect(headers["Foo"]).to eq("2222222222-jane")
    end

    describe "emitting events" do
      context "when emit_events is not set to true" do
        it "does not emit events" do
          expect {
            @checker.check
          }.not_to change { @checker.events.count }
        end
      end

      context "when emit_events is set to true" do
        before do
          @checker.options['emit_events'] = 'true'
          @checker.save!
        end

        it "emits the response status" do
          expect {
            @checker.check
          }.to change { @checker.events.count }.by(1)
          expect(@checker.events.last.payload['status']).to eq 200
        end

        it "emits the body" do
          @checker.check
          expect(@checker.events.last.payload['body']).to eq '<html>a webpage!</html>'
        end

        it "emits the response headers capitalized by default" do
          @checker.check
          expect(@checker.events.last.payload['headers']).to eq({ 'Content-Type' => 'text/html', 'X-Foo-Bar' => 'baz' })
        end

        it "emits the response headers capitalized" do
          @checker.options['event_headers_style'] = 'capitalized'
          @checker.check
          expect(@checker.events.last.payload['headers']).to eq({ 'Content-Type' => 'text/html', 'X-Foo-Bar' => 'baz' })
        end

        it "emits the response headers downcased" do
          @checker.options['event_headers_style'] = 'downcased'
          @checker.check
          expect(@checker.events.last.payload['headers']).to eq({ 'content-type' => 'text/html', 'x-foo-bar' => 'baz' })
        end

        it "emits the response headers snakecased" do
          @checker.options['event_headers_style'] = 'snakecased'
          @checker.check
          expect(@checker.events.last.payload['headers']).to eq({ 'content_type' => 'text/html', 'x_foo_bar' => 'baz' })
        end

        it "emits the response headers only including those specified by event_headers" do
          @checker.options['event_headers_style'] = 'snakecased'
          @checker.options['event_headers'] = 'content-type'
          @checker.check
          expect(@checker.events.last.payload['headers']).to eq({ 'content_type' => 'text/html' })
        end

        context "when output_mode is set to 'merge'" do
          before do
            @checker.options['output_mode'] = 'merge'
            @checker.save!
          end

          it "emits the received event" do
            @checker.receive([@event])
            @checker.check
            expect(@checker.events.last.payload['somekey']).to eq('somevalue')
            expect(@checker.events.last.payload['someotherkey']).to eq({ 'somekey' => 'value' })
          end
        end
      end
    end
  end

  describe "#working?" do
    it "checks if there was an error" do
      @checker.error("error")
      expect(@checker.logs.count).to eq(1)
      expect(@checker.reload).not_to be_working
    end

    it "checks if 'expected_receive_period_in_days' was not set" do
      expect(@checker.logs.count).to eq(0)
      @checker.options.delete('expected_receive_period_in_days')
      expect(@checker).to be_working
    end

    it "checks if no event has been received" do
      expect(@checker.logs.count).to eq(0)
      expect(@checker.last_receive_at).to be_nil
      expect(@checker.reload).not_to be_working
    end

    it "checks if events have been received within expected receive period" do
      expect(@checker).not_to be_working
      Agents::PostAgent.async_receive @checker.id, [@event.id]
      expect(@checker.reload).to be_working
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(@checker.reload).not_to be_working
    end
  end

  describe "validation" do
    before do
      expect(@checker).to be_valid
    end

    it "should validate presence of post_url" do
      @checker.options['post_url'] = ""
      expect(@checker).not_to be_valid
    end

    it "should validate absence of expected_receive_period_in_days is allowed" do
      @checker.options['expected_receive_period_in_days'] = ""
      expect(@checker).to be_valid
    end

    it "should validate method as post, get, put, patch, or delete, defaulting to post" do
      @checker.options['method'] = ""
      expect(@checker.method).to eq("post")
      expect(@checker).to be_valid

      @checker.options['method'] = "POST"
      expect(@checker.method).to eq("post")
      expect(@checker).to be_valid

      @checker.options['method'] = "get"
      expect(@checker.method).to eq("get")
      expect(@checker).to be_valid

      @checker.options['method'] = "patch"
      expect(@checker.method).to eq("patch")
      expect(@checker).to be_valid

      @checker.options['method'] = "wut"
      expect(@checker.method).to eq("wut")
      expect(@checker).not_to be_valid
    end

    it "should validate that no_merge is 'true' or 'false', if present" do
      @checker.options['no_merge'] = ""
      expect(@checker).to be_valid

      @checker.options['no_merge'] = "true"
      expect(@checker).to be_valid

      @checker.options['no_merge'] = "false"
      expect(@checker).to be_valid

      @checker.options['no_merge'] = false
      expect(@checker).to be_valid

      @checker.options['no_merge'] = true
      expect(@checker).to be_valid

      @checker.options['no_merge'] = 'blarg'
      expect(@checker).not_to be_valid
    end

    it "should validate payload as a hash, if present" do
      @checker.options['payload'] = ""
      expect(@checker).to be_valid

      @checker.options['payload'] = ["foo", "bar"]
      expect(@checker).to be_valid

      @checker.options['payload'] = "hello"
      expect(@checker).not_to be_valid

      @checker.options['payload'] = { 'this' => 'that' }
      expect(@checker).to be_valid
    end

    it "should not validate payload as a hash or an array if content_type includes a MIME type and method is not get or delete" do
      @checker.options['no_merge'] = 'true'
      @checker.options['content_type'] = 'text/xml'
      @checker.options['payload'] = "test"
      expect(@checker).to be_valid

      @checker.options['method'] = 'get'
      expect(@checker).not_to be_valid

      @checker.options['method'] = 'delete'
      expect(@checker).not_to be_valid
    end

    it "requires `no_merge` to be set to true when content_type contains a MIME type" do
      @checker.options['content_type'] = 'text/xml'
      @checker.options['payload'] = "test"
      expect(@checker).not_to be_valid
    end

    it "requires headers to be a hash, if present" do
      @checker.options['headers'] = [1,2,3]
      expect(@checker).not_to be_valid

      @checker.options['headers'] = "hello world"
      expect(@checker).not_to be_valid

      @checker.options['headers'] = ""
      expect(@checker).to be_valid

      @checker.options['headers'] = {}
      expect(@checker).to be_valid

      @checker.options['headers'] = { "Authorization" => "foo bar" }
      expect(@checker).to be_valid
    end

    it "requires emit_events to be true or false" do
      @checker.options['emit_events'] = 'what?'
      expect(@checker).not_to be_valid

      @checker.options.delete('emit_events')
      expect(@checker).to be_valid

      @checker.options['emit_events'] = 'true'
      expect(@checker).to be_valid

      @checker.options['emit_events'] = 'false'
      expect(@checker).to be_valid

      @checker.options['emit_events'] = true
      expect(@checker).to be_valid
    end

    it "requires output_mode to be 'clean' or 'merge', if present" do
      @checker.options['output_mode'] = 'what?'
      expect(@checker).not_to be_valid

      @checker.options.delete('output_mode')
      expect(@checker).to be_valid

      @checker.options['output_mode'] = 'clean'
      expect(@checker).to be_valid

      @checker.options['output_mode'] = 'merge'
      expect(@checker).to be_valid

      @checker.options['output_mode'] = :clean
      expect(@checker).to be_valid

      @checker.options['output_mode'] = :merge
      expect(@checker).to be_valid

      @checker.options['output_mode'] = '{{somekey}}'
      expect(@checker).to be_valid

      @checker.options['output_mode'] = "{% if key == 'foo' %}merge{% else %}clean{% endif %}"
      expect(@checker).to be_valid
    end
  end
end
