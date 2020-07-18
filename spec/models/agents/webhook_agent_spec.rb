require 'rails_helper'

describe Agents::WebhookAgent do
  let(:agent) do
    _agent = Agents::WebhookAgent.new(:name => 'webhook',
                                      :options => { 'secret' => 'foobar', 'payload_path' => 'some_key' })
    _agent.user = users(:bob)
    _agent.save!
    _agent
  end
  let(:payload) { {'people' => [{ 'name' => 'bob' }, { 'name' => 'jon' }] } }

  describe 'receive_web_request' do
    it 'should create event if secret matches' do
      webpayload = ActionDispatch::Request.new({
          'action_dispatch.request.request_parameters' => { 'some_key' => payload },
          'action_dispatch.request.path_parameters' => { secret: 'foobar' },
          'REQUEST_METHOD' => "POST",
          'HTTP_ACCEPT' => 'application/xml',
          'HTTP_X_HELLO_WORLD' => "Hello Huginn"
        })

      out = nil
      agent.options['event_headers'] = 'Accept,X-Hello-World'
      agent.options['event_headers_key'] = 'X-HTTP-HEADERS'
      expect {
        out = agent.receive_web_request(webpayload)
      }.to change { Event.count }.by(1)
      expect(out).to eq(['Event Created', 201])
      expect(Event.last.payload).to eq( {"people"=>[{"name"=>"bob"}, {"name"=>"jon"}], "X-HTTP-HEADERS"=>{"Accept"=>"application/xml", "X-Hello-World"=>"Hello Huginn"}})
    end

    it 'should be able to create multiple events when given an array' do
      webpayload = ActionDispatch::Request.new({
          'action_dispatch.request.request_parameters' => { 'some_key' => payload },
          'action_dispatch.request.path_parameters' => { secret: 'foobar' },
          'REQUEST_METHOD' => "POST",
          'HTTP_ACCEPT' => 'application/xml',
          'HTTP_X_HELLO_WORLD' => "Hello Huginn"
        })
      out = nil
      agent.options['payload_path'] = 'some_key.people'
      agent.options['event_headers'] = 'Accept,X-Hello-World'
      agent.options['event_headers_key'] = 'X-HTTP-HEADERS'
      expect {
        out = agent.receive_web_request(webpayload)
      }.to change { Event.count }.by(2)
      expect(out).to eq(['Event Created', 201])
      expect(Event.last.payload).to eq({"name"=>"jon", "X-HTTP-HEADERS"=>{"Accept"=>"application/xml", "X-Hello-World"=>"Hello Huginn"}})
    end

    it 'should not create event if secrets do not match' do
      webpayload = ActionDispatch::Request.new({
          'action_dispatch.request.request_parameters' => { 'some_key' => payload },
          'action_dispatch.request.path_parameters' => { secret: 'bazbat' },
          'REQUEST_METHOD' => "POST",
          'HTTP_ACCEPT' => 'application/xml',
          'HTTP_X_HELLO_WORLD' => "Hello Huginn"
        })

      out = nil
      agent.options['event_headers'] = 'Accept,X-Hello-World'
      agent.options['event_headers_key'] = 'X-HTTP-HEADERS'
      expect {
        out = agent.receive_web_request(webpayload)
      }.to change { Event.count }.by(0)
      expect(out).to eq(['Not Authorized', 401])
    end

    it 'should respond with customized response message if configured with `response` option' do
      webpayload = ActionDispatch::Request.new({
          'action_dispatch.request.request_parameters' => { 'some_key' => payload },
          'action_dispatch.request.path_parameters' => { secret: 'foobar' },
          'REQUEST_METHOD' => "POST",
          'HTTP_ACCEPT' => 'application/xml',
          'HTTP_X_HELLO_WORLD' => "Hello Huginn"
        })

      agent.options['response'] = 'That Worked'
      out = agent.receive_web_request(webpayload)
      expect(out).to eq(['That Worked', 201])

      # Empty string is a valid response
      agent.options['response'] = ''
      out = agent.receive_web_request(webpayload)
      expect(out).to eq(['', 201])
    end

    it 'should respond with interpolated response message if configured with `response` option' do
      webpayload = ActionDispatch::Request.new({
          'action_dispatch.request.request_parameters' => { 'some_key' => payload },
          'action_dispatch.request.path_parameters' => { secret: 'foobar' },
          'REQUEST_METHOD' => "POST",
          'HTTP_ACCEPT' => 'application/xml',
          'HTTP_X_HELLO_WORLD' => "Hello Huginn"
        })

      agent.options['response'] = '{{some_key.people[1].name}}'
      out = agent.receive_web_request(webpayload)
      expect(out).to eq(['jon', 201])
    end

    it 'should respond with custom response header if configured with `response_headers` option' do
      webpayload = ActionDispatch::Request.new({
          'action_dispatch.request.request_parameters' => { 'some_key' => payload },
          'action_dispatch.request.path_parameters' => { secret: 'foobar' },
          'REQUEST_METHOD' => "POST",
          'HTTP_ACCEPT' => 'application/xml',
          'HTTP_X_HELLO_WORLD' => "Hello Huginn"
        })
      agent.options['response_headers'] = {"X-My-Custom-Header" => 'hello'}
      out = agent.receive_web_request(webpayload)
      expect(out).to eq(['Event Created', 201, "text/plain", {"X-My-Custom-Header" => 'hello'}])
    end

    it 'should respond with `Event Created` if the response option is nil or missing' do
      webpayload = ActionDispatch::Request.new({
          'action_dispatch.request.request_parameters' => { 'some_key' => payload },
          'action_dispatch.request.path_parameters' => { secret: 'foobar' },
          'REQUEST_METHOD' => "POST",
          'HTTP_ACCEPT' => 'application/xml',
          'HTTP_X_HELLO_WORLD' => "Hello Huginn"
        })

      agent.options['response'] = nil
      out = agent.receive_web_request(webpayload)
      expect(out).to eq(['Event Created', 201])

      agent.options.delete('response')
      out = agent.receive_web_request(webpayload)
      expect(out).to eq(['Event Created', 201])
    end

    it 'should respond with customized response code if configured with `code` option' do
      webpayload = ActionDispatch::Request.new({
          'action_dispatch.request.request_parameters' => { 'some_key' => payload },
          'action_dispatch.request.path_parameters' => { secret: 'foobar' },
          'REQUEST_METHOD' => "POST",
          'HTTP_ACCEPT' => 'application/xml',
          'HTTP_X_HELLO_WORLD' => "Hello Huginn"
        })

      agent.options['code'] = '200'
      out = agent.receive_web_request(webpayload)
      expect(out).to eq(['Event Created', 200])
    end

    it 'should respond with `201` if the code option is empty, nil or missing' do
      webpayload = ActionDispatch::Request.new({
          'action_dispatch.request.request_parameters' => { 'some_key' => payload },
          'action_dispatch.request.path_parameters' => { secret: 'foobar' },
          'REQUEST_METHOD' => "POST",
          'HTTP_ACCEPT' => 'application/xml',
          'HTTP_X_HELLO_WORLD' => "Hello Huginn"
        })

      agent.options['code'] = ''
      out = agent.receive_web_request(webpayload)
      expect(out).to eq(['Event Created', 201])

      agent.options['code'] = nil
      out = agent.receive_web_request(webpayload)
      expect(out).to eq(['Event Created', 201])

      agent.options.delete('code')
      out = agent.receive_web_request(webpayload)
      expect(out).to eq(['Event Created', 201])
    end

    describe "receiving events" do

      context "default settings" do

        it "should not accept GET" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "GET",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(0)
          expect(out).to eq(['Please use POST requests only', 401])
        end

        it "should accept POST" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "POST",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(1)
          expect(out).to eq(['Event Created', 201])
        end

      end

      context "accepting get and post" do

        before { agent.options['verbs'] = 'get,post' }

        it "should accept GET" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "GET",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(1)
          expect(out).to eq(['Event Created', 201])
        end

        it "should accept POST" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "POST",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(1)
          expect(out).to eq(['Event Created', 201])
        end

        it "should not accept PUT" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "PUT",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(0)
          expect(out).to eq(['Please use GET/POST requests only', 401])
        end

      end

      context "accepting only get" do

        before { agent.options['verbs'] = 'get' }

        it "should accept GET" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "GET",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(1)
          expect(out).to eq(['Event Created', 201])
        end

        it "should not accept POST" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "POST",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(0)
          expect(out).to eq(['Please use GET requests only', 401])
        end

      end

      context "accepting only post" do

        before { agent.options['verbs'] = 'post' }

        it "should not accept GET" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "GET",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(0)
          expect(out).to eq(['Please use POST requests only', 401])
        end

        it "should accept POST" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "POST",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(1)
          expect(out).to eq(['Event Created', 201])
        end

      end

      context "accepting only put" do

        before { agent.options['verbs'] = 'put' }

        it "should accept PUT" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "PUT",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(1)
          expect(out).to eq(['Event Created', 201])
        end

        it "should not accept GET" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "GET",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(0)
          expect(out).to eq(['Please use PUT requests only', 401])
        end

        it "should not accept POST" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "POST",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(0)
          expect(out).to eq(['Please use PUT requests only', 401])
        end

      end

      context "flaky content with commas" do

        before { agent.options['verbs'] = ',,  PUT,POST, gEt , ,' }

        it "should accept PUT" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "PUT",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(1)
          expect(out).to eq(['Event Created', 201])
        end

        it "should accept GET" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "GET",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(1)
          expect(out).to eq(['Event Created', 201])
        end

        it "should accept POST" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "POST",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(1)
          expect(out).to eq(['Event Created', 201])
        end

        it "should not accept DELETE" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "DELETE",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          out = nil
          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { Event.count }.by(0)
          expect(out).to eq(['Please use PUT/POST/GET requests only', 401])
        end

      end

      context "with reCAPTCHA" do
        it "should not check a reCAPTCHA response unless recaptcha_secret is set" do
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "POST",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          checked = false
          out = nil

          stub_request(:any, /verify/).to_return { |request|
            checked = true
            { status: 200, body: '{"success":false}' }
          }

          expect {
            out= agent.receive_web_request(webpayload)
          }.not_to change { checked }

          expect(out).to eq(["Event Created", 201])
        end

        it "should reject a request if recaptcha_secret is set but g-recaptcha-response is not given" do
          agent.options['recaptcha_secret'] = 'supersupersecret'

          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "POST",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          checked = false
          out = nil

          stub_request(:any, /verify/).to_return { |request|
            checked = true
            { status: 200, body: '{"success":false}' }
          }

          expect {
            out = agent.receive_web_request(webpayload)
          }.not_to change { checked }

          expect(out).to eq(["Not Authorized", 401])
        end

        it "should reject a request if recaptcha_secret is set and g-recaptcha-response given is not verified" do
          agent.options['recaptcha_secret'] = 'supersupersecret'
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => { 'some_key' => payload, 'g-recaptcha-response' => 'somevalue' },
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "POST",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          checked = false
          out = nil

          stub_request(:any, /verify/).to_return { |request|
            checked = true
            { status: 200, body: '{"success":false}' }
          }
         expect {
            out = agent.receive_web_request(webpayload)
          }.to change { checked }

          expect(out).to eq(["Not Authorized", 401])
        end

        it "should accept a request if recaptcha_secret is set and g-recaptcha-response given is verified" do
          agent.options['payload_path'] = '.'
          agent.options['recaptcha_secret'] = 'supersupersecret'
          webpayload = ActionDispatch::Request.new({
              'action_dispatch.request.request_parameters' => payload.merge({ 'g-recaptcha-response' => 'somevalue' }),
              'action_dispatch.request.path_parameters' => { secret: 'foobar' },
              'REQUEST_METHOD' => "POST",
              'HTTP_ACCEPT' => 'application/xml',
              'HTTP_X_HELLO_WORLD' => "Hello Huginn"
            })

          checked = false
          out = nil

          stub_request(:any, /verify/).to_return { |request|
            checked = true
            { status: 200, body: '{"success":true}' }
          }

          expect {
            out = agent.receive_web_request(webpayload)
          }.to change { checked }

          expect(out).to eq(["Event Created", 201])
          expect(Event.last.payload).to eq(payload)
        end
      end
    end
    context "with headers" do
      it "should not pass any headers if event_headers_key is not set" do
        webpayload = ActionDispatch::Request.new({
            'action_dispatch.request.request_parameters' => { 'some_key' => payload },
            'action_dispatch.request.path_parameters' => { secret: 'foobar' },
            'REQUEST_METHOD' => "POST",
            'HTTP_ACCEPT' => 'application/xml',
            'HTTP_X_HELLO_WORLD' => "Hello Huginn"
          })

        agent.options['event_headers'] = 'Accept,X-Hello-World'
        agent.options['event_headers_key'] = ''

        out = nil

        expect {
          out = agent.receive_web_request(webpayload)
        }.to change { Event.count }.by(1)
        expect(out).to eq(['Event Created', 201])
        expect(Event.last.payload).to eq(payload)
      end

      it "should pass selected headers specified in event_headers_key" do
        webpayload = ActionDispatch::Request.new({
            'action_dispatch.request.request_parameters' => { 'some_key' => payload },
            'action_dispatch.request.path_parameters' => { secret: 'foobar' },
            'REQUEST_METHOD' => "POST",
            'HTTP_ACCEPT' => 'application/xml',
            'HTTP_X_HELLO_WORLD' => "Hello Huginn"
          })

        agent.options['event_headers'] = 'X-Hello-World'
        agent.options['event_headers_key'] = 'X-HTTP-HEADERS'

        out = nil

        expect {
          out= agent.receive_web_request(webpayload)
        }.to change { Event.count }.by(1)
        expect(out).to eq(['Event Created', 201])
        expect(Event.last.payload).to eq({"people"=>[{"name"=>"bob"}, {"name"=>"jon"}], "X-HTTP-HEADERS"=>{"X-Hello-World"=>"Hello Huginn"}})
      end

      it "should pass empty event_headers_key if none of the headers exist" do
        webpayload = ActionDispatch::Request.new({
            'action_dispatch.request.request_parameters' => { 'some_key' => payload },
            'action_dispatch.request.path_parameters' => { secret: 'foobar' },
            'REQUEST_METHOD' => "POST",
            'HTTP_ACCEPT' => 'application/xml',
            'HTTP_X_HELLO_WORLD' => "Hello Huginn"
          })

        agent.options['event_headers'] = 'x-hello-world1'
        agent.options['event_headers_key'] = 'X-HTTP-HEADERS'

        out = nil

        expect {
          out= agent.receive_web_request(webpayload)
        }.to change { Event.count }.by(1)
        expect(out).to eq(['Event Created', 201])
        expect(Event.last.payload).to eq({"people"=>[{"name"=>"bob"}, {"name"=>"jon"}], "X-HTTP-HEADERS"=>{}})
      end

      it "should pass empty event_headers_key if event_headers is empty" do
        webpayload = ActionDispatch::Request.new({
            'action_dispatch.request.request_parameters' => { 'some_key' => payload },
            'action_dispatch.request.path_parameters' => { secret: 'foobar' },
            'REQUEST_METHOD' => "POST",
            'HTTP_ACCEPT' => 'application/xml',
            'HTTP_X_HELLO_WORLD' => "Hello Huginn"
          })

        agent.options['event_headers'] = ''
        agent.options['event_headers_key'] = 'X-HTTP-HEADERS'

        out = nil

        expect {
          out= agent.receive_web_request(webpayload)
        }.to change { Event.count }.by(1)
        expect(out).to eq(['Event Created', 201])
        expect(Event.last.payload).to eq({"people"=>[{"name"=>"bob"}, {"name"=>"jon"}], "X-HTTP-HEADERS"=>{}})
      end

    end

  end
end
